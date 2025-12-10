import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../models/file_entry.dart';
import '../services/ssh_service.dart';
import '../services/local_file_service.dart';

class FileBrowserProvider extends ChangeNotifier {
  final LocalFileService _localFileService = LocalFileService();
  SSHService? _sshService;

  // Local file browser state
  String _localPath = '';
  List<FileEntry> _localFiles = [];
  bool _isLoadingLocal = false;
  String? _localError;
  final Set<String> _selectedLocalFiles = {};

  // Remote file browser state
  String _remotePath = '';
  String _remoteHomePath = '';
  List<FileEntry> _remoteFiles = [];
  bool _isLoadingRemote = false;
  String? _remoteError;
  final Set<String> _selectedRemoteFiles = {};

  // Transfer state
  final List<FileTransfer> _transfers = [];
  bool get hasActiveTransfers => _transfers.any(
    (t) => t.status == TransferStatus.pending || t.status == TransferStatus.inProgress,
  );

  // Getters
  String get localPath => _localPath;
  List<FileEntry> get localFiles => _localFiles;
  bool get isLoadingLocal => _isLoadingLocal;
  String? get localError => _localError;
  Set<String> get selectedLocalFiles => _selectedLocalFiles;

  String get remotePath => _remotePath;
  String get remoteHomePath => _remoteHomePath;
  List<FileEntry> get remoteFiles => _remoteFiles;
  bool get isLoadingRemote => _isLoadingRemote;
  String? get remoteError => _remoteError;
  Set<String> get selectedRemoteFiles => _selectedRemoteFiles;

  List<FileTransfer> get transfers => _transfers;
  bool get isRemoteConnected => _sshService?.isConnected ?? false;

  FileBrowserProvider() {
    _initLocalPath();
  }

  void _initLocalPath() {
    _localPath = _localFileService.getHomeDirectory();
    loadLocalDirectory(_localPath);
  }

  /// Set SSH service reference
  void setSshService(SSHService service) {
    _sshService = service;
  }

  /// Load local directory
  Future<void> loadLocalDirectory(String path) async {
    _isLoadingLocal = true;
    _localError = null;
    notifyListeners();

    try {
      _localFiles = await _localFileService.listDirectory(path);
      _localPath = path;
      _selectedLocalFiles.clear();
    } catch (e) {
      _localError = e.toString();
    } finally {
      _isLoadingLocal = false;
      notifyListeners();
    }
  }

  /// Navigate up in local file system
  void navigateLocalUp() {
    final parent = _localFileService.getParentDirectory(_localPath);
    if (parent != _localPath) {
      loadLocalDirectory(parent);
    }
  }

  /// Navigate into local directory
  void navigateLocalInto(FileEntry entry) {
    if (entry.isDirectory) {
      loadLocalDirectory(entry.path);
    }
  }

  /// Load remote directory
  Future<void> loadRemoteDirectory(String path) async {
    if (_sshService == null || !_sshService!.isConnected) {
      _remoteError = 'Not connected';
      notifyListeners();
      return;
    }

    _isLoadingRemote = true;
    _remoteError = null;
    notifyListeners();

    try {
      _remoteFiles = await _sshService!.listRemoteDirectory(path);
      _remotePath = path;
      _selectedRemoteFiles.clear();
    } catch (e) {
      _remoteError = e.toString();
    } finally {
      _isLoadingRemote = false;
      notifyListeners();
    }
  }

  /// Initialize remote browser with home directory
  Future<void> initRemoteBrowser() async {
    if (_sshService == null || !_sshService!.isConnected) return;

    try {
      _remoteHomePath = await _sshService!.getRemoteHomeDirectory();
      _remotePath = _remoteHomePath;
      await loadRemoteDirectory(_remotePath);
    } catch (e) {
      _remoteError = e.toString();
      notifyListeners();
    }
  }

  /// Navigate up in remote file system
  void navigateRemoteUp() {
    final parent = p.posix.dirname(_remotePath);
    if (parent != _remotePath && parent.isNotEmpty) {
      loadRemoteDirectory(parent);
    }
  }

  /// Navigate into remote directory
  void navigateRemoteInto(FileEntry entry) {
    if (entry.isDirectory) {
      loadRemoteDirectory(entry.path);
    }
  }

  /// Toggle local file selection
  void toggleLocalSelection(String path) {
    if (_selectedLocalFiles.contains(path)) {
      _selectedLocalFiles.remove(path);
    } else {
      _selectedLocalFiles.add(path);
    }
    notifyListeners();
  }

  /// Toggle remote file selection
  void toggleRemoteSelection(String path) {
    if (_selectedRemoteFiles.contains(path)) {
      _selectedRemoteFiles.remove(path);
    } else {
      _selectedRemoteFiles.add(path);
    }
    notifyListeners();
  }

  /// Select all local files
  void selectAllLocal() {
    _selectedLocalFiles.addAll(_localFiles.map((f) => f.path));
    notifyListeners();
  }

  /// Select all remote files
  void selectAllRemote() {
    _selectedRemoteFiles.addAll(_remoteFiles.map((f) => f.path));
    notifyListeners();
  }

  /// Clear local selection
  void clearLocalSelection() {
    _selectedLocalFiles.clear();
    notifyListeners();
  }

