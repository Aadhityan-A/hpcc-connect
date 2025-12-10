import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:xterm/xterm.dart';

import '../services/local_terminal_service.dart';

/// Provider for managing local terminal state
class LocalTerminalProvider extends ChangeNotifier {
  final LocalTerminalService _service = LocalTerminalService();
  Terminal? _terminal;
  StreamSubscription<String>? _outputSubscription;
  bool _isInitialized = false;
  String? _errorMessage;

  /// The terminal instance
  Terminal? get terminal => _terminal;
  
  /// Whether the terminal is initialized
  bool get isInitialized => _isInitialized;
  
  /// Whether local terminal is supported on this platform
  bool get isSupported => LocalTerminalService.isSupported;
  
  /// Current working directory
  String get currentDirectory => _service.currentDirectory;
  
  /// Error message if initialization failed
  String? get errorMessage => _errorMessage;

  /// Initialize the local terminal
  Future<void> initializeTerminal({
    required int width,
    required int height,
  }) async {
    if (!isSupported) {
      _errorMessage = 'Local terminal is not available on ${Platform.operatingSystem}';
      notifyListeners();
      return;
    }

    try {
      _errorMessage = null;
      
      // Create terminal instance
      _terminal = Terminal(
        maxLines: 10000,
      );

      // Listen for terminal input and send to local shell
      _terminal!.onOutput = (data) {
        _service.write(data);
      };

      _terminal!.onResize = (width, height, pixelWidth, pixelHeight) {
        _service.resize(width, height);
      };

      // Start the local shell
      await _service.start(
        columns: width,
        rows: height,
      );

      // Listen for shell output and write to terminal
      _outputSubscription = _service.output.listen((data) {
        _terminal!.write(data);
      });

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to start local terminal: $e';
      _isInitialized = false;
      notifyListeners();
    }
  }

  /// Resize the terminal
  void resizeTerminal(int width, int height) {
    _service.resize(width, height);
  }

  /// Write data directly to the terminal PTY
  void writeToTerminal(String data) {
    _service.write(data);
  }

  /// Clear the terminal screen
  void clearTerminal() {
    _terminal?.buffer.clear();
    _terminal?.buffer.setCursor(0, 0);
    // Send clear command to shell
    if (Platform.isWindows) {
      _service.write('cls\r');
    } else {
      _service.write('clear\r');
    }
    notifyListeners();
  }

  /// Dispose the terminal
  void disposeTerminal() {
    _outputSubscription?.cancel();
    _outputSubscription = null;
    _service.stop();
    _terminal = null;
    _isInitialized = false;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    disposeTerminal();
    _service.dispose();
    super.dispose();
  }
}
