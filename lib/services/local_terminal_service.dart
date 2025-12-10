import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_pty/flutter_pty.dart';

/// Service for managing local terminal sessions (native shell)
/// Supports Linux, macOS, and Windows. Not available on mobile platforms.
class LocalTerminalService {
  Pty? _pty;
  final StreamController<String> _outputController = StreamController<String>.broadcast();
  String _currentDirectory = '';
  bool _isRunning = false;

  /// Stream of terminal output
  Stream<String> get output => _outputController.stream;
  
  /// Current working directory (best effort tracking)
  String get currentDirectory => _currentDirectory;
  
  /// Whether a terminal session is active
  bool get isRunning => _isRunning;
  
  /// Check if local terminal is supported on current platform
  static bool get isSupported => 
      Platform.isLinux || Platform.isMacOS || Platform.isWindows;

  /// Get the default shell for the current platform
  String _getDefaultShell() {
    if (Platform.isWindows) {
      // Prefer PowerShell if available, fallback to cmd
      return Platform.environment['COMSPEC'] ?? 'cmd.exe';
    } else {
      // Unix-like systems
      return Platform.environment['SHELL'] ?? '/bin/bash';
    }
  }

  /// Get environment variables for the shell
  Map<String, String> _getEnvironment() {
    final env = Map<String, String>.from(Platform.environment);
    env['TERM'] = 'xterm-256color';
    env['COLORTERM'] = 'truecolor';
    return env;
  }

  /// Start a local terminal session
  Future<void> start({
    int columns = 80,
    int rows = 24,
  }) async {
    if (!isSupported) {
      throw UnsupportedError('Local terminal is not supported on this platform');
    }

    if (_isRunning) {
      await stop();
    }

    final shell = _getDefaultShell();
    _currentDirectory = Platform.environment['HOME'] ?? 
                        Platform.environment['USERPROFILE'] ?? 
                        Directory.current.path;

    try {
      _pty = Pty.start(
        shell,
        columns: columns,
        rows: rows,
        environment: _getEnvironment(),
        workingDirectory: _currentDirectory,
      );

      _pty!.output.listen(
        (data) {
          final output = String.fromCharCodes(data);
          _outputController.add(output);
          _trackCurrentDirectory(output);
        },
        onError: (error) {
          _outputController.addError(error);
        },
        onDone: () {
          _isRunning = false;
        },
      );

      _isRunning = true;
    } catch (e) {
      _isRunning = false;
      rethrow;
    }
  }

  /// Track current directory from shell output (best effort)
  void _trackCurrentDirectory(String output) {
    // Try to detect directory changes from common patterns
    // This is a heuristic and may not always be accurate
    final cdMatch = RegExp(r'cd\s+([^\s&;|]+)').firstMatch(output);
    if (cdMatch != null) {
      final newDir = cdMatch.group(1);
      if (newDir != null) {
        if (newDir.startsWith('/') || newDir.startsWith('~')) {
          _currentDirectory = newDir.replaceFirst('~', 
              Platform.environment['HOME'] ?? '/home');
        } else if (newDir == '..') {
          _currentDirectory = Directory(_currentDirectory).parent.path;
        } else if (newDir != '.') {
          _currentDirectory = '$_currentDirectory/$newDir';
        }
      }
    }
  }

  /// Write input to the terminal
  void write(String data) {
    if (_pty == null || !_isRunning) return;
    _pty!.write(Uint8List.fromList(data.codeUnits));
  }

  /// Resize the terminal
  void resize(int columns, int rows) {
    if (_pty == null || !_isRunning) return;
    // flutter_pty expects rows before columns while xterm reports columns first.
    _pty!.resize(rows, columns);
  }

  /// Stop the terminal session
  Future<void> stop() async {
    if (_pty != null) {
      _pty!.kill();
      _pty = null;
    }
    _isRunning = false;
  }

  /// Dispose resources
  void dispose() {
    stop();
    _outputController.close();
  }
}
