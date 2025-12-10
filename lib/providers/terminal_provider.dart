import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:xterm/xterm.dart';

import '../services/ssh_service.dart';

class TerminalProvider extends ChangeNotifier {
  SSHService? _sshService;
  Terminal? _terminal;
  StreamSubscription<String>? _outputSubscription;
  bool _isInitialized = false;
  String _currentDirectory = '';
  String _homeDirectory = '';

  Terminal? get terminal => _terminal;
  bool get isInitialized => _isInitialized;
  String get currentDirectory => _currentDirectory;
  String get homeDirectory => _homeDirectory;

  void setSshService(SSHService service) {
    _sshService = service;
  }

  Future<void> initializeTerminal({
    required int width,
    required int height,
  }) async {
    if (_sshService == null || !_sshService!.isConnected) {
      throw StateError('SSH not connected');
    }

    // Create terminal
    _terminal = Terminal(
      maxLines: 10000,
    );

    // Listen for terminal input and send to SSH
    _terminal!.onOutput = (data) {
      _sshService!.writeToShell(data);
    };

    _terminal!.onResize = (width, height, pixelWidth, pixelHeight) {
      _sshService?.resizeTerminal(width, height);
    };

    // Start shell session
    await _sshService!.startShell(
      width: width,
      height: height,
    );

    // Listen for SSH output and write to terminal
    _outputSubscription = _sshService!.terminalOutput.listen((data) {
      _terminal!.write(data);
    });

    await _initializeRemoteDirectories();

    _isInitialized = true;
    notifyListeners();
  }

  void resizeTerminal(int width, int height) {
    _sshService?.resizeTerminal(width, height);
  }

  /// Write data to the SSH shell (sends input to PTY)
  void writeToShell(String data) {
    _sshService?.writeToShell(data);
  }

  void clearTerminal() {
    _terminal?.buffer.clear();
    _terminal?.buffer.setCursor(0, 0);
    notifyListeners();
  }

  void disposeTerminal() {
    _outputSubscription?.cancel();
    _outputSubscription = null;
    _terminal = null;
    _isInitialized = false;
    _currentDirectory = '';
    _homeDirectory = '';
    notifyListeners();
  }

  Future<String> runCommand(String command) async {
    if (_sshService == null || !_sshService!.isConnected) {
      throw StateError('SSH not connected');
    }
    final workingDir = _effectiveRemoteDirectory();
    final cdPrefix = workingDir.isNotEmpty
        ? 'cd "${_escapePathForShell(workingDir)}" && '
        : '';
    return _sshService!.runCommand('$cdPrefix$command');
  }

  String? updateRemoteDirectoryFromCommand(String command) {
    if (command.trim().isEmpty) return null;

    final normalized = command.trim();

    if (normalized == 'cd' || normalized == 'cd ~') {
      _setCurrentDirectory(_homeOrRoot());
      return _currentDirectory;
    }

    final match = RegExp(r'^cd\s+([^;&|]+)', caseSensitive: false)
      .firstMatch(normalized);
    if (match == null) {
      return null;
    }

    final rawTarget = match.group(1)?.trim();
    if (rawTarget == null || rawTarget.isEmpty || rawTarget == '-') {
      return null;
    }

    final cleaned = _stripQuotes(rawTarget);
    final resolved = _resolveRemotePath(cleaned);
    _setCurrentDirectory(resolved);
    return _currentDirectory;
  }

  Future<void> _initializeRemoteDirectories() async {
    _homeDirectory = '';
    _currentDirectory = '';

    if (_sshService == null) return;

    try {
      final remoteHome = await _sshService!.getRemoteHomeDirectory();
      if (remoteHome.isNotEmpty) {
        _homeDirectory = _normalizeRemotePath(remoteHome);
      }
    } catch (_) {
      _homeDirectory = '';
    }

    if (_homeDirectory.isEmpty) {
      _homeDirectory = '/';
    }

    _currentDirectory = _homeDirectory;
    notifyListeners();
  }

  void _setCurrentDirectory(String path) {
    final normalized = _normalizeRemotePath(path);
    if (normalized == _currentDirectory) {
      return;
    }
    _currentDirectory = normalized;
    notifyListeners();
  }

  String _resolveRemotePath(String input) {
    final ctx = p.posix;
    if (input.isEmpty) {
      return _homeOrRoot();
    }

    if (input == '~') {
      return _homeOrRoot();
    }

    if (input.startsWith('~')) {
      final home = _homeOrRoot();
      return _normalizeRemotePath(home + input.substring(1));
    }

    if (ctx.isAbsolute(input)) {
      return _normalizeRemotePath(input);
    }

    final base = _currentDirectory.isNotEmpty ? _currentDirectory : _homeOrRoot();
    return _normalizeRemotePath(ctx.join(base, input));
  }

  String _normalizeRemotePath(String path) {
    if (path.isEmpty) {
      return '/';
    }
    final normalized = p.posix.normalize(path);
    if (normalized.isEmpty || normalized == '.') {
      return '/';
    }
    return normalized;
  }

  String _escapePathForShell(String path) {
    return path.replaceAll('"', r'\"');
  }

  String _homeOrRoot() {
    return _homeDirectory.isNotEmpty ? _homeDirectory : '/';
  }

  String _effectiveRemoteDirectory() {
    if (_currentDirectory.isNotEmpty) {
      return _currentDirectory;
    }
    return _homeOrRoot();
  }

  String _stripQuotes(String value) {
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      return value.substring(1, value.length - 1);
    }
    return value;
  }

  @override
  void dispose() {
    disposeTerminal();
    super.dispose();
  }
}
