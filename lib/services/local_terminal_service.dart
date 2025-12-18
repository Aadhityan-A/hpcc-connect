import 'dart:async';
import 'dart:convert';
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
      // Use PowerShell for better PTY support on Windows
      // Try PowerShell Core (pwsh) first, then Windows PowerShell, fallback to cmd
      final pwshCore = 'C:\\Program Files\\PowerShell\\7\\pwsh.exe';
      final pwshWindows = 'C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe';
      
      if (File(pwshCore).existsSync()) {
        return pwshCore;
      } else if (File(pwshWindows).existsSync()) {
        return pwshWindows;
      }
      // Fallback to cmd if PowerShell not found
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

  /// Get shell arguments for the current platform
  List<String> _getShellArguments(String shell) {
    if (Platform.isWindows) {
      // Check if using PowerShell
      if (shell.toLowerCase().contains('powershell') || shell.toLowerCase().contains('pwsh')) {
        // -NoLogo: Hides banner
        // -NoExit: Keeps shell running
        // -Command -: Makes it interactive
        return ['-NoLogo', '-NoExit'];
      }
      // cmd.exe doesn't need special args
      return [];
    }
    // Unix shells - use interactive login mode
    return ['-l'];
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
    final shellArgs = _getShellArguments(shell);
    _currentDirectory = Platform.environment['HOME'] ?? 
                        Platform.environment['USERPROFILE'] ?? 
                        Directory.current.path;

    try {
      _pty = Pty.start(
        shell,
        arguments: shellArgs,
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
    // Use UTF-8 encoding for proper character handling
    _pty!.write(Uint8List.fromList(utf8.encode(data)));
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
