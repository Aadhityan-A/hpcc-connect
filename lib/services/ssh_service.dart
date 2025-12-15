import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:path/path.dart' as p;

import '../models/ssh_connection.dart';
import '../models/file_entry.dart';

/// Service for managing SSH connections, SFTP, and terminal sessions
class SSHService {
  SSHClient? _client;
  SftpClient? _sftpClient;
  SSHSession? _shellSession;
  
  final StreamController<String> _terminalOutputController = StreamController<String>.broadcast();
  final StreamController<bool> _connectionStateController = StreamController<bool>.broadcast();
  
  Stream<String> get terminalOutput => _terminalOutputController.stream;
  Stream<bool> get connectionState => _connectionStateController.stream;
  
  bool get isConnected => _client != null;
  SSHConnection? _currentConnection;
  SSHConnection? get currentConnection => _currentConnection;

  /// Connect to SSH server
  Future<void> connect(SSHConnection connection) async {
    try {
      await disconnect();
      
      final socket = await SSHSocket.connect(
        connection.host,
        connection.port,
        timeout: const Duration(seconds: 30),
      );

      if (connection.authType == AuthType.password) {
        _client = SSHClient(
          socket,
          username: connection.username,
          onPasswordRequest: () => connection.password ?? '',
        );
      } else {
        final keyPairs = SSHKeyPair.fromPem(
          connection.privateKey!,
          connection.passphrase,
        );
        _client = SSHClient(
          socket,
          username: connection.username,
          identities: keyPairs,
        );
      }

      _currentConnection = connection;
      _connectionStateController.add(true);
    } catch (e) {
      _connectionStateController.add(false);
      rethrow;
    }
  }

  /// Disconnect from SSH server
  Future<void> disconnect() async {
    _shellSession?.close();
    _shellSession = null;
    _sftpClient?.close();
    _sftpClient = null;
    _client?.close();
    _client = null;
    _currentConnection = null;
    _connectionStateController.add(false);
  }

  /// Start a shell session for terminal
  Future<void> startShell({
    required int width,
    required int height,
  }) async {
    if (_client == null) throw StateError('Not connected');
    
    _shellSession = await _client!.shell(
      pty: SSHPtyConfig(
        width: width,
        height: height,
        type: 'xterm-256color',
      ),
    );

    _shellSession!.stdout.listen((data) {
      _terminalOutputController.add(utf8.decode(data, allowMalformed: true));
    });

        _shellSession!.stderr.listen((data) {
      _terminalOutputController.add(utf8.decode(data, allowMalformed: true));
    });
  }

  /// Execute a command and return output
  Future<String> runCommand(String command) async {
    if (_client == null) throw StateError('Not connected');
    final result = await _client!.run(command);
    return utf8.decode(result, allowMalformed: true);
  }

  /// Write input to shell
  void writeToShell(String data) {
    if (_shellSession == null) return;
    _shellSession!.stdin.add(utf8.encode(data));
  }

  /// Resize terminal
  void resizeTerminal(int width, int height) {
    _shellSession?.resizeTerminal(width, height);
  }

  /// Get SFTP client
  Future<SftpClient> _getSftpClient() async {
    if (_client == null) throw StateError('Not connected');
    _sftpClient ??= await _client!.sftp();
    return _sftpClient!;
  }

