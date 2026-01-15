import 'package:flutter/foundation.dart';

/// Enum for terminal types
enum TerminalType {
  local,
  ssh,
}

/// Provider for tracking the active terminal mode
/// This allows other widgets (like the snippet sidebar) to know which terminal
/// is currently active and send commands to the correct terminal.
class TerminalModeProvider extends ChangeNotifier {
  TerminalType _activeTerminal = TerminalType.local;

  /// The currently active terminal type
  TerminalType get activeTerminal => _activeTerminal;

  /// Whether the local terminal is active
  bool get isLocalTerminalActive => _activeTerminal == TerminalType.local;

  /// Whether the SSH terminal is active
  bool get isSshTerminalActive => _activeTerminal == TerminalType.ssh;

  /// Set the active terminal
  void setActiveTerminal(TerminalType type) {
    if (_activeTerminal != type) {
      _activeTerminal = type;
      notifyListeners();
    }
  }

  /// Switch to local terminal
  void switchToLocal() {
    setActiveTerminal(TerminalType.local);
  }

  /// Switch to SSH terminal
  void switchToSsh() {
    setActiveTerminal(TerminalType.ssh);
  }

  /// Toggle between terminals
  void toggle() {
    if (_activeTerminal == TerminalType.local) {
      switchToSsh();
    } else {
      switchToLocal();
    }
  }
}
