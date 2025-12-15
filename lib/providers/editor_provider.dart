import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../services/local_file_service.dart';
import '../services/ssh_service.dart';

/// Represents an open file in the editor
class OpenFile {
  final String id;
  final String originalPath;
  final String displayName;
  final bool isRemote;
  final String? remotePath; // Original remote path for remote files
  String? tempPath; // Local temp path for remote files
  String content;
  String savedContent; // Content as it was when last saved
  bool isLoading;
  bool isSaving;
  String? error;

  OpenFile({
    required this.id,
    required this.originalPath,
    required this.displayName,
    required this.isRemote,
    this.remotePath,
    this.tempPath,
    this.content = '',
    this.savedContent = '',
    this.isLoading = false,
    this.isSaving = false,
    this.error,
  });

  bool get isModified => content != savedContent;

  OpenFile copyWith({
    String? content,
    String? savedContent,
    String? tempPath,
    bool? isLoading,
    bool? isSaving,
    String? error,
  }) {
    return OpenFile(
      id: id,
      originalPath: originalPath,
      displayName: displayName,
      isRemote: isRemote,
      remotePath: remotePath,
      tempPath: tempPath ?? this.tempPath,
      content: content ?? this.content,
      savedContent: savedContent ?? this.savedContent,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: error,
    );
  }
}

/// Provider for managing text editor state
class EditorProvider extends ChangeNotifier {
  final LocalFileService _localFileService = LocalFileService();
  SSHService? _sshService;

  final List<OpenFile> _openFiles = [];
  String? _activeFileId;

  List<OpenFile> get openFiles => List.unmodifiable(_openFiles);
  OpenFile? get activeFile => _activeFileId != null
      ? _openFiles.cast<OpenFile?>().firstWhere(
            (f) => f?.id == _activeFileId,
            orElse: () => null,
          )
      : null;

  /// Set SSH service reference
  void setSshService(SSHService service) {
    _sshService = service;
  }

  /// Check if a file is already open
  bool isFileOpen(String path, bool isRemote) {
    return _openFiles.any((f) =>
        f.originalPath == path && f.isRemote == isRemote);
  }

  /// Get open file by path
  OpenFile? getOpenFile(String path, bool isRemote) {
    try {
      return _openFiles.firstWhere(
          (f) => f.originalPath == path && f.isRemote == isRemote);
    } catch (_) {
      return null;
    }
  }

  /// Open a local file
  Future<void> openLocalFile(String path) async {
    // Check if already open
    final existing = getOpenFile(path, false);
    if (existing != null) {
      _activeFileId = existing.id;
      notifyListeners();
      return;
    }

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final fileName = p.basename(path);

    final openFile = OpenFile(
      id: id,
      originalPath: path,
      displayName: fileName,
      isRemote: false,
      isLoading: true,
    );

    _openFiles.add(openFile);
    _activeFileId = id;
    notifyListeners();

    try {
      final content = await _localFileService.readFileContent(path);
      final index = _openFiles.indexWhere((f) => f.id == id);
      if (index != -1) {
        _openFiles[index] = openFile.copyWith(
          content: content,
          savedContent: content,
          isLoading: false,
        );
      }
    } catch (e) {
      final index = _openFiles.indexWhere((f) => f.id == id);
      if (index != -1) {
        _openFiles[index] = openFile.copyWith(
          isLoading: false,
          error: e.toString(),
        );
      }
    }
    notifyListeners();
  }

  /// Open a remote file (downloads to temp first)
  Future<void> openRemoteFile(String remotePath) async {
    if (_sshService == null || !_sshService!.isConnected) {
      throw StateError('Not connected to server');
    }

    // Check if already open
    final existing = getOpenFile(remotePath, true);
    if (existing != null) {
      _activeFileId = existing.id;
      notifyListeners();
      return;
    }

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final fileName = p.basename(remotePath);

    final openFile = OpenFile(
      id: id,
      originalPath: remotePath,
      displayName: '$fileName (Remote)',
      isRemote: true,
      remotePath: remotePath,
      isLoading: true,
    );

    _openFiles.add(openFile);
    _activeFileId = id;
    notifyListeners();

    try {
      // Read content directly from remote
      final content = await _sshService!.readRemoteFileContent(remotePath);
      
      final index = _openFiles.indexWhere((f) => f.id == id);
      if (index != -1) {
        _openFiles[index] = openFile.copyWith(
          content: content,
          savedContent: content,
          isLoading: false,
        );
      }
    } catch (e) {
      final index = _openFiles.indexWhere((f) => f.id == id);
      if (index != -1) {
        _openFiles[index] = openFile.copyWith(
          isLoading: false,
          error: e.toString(),
        );
      }
    }
    notifyListeners();
  }