  /// Clear remote selection
  void clearRemoteSelection() {
    _selectedRemoteFiles.clear();
    notifyListeners();
  }

  /// Upload files from local to remote
  Future<void> uploadFiles(List<String> localPaths) async {
    if (_sshService == null || !_sshService!.isConnected) return;

    for (final localPath in localPaths) {
      final fileName = p.basename(localPath);
      final remoteDest = p.posix.join(_remotePath, fileName);

      final transfer = FileTransfer(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sourcePath: localPath,
        destinationPath: remoteDest,
        operation: TransferOperation.upload,
        totalBytes: await File(localPath).length(),
      );

      _transfers.add(transfer);
      notifyListeners();

      try {
        transfer.status = TransferStatus.inProgress;
        notifyListeners();

        await _sshService!.uploadFile(
          localPath,
          remoteDest,
          onProgress: (transferred, total) {
            transfer.transferredBytes = transferred;
            notifyListeners();
          },
        );

        transfer.status = TransferStatus.completed;
      } catch (e) {
        transfer.status = TransferStatus.failed;
        transfer.error = e.toString();
      }
      notifyListeners();
    }

    // Refresh remote directory
    await loadRemoteDirectory(_remotePath);
  }

  /// Download files from remote to local
  Future<void> downloadFiles(List<String> remotePaths) async {
    if (_sshService == null || !_sshService!.isConnected) return;

    for (final remotePath in remotePaths) {
      final fileName = p.basename(remotePath);
      final localDest = _localFileService.joinPaths(_localPath, fileName);

      // Get file info for size (approximate for directories)
      final fileEntry = _remoteFiles.firstWhere(
        (f) => f.path == remotePath,
        orElse: () => FileEntry(
          name: fileName,
          path: remotePath,
          isDirectory: false,
          size: 0,
          isLocal: false,
        ),
      );

      if (fileEntry.isDirectory) {
        // TODO: Handle directory download recursively
        continue;
      }

      final transfer = FileTransfer(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sourcePath: remotePath,
        destinationPath: localDest,
        operation: TransferOperation.download,
        totalBytes: fileEntry.size,
      );

      _transfers.add(transfer);
      notifyListeners();

      try {
        transfer.status = TransferStatus.inProgress;
        notifyListeners();

        await _sshService!.downloadFile(
          remotePath,
          localDest,
          onProgress: (transferred, total) {
            transfer.transferredBytes = transferred;
            notifyListeners();
          },
        );

        transfer.status = TransferStatus.completed;
      } catch (e) {
        transfer.status = TransferStatus.failed;
        transfer.error = e.toString();
      }
      notifyListeners();
    }

    // Refresh local directory
    await loadLocalDirectory(_localPath);
  }

  /// Create new folder locally
  Future<void> createLocalFolder(String name) async {
    final path = _localFileService.joinPaths(_localPath, name);
    await _localFileService.createDirectory(path);
    await loadLocalDirectory(_localPath);
  }

  /// Create new folder remotely
  Future<void> createRemoteFolder(String name) async {
    if (_sshService == null || !_sshService!.isConnected) return;
    final path = p.posix.join(_remotePath, name);
    await _sshService!.createRemoteDirectory(path);
    await loadRemoteDirectory(_remotePath);
  }

  /// Delete local files
  Future<void> deleteLocalFiles(List<String> paths) async {
    for (final path in paths) {
      final entry = _localFiles.firstWhere((f) => f.path == path);
      await _localFileService.delete(path, isDirectory: entry.isDirectory);
    }
    _selectedLocalFiles.removeAll(paths);
    await loadLocalDirectory(_localPath);
  }

  /// Delete remote files
  Future<void> deleteRemoteFiles(List<String> paths) async {
    if (_sshService == null || !_sshService!.isConnected) return;
    
    for (final path in paths) {
      final entry = _remoteFiles.firstWhere((f) => f.path == path);
      await _sshService!.deleteRemote(path, isDirectory: entry.isDirectory);
    }
    _selectedRemoteFiles.removeAll(paths);
    await loadRemoteDirectory(_remotePath);
  }

  /// Rename local file
  Future<void> renameLocal(String oldPath, String newName) async {
    final newPath = _localFileService.joinPaths(
      _localFileService.getParentDirectory(oldPath),
      newName,
    );
    await _localFileService.rename(oldPath, newPath);
    await loadLocalDirectory(_localPath);
  }

  /// Rename remote file
  Future<void> renameRemote(String oldPath, String newName) async {
    if (_sshService == null || !_sshService!.isConnected) return;
    
    final newPath = p.posix.join(p.posix.dirname(oldPath), newName);
    await _sshService!.renameRemote(oldPath, newPath);
    await loadRemoteDirectory(_remotePath);
  }

  /// Clear completed transfers
  void clearCompletedTransfers() {
    _transfers.removeWhere(
      (t) => t.status == TransferStatus.completed || t.status == TransferStatus.failed,
    );
    notifyListeners();
  }

  /// Clear remote state on disconnect
  void clearRemoteState() {
    _remoteFiles.clear();
    _remotePath = '';
    _remoteError = null;
    _selectedRemoteFiles.clear();
    notifyListeners();
  }
}