  /// List remote directory
  Future<List<FileEntry>> listRemoteDirectory(String path) async {
    final sftp = await _getSftpClient();
    final items = await sftp.listdir(path);
    
    return items.where((item) {
      final name = item.filename;
      return name != '.' && name != '..';
    }).map((item) {
      final attr = item.attr;
      return FileEntry(
        name: item.filename,
        path: p.posix.join(path, item.filename),
        isDirectory: attr.isDirectory,
        size: attr.size ?? 0,
        modifiedTime: attr.modifyTime != null 
            ? DateTime.fromMillisecondsSinceEpoch(attr.modifyTime! * 1000)
            : null,
        permissions: _formatPermissionsFromMode(attr.mode),
        isLocal: false,
      );
    }).toList()
      ..sort((a, b) {
        if (a.isDirectory && !b.isDirectory) return -1;
        if (!a.isDirectory && b.isDirectory) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
  }

  /// Get remote home directory
  Future<String> getRemoteHomeDirectory() async {
    final sftp = await _getSftpClient();
    return await sftp.absolute('.');
  }

  /// Download file from remote to local
  Future<void> downloadFile(
    String remotePath,
    String localPath, {
    void Function(int transferred, int total)? onProgress,
  }) async {
    final sftp = await _getSftpClient();
    final remoteFile = await sftp.open(remotePath, mode: SftpFileOpenMode.read);
    
    try {
      final stat = await remoteFile.stat();
      final totalSize = stat.size ?? 0;
      
      final localFile = File(localPath);
      await localFile.parent.create(recursive: true);
      final sink = localFile.openWrite();
      
      int transferred = 0;
      await for (final chunk in remoteFile.read()) {
        sink.add(chunk);
        transferred += chunk.length;
        onProgress?.call(transferred, totalSize);
      }
      
      await sink.close();
    } finally {
      await remoteFile.close();
    }
  }

  /// Upload file from local to remote
  Future<void> uploadFile(
    String localPath,
    String remotePath, {
    void Function(int transferred, int total)? onProgress,
  }) async {
    final sftp = await _getSftpClient();
    final localFile = File(localPath);
    final totalSize = await localFile.length();
    
    final remoteFile = await sftp.open(
      remotePath,
      mode: SftpFileOpenMode.create | SftpFileOpenMode.write | SftpFileOpenMode.truncate,
    );
    
    try {
      int transferred = 0;
      final stream = localFile.openRead();
      
      await for (final chunk in stream) {
        await remoteFile.write(Stream.value(Uint8List.fromList(chunk)));
        transferred += chunk.length;
        onProgress?.call(transferred, totalSize);
      }
    } finally {
      await remoteFile.close();
    }
  }

  /// Create remote directory
  Future<void> createRemoteDirectory(String path) async {
    final sftp = await _getSftpClient();
    await sftp.mkdir(path);
  }

  /// Delete remote file or directory
  Future<void> deleteRemote(String path, {bool isDirectory = false}) async {
    final sftp = await _getSftpClient();
    if (isDirectory) {
      await _deleteRemoteDirectoryRecursive(sftp, path);
    } else {
      await sftp.remove(path);
    }
  }

  Future<void> _deleteRemoteDirectoryRecursive(SftpClient sftp, String path) async {
    final items = await sftp.listdir(path);
    for (final item in items) {
      if (item.filename == '.' || item.filename == '..') continue;
      final itemPath = p.posix.join(path, item.filename);
      if (item.attr.isDirectory) {
        await _deleteRemoteDirectoryRecursive(sftp, itemPath);
      } else {
        await sftp.remove(itemPath);
      }
    }
    await sftp.rmdir(path);
  }

  /// Rename remote file or directory
  Future<void> renameRemote(String oldPath, String newPath) async {
    final sftp = await _getSftpClient();
    await sftp.rename(oldPath, newPath);
  }

  /// Download directory recursively from remote to local
  /// Returns the total number of files downloaded and callbacks for progress
  Future<void> downloadDirectoryRecursive(
    String remotePath,
    String localPath, {
    void Function(String currentFile, int fileIndex, int totalFiles)? onFileStart,
    void Function(int transferred, int total)? onFileProgress,
    void Function(String filePath)? onFileComplete,
    void Function(int totalFiles)? onCountingComplete,
  }) async {
    final sftp = await _getSftpClient();
    
    // First, count all files recursively
    final allFiles = <_RemoteFileInfo>[];
    await _collectRemoteFiles(sftp, remotePath, localPath, allFiles);
    
    onCountingComplete?.call(allFiles.length);
    
    // Download each file
    for (int i = 0; i < allFiles.length; i++) {
      final fileInfo = allFiles[i];
      onFileStart?.call(fileInfo.remotePath, i + 1, allFiles.length);
      
      // Ensure parent directory exists
      final localDir = Directory(p.dirname(fileInfo.localPath));
      if (!await localDir.exists()) {
        await localDir.create(recursive: true);
      }
      
      // Download the file
      await downloadFile(
        fileInfo.remotePath,
        fileInfo.localPath,
        onProgress: onFileProgress,
      );
      
      onFileComplete?.call(fileInfo.localPath);
    }
  }

  /// Helper to collect all files in a remote directory recursively
  Future<void> _collectRemoteFiles(
    SftpClient sftp,
    String remotePath,
    String localPath,
    List<_RemoteFileInfo> files,
  ) async {
    final items = await sftp.listdir(remotePath);
    
    for (final item in items) {
      if (item.filename == '.' || item.filename == '..') continue;
      
      final itemRemotePath = p.posix.join(remotePath, item.filename);
      final itemLocalPath = p.join(localPath, item.filename);
      
      if (item.attr.isDirectory) {
        // Recursively collect files from subdirectory
        await _collectRemoteFiles(sftp, itemRemotePath, itemLocalPath, files);
      } else {
        files.add(_RemoteFileInfo(
          remotePath: itemRemotePath,
          localPath: itemLocalPath,
          size: item.attr.size ?? 0,
        ));
      }
    }
  }

  /// Upload directory recursively from local to remote
  Future<void> uploadDirectoryRecursive(
    String localPath,
    String remotePath, {
    void Function(String currentFile, int fileIndex, int totalFiles)? onFileStart,
    void Function(int transferred, int total)? onFileProgress,
    void Function(String filePath)? onFileComplete,
    void Function(int totalFiles)? onCountingComplete,
  }) async {
    final sftp = await _getSftpClient();
    
    // First, count all files recursively
    final allFiles = <_LocalFileInfo>[];
    await _collectLocalFiles(localPath, remotePath, allFiles);
    
    onCountingComplete?.call(allFiles.length);
    
    // Create all necessary remote directories first
    final dirsToCreate = <String>{};
    for (final fileInfo in allFiles) {
      final dir = p.posix.dirname(fileInfo.remotePath);
      dirsToCreate.add(dir);
    }
    
    // Sort directories by depth to create parents first
    final sortedDirs = dirsToCreate.toList()
      ..sort((a, b) => a.split('/').length.compareTo(b.split('/').length));
    
    for (final dir in sortedDirs) {
      try {
        await sftp.mkdir(dir);
      } catch (_) {
        // Directory may already exist, ignore error
      }
    }
    
    // Upload each file
    for (int i = 0; i < allFiles.length; i++) {
      final fileInfo = allFiles[i];
      onFileStart?.call(fileInfo.localPath, i + 1, allFiles.length);
      
      await uploadFile(
        fileInfo.localPath,
        fileInfo.remotePath,
        onProgress: onFileProgress,
      );
      
      onFileComplete?.call(fileInfo.remotePath);
    }
  }

  /// Helper to collect all files in a local directory recursively
  Future<void> _collectLocalFiles(
    String localPath,
    String remotePath,
    List<_LocalFileInfo> files,
  ) async {
    final dir = Directory(localPath);
    
    await for (final entity in dir.list(followLinks: false)) {
      final name = p.basename(entity.path);
      final itemRemotePath = p.posix.join(remotePath, name);
      
      if (entity is Directory) {
        // Recursively collect files from subdirectory
        await _collectLocalFiles(entity.path, itemRemotePath, files);
      } else if (entity is File) {
        final stat = await entity.stat();
        files.add(_LocalFileInfo(
          localPath: entity.path,
          remotePath: itemRemotePath,
          size: stat.size,
        ));
      }
    }
  }

  /// Read remote file content as string
  Future<String> readRemoteFileContent(String remotePath) async {
    final sftp = await _getSftpClient();
    final remoteFile = await sftp.open(remotePath, mode: SftpFileOpenMode.read);
    
    try {
      final chunks = <int>[];
      await for (final chunk in remoteFile.read()) {
        chunks.addAll(chunk);
      }
      return utf8.decode(chunks);
    } finally {
      await remoteFile.close();
    }
  }

  /// Write content to remote file
  Future<void> writeRemoteFileContent(String remotePath, String content) async {
    final sftp = await _getSftpClient();
    final remoteFile = await sftp.open(
      remotePath,
      mode: SftpFileOpenMode.create | SftpFileOpenMode.write | SftpFileOpenMode.truncate,
    );
    
    try {
      final bytes = utf8.encode(content);
      await remoteFile.write(Stream.value(Uint8List.fromList(bytes)));
    } finally {
      await remoteFile.close();
    }
  }

  /// Execute command on remote
  Future<String> executeCommand(String command) async {
    if (_client == null) throw StateError('Not connected');
    final result = await _client!.run(command);
    return utf8.decode(result);
  }

  String _formatPermissionsFromMode(SftpFileMode? mode) {
    if (mode == null) return '----------';
    return mode.toString();
  }

  void dispose() {
    disconnect();
    _terminalOutputController.close();
    _connectionStateController.close();
  }
}

/// Helper class to store remote file info during recursive download
class _RemoteFileInfo {
  final String remotePath;
  final String localPath;
  final int size;

  _RemoteFileInfo({
    required this.remotePath,
    required this.localPath,
    required this.size,
  });
}

/// Helper class to store local file info during recursive upload
class _LocalFileInfo {
  final String localPath;
  final String remotePath;
  final int size;

  _LocalFileInfo({
    required this.localPath,
    required this.remotePath,
    required this.size,
  });
}