  /// Update content of active file
  void updateContent(String content) {
    if (_activeFileId == null) return;

    final index = _openFiles.indexWhere((f) => f.id == _activeFileId);
    if (index != -1) {
      _openFiles[index] = _openFiles[index].copyWith(content: content);
      notifyListeners();
    }
  }

  /// Save active file
  Future<void> saveActiveFile() async {
    final file = activeFile;
    if (file == null) return;

    final index = _openFiles.indexWhere((f) => f.id == file.id);
    if (index == -1) return;

    _openFiles[index] = file.copyWith(isSaving: true);
    notifyListeners();

    try {
      if (file.isRemote) {
        // Save to remote server
        if (_sshService == null || !_sshService!.isConnected) {
          throw StateError('Not connected to server');
        }
        await _sshService!.writeRemoteFileContent(
          file.remotePath!,
          file.content,
        );
      } else {
        // Save to local file
        await _localFileService.writeFileContent(
          file.originalPath,
          file.content,
        );
      }

      _openFiles[index] = file.copyWith(
        savedContent: file.content,
        isSaving: false,
      );
    } catch (e) {
      _openFiles[index] = file.copyWith(
        isSaving: false,
        error: e.toString(),
      );
    }
    notifyListeners();
  }

  /// Save active file as (new path)
  Future<void> saveActiveFileAs(String newPath, {bool asRemote = false}) async {
    final file = activeFile;
    if (file == null) return;

    final index = _openFiles.indexWhere((f) => f.id == file.id);
    if (index == -1) return;

    _openFiles[index] = file.copyWith(isSaving: true);
    notifyListeners();

    try {
      if (asRemote) {
        // Save to remote server
        if (_sshService == null || !_sshService!.isConnected) {
          throw StateError('Not connected to server');
        }
        await _sshService!.writeRemoteFileContent(newPath, file.content);
      } else {
        // Save to local file
        await _localFileService.writeFileContent(newPath, file.content);
      }

      // Update the file info with new path
      final newFileName = p.basename(newPath);
      _openFiles[index] = OpenFile(
        id: file.id,
        originalPath: newPath,
        displayName: asRemote ? '$newFileName (Remote)' : newFileName,
        isRemote: asRemote,
        remotePath: asRemote ? newPath : null,
        content: file.content,
        savedContent: file.content,
        isLoading: false,
        isSaving: false,
      );
    } catch (e) {
      _openFiles[index] = file.copyWith(
        isSaving: false,
        error: e.toString(),
      );
    }
    notifyListeners();
  }

  /// Close a file
  void closeFile(String id) {
    _openFiles.removeWhere((f) => f.id == id);
    if (_activeFileId == id) {
      _activeFileId = _openFiles.isNotEmpty ? _openFiles.last.id : null;
    }
    notifyListeners();
  }

  /// Set active file
  void setActiveFile(String id) {
    if (_openFiles.any((f) => f.id == id)) {
      _activeFileId = id;
      notifyListeners();
    }
  }

  /// Check if any files have unsaved changes
  bool get hasUnsavedChanges => _openFiles.any((f) => f.isModified);

  /// Get list of files with unsaved changes
  List<OpenFile> get unsavedFiles => _openFiles.where((f) => f.isModified).toList();

  /// Clear error for active file
  void clearError() {
    if (_activeFileId == null) return;

    final index = _openFiles.indexWhere((f) => f.id == _activeFileId);
    if (index != -1) {
      _openFiles[index] = _openFiles[index].copyWith(error: null);
      notifyListeners();
    }
  }
}
