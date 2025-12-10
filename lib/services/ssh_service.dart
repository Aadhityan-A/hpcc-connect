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
