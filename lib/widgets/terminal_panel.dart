import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:xterm/xterm.dart';

import '../providers/connection_provider.dart';
import '../providers/file_browser_provider.dart';
import '../providers/terminal_provider.dart';
import '../providers/local_terminal_provider.dart';
import '../services/autocomplete_models.dart';
import '../services/autocomplete_service.dart';
import '../services/local_terminal_service.dart';

/// VS Code-style Terminal panel with SSH and Local terminal tabs
/// Features:
/// - IntelliSense autocomplete with command/flag/path suggestions
/// - Command history search (Ctrl+R)
/// - Recent directories (Ctrl+G)
/// - Quick fixes for common errors
/// - Command decorations (exit code indicators)
class TerminalPanel extends StatefulWidget {
  const TerminalPanel({super.key});

  @override
  State<TerminalPanel> createState() => _TerminalPanelState();
}

class _TerminalPanelState extends State<TerminalPanel> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TerminalController _sshTerminalController = TerminalController();
  final TerminalController _localTerminalController = TerminalController();
  final FocusNode _sshFocusNode = FocusNode();
  final FocusNode _localFocusNode = FocusNode();
  
  // Autocomplete
  final AutocompleteService _autocompleteService = AutocompleteService();
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  List<AutocompleteSuggestion> _suggestions = [];
  int _selectedSuggestionIndex = 0;
  Timer? _autocompleteDebounce;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  // History search mode
  bool _historySearchMode = false;
  List<CommandHistoryEntry> _historyResults = [];
  
  // Directory search mode
  bool _directorySearchMode = false;
  List<String> _directoryResults = [];
  
  // Quick fixes
  List<QuickFixSuggestion> _quickFixes = [];
  bool _showQuickFixes = false;
  
  // Last command tracking
  String _lastCommand = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _inputController.addListener(_onInputChanged);
    _inputFocusNode.addListener(_onInputFocusChanged);
    
    // Initialize autocomplete service
    _autocompleteService.initialize();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _sshTerminalController.dispose();
    _localTerminalController.dispose();
    _sshFocusNode.dispose();
    _localFocusNode.dispose();
    _inputController.dispose();
    _inputFocusNode.removeListener(_onInputFocusChanged);
    _inputFocusNode.dispose();
    _autocompleteDebounce?.cancel();
    _removeOverlay();
    super.dispose();
  }

  void _onTabChanged() {
    setState(() {});
    _removeOverlay();
    _resetModes();
  }

  void _onInputFocusChanged() {
    if (!_inputFocusNode.hasFocus) {
      _removeOverlay();
    }
  }

  void _resetModes() {
    setState(() {
      _historySearchMode = false;
      _directorySearchMode = false;
      _showQuickFixes = false;
    });
  }

  void _onInputChanged() {
    _autocompleteDebounce?.cancel();
    
    final input = _inputController.text;
    
    // Handle history search mode
    if (_historySearchMode) {
      _updateHistorySearch(input);
      return;
    }
    
    // Handle directory search mode
    if (_directorySearchMode) {
      _updateDirectorySearch(input);
      return;
    }
    
    // Check for trigger characters
    String? triggerChar;
    if (input.isNotEmpty) {
      final lastChar = input[input.length - 1];
      if (lastChar == '-' || lastChar == '/' || lastChar == Platform.pathSeparator) {
        triggerChar = lastChar;
      }
    }
    
    _autocompleteDebounce = Timer(const Duration(milliseconds: 100), () {
      _updateSuggestions(triggerCharacter: triggerChar);
    });
  }

  void _updateHistorySearch(String query) {
    final results = _autocompleteService.searchHistory(query);
    setState(() {
      _historyResults = results;
      _selectedSuggestionIndex = 0;
    });
    _showHistoryOverlay();
  }

  void _updateDirectorySearch(String query) {
    final results = _autocompleteService.searchDirectories(query);
    setState(() {
      _directoryResults = results;
      _selectedSuggestionIndex = 0;
    });
    _showDirectoryOverlay();
  }

  Future<void> _updateSuggestions({String? triggerCharacter, bool autoTrigger = false}) async {
    final input = _inputController.text;
    if (input.isEmpty) {
      _hideSuggestions();
      return;
    }

    // Determine current directory based on active terminal
    String currentDir;
    Future<String> Function(String)? commandRunner;
    DirectoryFetcher? directoryFetcher;
    String? homeDirectory;

    if (_tabController.index == 0) {
      // Local terminal
      final localProvider = context.read<LocalTerminalProvider>();
      currentDir = localProvider.currentDirectory.isNotEmpty 
          ? localProvider.currentDirectory 
          : Platform.environment['HOME'] ?? '/';
      homeDirectory = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      
      commandRunner = (cmd) async {
        final parts = cmd.split(' ');
        if (parts.isEmpty) return '';
        try {
          final result = await Process.run(parts[0], parts.sublist(1));
          return result.stdout.toString();
        } catch (e) {
          return '';
        }
      };
    } else {
      // SSH terminal
      final terminalProvider = context.read<TerminalProvider>();
      final connectionProvider = context.read<ConnectionProvider>();
      final fileBrowserProvider = context.read<FileBrowserProvider>();

      currentDir = fileBrowserProvider.remotePath.isNotEmpty
          ? fileBrowserProvider.remotePath
          : '/';
      homeDirectory = fileBrowserProvider.remoteHomePath.isNotEmpty
          ? fileBrowserProvider.remoteHomePath
          : null;

      if (terminalProvider.isInitialized) {
        commandRunner = (cmd) => terminalProvider.runCommand(cmd);
      }

      directoryFetcher = connectionProvider.sshService.listRemoteDirectory;
    }

    final suggestions = await _autocompleteService.getSuggestions(
      input,
      currentDir,
      triggerCharacter: triggerCharacter,
      autoTrigger: autoTrigger,
      commandRunner: commandRunner,
      directoryFetcher: directoryFetcher,
      homeDirectory: homeDirectory,
    );

    if (mounted && input == _inputController.text) {
      setState(() {
        _suggestions = suggestions;
        _selectedSuggestionIndex = 0;
      });
      
      if (suggestions.isNotEmpty) {
        _showSuggestionsOverlay();
      } else {
        _hideSuggestions();
      }
    }
  }

  void _showSuggestionsOverlay() {
    _removeOverlay();
    
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: 400,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, -8),
          followerAnchor: Alignment.bottomLeft,
          targetAnchor: Alignment.topLeft,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            color: const Color(0xFFF5F5F5),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE0E0E0)),
                borderRadius: BorderRadius.circular(8),
              ),
              constraints: const BoxConstraints(maxHeight: 300),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8E8E8),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lightbulb_outline, size: 14, color: Colors.amber),
                        const SizedBox(width: 6),
                        Text(
                          'Suggestions (${_suggestions.length})',
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 11,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Tab to insert',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: _suggestions.length,
                      itemBuilder: (context, index) => _buildSuggestionItem(index),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  Widget _buildSuggestionItem(int index) {
    final suggestion = _suggestions[index];
    final isSelected = index == _selectedSuggestionIndex;
    
    return InkWell(
      onTap: () => _applySuggestion(suggestion),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        color: isSelected ? const Color(0xFFBBDEFB) : Colors.transparent,
        child: Row(
          children: [
            _getSuggestionIcon(suggestion),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.displayText,
                    style: TextStyle(
                      color: Colors.black,
                      fontFamily: 'monospace',
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (suggestion.description.isNotEmpty)
                    Text(
                      suggestion.description,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            _getSuggestionTypeLabel(suggestion),
          ],
        ),
      ),
    );
  }

  Widget _getSuggestionIcon(AutocompleteSuggestion suggestion) {
    IconData icon;
    Color color;
    
    switch (suggestion.type) {
      case SuggestionType.command:
        icon = Icons.terminal;
        color = Colors.blue;
        break;
      case SuggestionType.subcommand:
        icon = Icons.subdirectory_arrow_right;
        color = Colors.cyan;
        break;
      case SuggestionType.flag:
        icon = Icons.flag;
        color = Colors.orange;
        break;
      case SuggestionType.history:
        icon = Icons.history;
        color = Colors.purple;
        break;
      case SuggestionType.directory:
        icon = Icons.folder;
        color = Colors.amber;
        break;
      case SuggestionType.executable:
        icon = Icons.play_circle_filled;
        color = Colors.green;
        break;
      case SuggestionType.codeFile:
        icon = Icons.code;
        color = Colors.lightBlue;
        break;
      case SuggestionType.configFile:
        icon = Icons.settings;
        color = Colors.grey;
        break;
      case SuggestionType.document:
        icon = Icons.description;
        color = Colors.lightGreen;
        break;
      case SuggestionType.image:
        icon = Icons.image;
        color = Colors.pink;
        break;
      case SuggestionType.archive:
        icon = Icons.archive;
        color = Colors.brown;
      case SuggestionType.script:
        icon = Icons.code;
        color = Colors.teal;
      case SuggestionType.file:
        icon = Icons.insert_drive_file;
        color = Colors.grey;
    }
    
    return Icon(icon, size: 16, color: color);
  }

  Widget _getSuggestionTypeLabel(AutocompleteSuggestion suggestion) {
    String label;
    Color color;
    
    switch (suggestion.type) {
      case SuggestionType.command:
        label = 'cmd';
        color = Colors.blue;
        break;
      case SuggestionType.subcommand:
        label = 'sub';
        color = Colors.cyan;
        break;
      case SuggestionType.flag:
        label = 'flag';
        color = Colors.orange;
        break;
      case SuggestionType.history:
        label = 'hist';
        color = Colors.purple;
        break;
      case SuggestionType.directory:
        label = 'dir';
        color = Colors.amber;
        break;
      default:
        label = 'file';
        color = Colors.grey;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showHistoryOverlay() {
    _removeOverlay();
    
    if (_historyResults.isEmpty) return;
    
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: 500,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, -8),
          followerAnchor: Alignment.bottomLeft,
          targetAnchor: Alignment.topLeft,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            color: const Color(0xFFF5F5F5),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE0E0E0)),
                borderRadius: BorderRadius.circular(8),
              ),
              constraints: const BoxConstraints(maxHeight: 350),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8E8E8),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.history, size: 16, color: Colors.purple),
                        const SizedBox(width: 8),
                        const Text(
                          'Run Recent Command',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Ctrl+R',
                            style: TextStyle(color: Colors.black54, fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: _historyResults.length,
                      itemBuilder: (context, index) {
                        final entry = _historyResults[index];
                        final isSelected = index == _selectedSuggestionIndex;
                        
                        return InkWell(
                          onTap: () => _applyHistoryEntry(entry),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            color: isSelected ? const Color(0xFFBBDEFB) : Colors.transparent,
                            child: Row(
                              children: [
                                // Exit code indicator
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: entry.succeeded ? Colors.green : Colors.red,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.command,
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontFamily: 'monospace',
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (entry.directory != null)
                                        Text(
                                          entry.directory!,
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                            fontSize: 11,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  _formatTimestamp(entry.timestamp),
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _showDirectoryOverlay() {
    _removeOverlay();
    
    if (_directoryResults.isEmpty) return;
    
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: 450,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, -8),
          followerAnchor: Alignment.bottomLeft,
          targetAnchor: Alignment.topLeft,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            color: const Color(0xFFF5F5F5),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE0E0E0)),
                borderRadius: BorderRadius.circular(8),
              ),
              constraints: const BoxConstraints(maxHeight: 300),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8E8E8),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.folder_open, size: 16, color: Colors.amber),
                        const SizedBox(width: 8),
                        const Text(
                          'Go to Recent Directory',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Ctrl+G',
                            style: TextStyle(color: Colors.black54, fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: _directoryResults.length,
                      itemBuilder: (context, index) {
                        final dir = _directoryResults[index];
                        final isSelected = index == _selectedSuggestionIndex;
                        
                        return InkWell(
                          onTap: () => _applyDirectory(dir),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            color: isSelected ? const Color(0xFFBBDEFB) : Colors.transparent,
                            child: Row(
                              children: [
                                const Icon(Icons.folder, size: 16, color: Colors.amber),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    dir,
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontFamily: 'monospace',
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _showQuickFixesOverlay() {
    if (_quickFixes.isEmpty) return;
    
    _removeOverlay();
    
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: 400,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, -8),
          followerAnchor: Alignment.bottomLeft,
          targetAnchor: Alignment.topLeft,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            color: const Color(0xFFF5F5F5),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE0E0E0)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8E8E8),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lightbulb, size: 16, color: Colors.amber),
                        const SizedBox(width: 8),
                        const Text(
                          'Quick Fix',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, size: 14, color: Colors.grey),
                          onPressed: _removeOverlay,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  ...List.generate(_quickFixes.length, (index) {
                    final fix = _quickFixes[index];
                    final isSelected = index == _selectedSuggestionIndex;
                    
                    return InkWell(
                      onTap: () => _applyQuickFix(fix),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        color: isSelected ? const Color(0xFFBBDEFB) : Colors.transparent,
                        child: Row(
                          children: [
                            const Icon(Icons.auto_fix_high, size: 16, color: Colors.blue),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fix.title,
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    fix.command,
                                    style: const TextStyle(
                                      color: Colors.blue,
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (fix.description.isNotEmpty)
                                    Text(
                                      fix.description,
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() {
      _showQuickFixes = true;
    });
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${timestamp.month}/${timestamp.day}';
  }

  void _hideSuggestions() {
    _removeOverlay();
    setState(() {
      _suggestions = [];
    });
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry?.dispose();
    _overlayEntry = null;
    if (mounted) {
      setState(() {
        _showQuickFixes = false;
      });
    }
  }

  void _applySuggestion(AutocompleteSuggestion suggestion) {
    final input = _inputController.text;
    final text = suggestion.text;
    
    // Find the last word/argument being completed
    // We need to handle paths properly - a path like "Documents/images/" is one argument
    int lastArgStart = 0;
    bool inQuote = false;
    String quoteChar = '';
    
    for (int i = 0; i < input.length; i++) {
      final char = input[i];
      if ((char == '"' || char == "'") && !inQuote) {
        inQuote = true;
        quoteChar = char;
      } else if (char == quoteChar && inQuote) {
        inQuote = false;
      } else if (char == ' ' && !inQuote) {
        lastArgStart = i + 1;
      }
    }
    
    // Build the new input by replacing only the last argument
    final prefix = input.substring(0, lastArgStart);
    
    // Don't add trailing space for directories (they end with /)
    // This allows user to continue typing the path
    final isDirectory = suggestion.isDirectory || text.endsWith('/') || text.endsWith(Platform.pathSeparator);
    final newText = isDirectory ? '$prefix$text' : '$prefix$text ';
    
    _inputController.text = newText;
    _inputController.selection = TextSelection.fromPosition(
      TextPosition(offset: _inputController.text.length),
    );
    
    _inputFocusNode.requestFocus();
    
    // Immediately trigger new suggestions for VS Code-style continuous IntelliSense
    // Use post-frame callback to ensure UI has updated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateSuggestions(autoTrigger: true);
      }
    });
  }

  void _applyHistoryEntry(CommandHistoryEntry entry) {
    _inputController.text = entry.command;
    _inputController.selection = TextSelection.fromPosition(
      TextPosition(offset: _inputController.text.length),
    );
    _removeOverlay();
    setState(() {
      _historySearchMode = false;
      _historyResults = [];
    });
    _inputFocusNode.requestFocus();
  }

  void _applyDirectory(String directory) {
    _inputController.text = 'cd $directory';
    _inputController.selection = TextSelection.fromPosition(
      TextPosition(offset: _inputController.text.length),
    );
    _removeOverlay();
    setState(() {
      _directorySearchMode = false;
      _directoryResults = [];
    });
    _inputFocusNode.requestFocus();
  }

  void _applyQuickFix(QuickFixSuggestion fix) {
    _inputController.text = fix.command;
    _removeOverlay();
    _submitCommand();
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    
    final key = event.logicalKey;
    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    
    // Ctrl+R: History search
    if (isCtrl && key == LogicalKeyboardKey.keyR) {
      setState(() {
        _historySearchMode = true;
        _directorySearchMode = false;
        _inputController.clear();
      });
      _updateHistorySearch('');
      return KeyEventResult.handled;
    }
    
    // Ctrl+G: Directory search
    if (isCtrl && key == LogicalKeyboardKey.keyG) {
      setState(() {
        _directorySearchMode = true;
        _historySearchMode = false;
        _inputController.clear();
      });
      _updateDirectorySearch('');
      return KeyEventResult.handled;
    }
    
    // Handle overlay navigation
    if (_overlayEntry != null) {
      final itemCount = _historySearchMode 
          ? _historyResults.length 
          : _directorySearchMode 
              ? _directoryResults.length 
              : _showQuickFixes 
                  ? _quickFixes.length 
                  : _suggestions.length;
      
      if (itemCount > 0) {
        if (key == LogicalKeyboardKey.arrowDown) {
          setState(() {
            _selectedSuggestionIndex = (_selectedSuggestionIndex + 1) % itemCount;
          });
          _refreshOverlay();
          return KeyEventResult.handled;
        } else if (key == LogicalKeyboardKey.arrowUp) {
          setState(() {
            _selectedSuggestionIndex = (_selectedSuggestionIndex - 1 + itemCount) % itemCount;
          });
          _refreshOverlay();
          return KeyEventResult.handled;
        } else if (key == LogicalKeyboardKey.tab) {
          // Tab: Insert the selected suggestion
          if (_historySearchMode && _historyResults.isNotEmpty) {
            _applyHistoryEntry(_historyResults[_selectedSuggestionIndex]);
            return KeyEventResult.handled;
          } else if (_directorySearchMode && _directoryResults.isNotEmpty) {
            _applyDirectory(_directoryResults[_selectedSuggestionIndex]);
            return KeyEventResult.handled;
          } else if (_showQuickFixes && _quickFixes.isNotEmpty) {
            _applyQuickFix(_quickFixes[_selectedSuggestionIndex]);
            return KeyEventResult.handled;
          } else if (_suggestions.isNotEmpty) {
            _applySuggestion(_suggestions[_selectedSuggestionIndex]);
            return KeyEventResult.handled;
          }
        } else if (key == LogicalKeyboardKey.enter) {
          // Enter: Execute the current command in the input box
          _hideSuggestions();
          _submitCommand();
          return KeyEventResult.handled;
        } else if (key == LogicalKeyboardKey.escape) {
          _removeOverlay();
          _resetModes();
          return KeyEventResult.handled;
        }
      }
    }
    
    return KeyEventResult.ignored;
  }

  void _refreshOverlay() {
    if (_historySearchMode) {
      _showHistoryOverlay();
    } else if (_directorySearchMode) {
      _showDirectoryOverlay();
    } else if (_showQuickFixes) {
      _showQuickFixesOverlay();
    } else if (_suggestions.isNotEmpty) {
      _showSuggestionsOverlay();
    }
  }

  void _submitCommand() {
    final command = _inputController.text;
    if (command.isEmpty) return;

    // Track command in history
    String? currentDir;
    if (_tabController.index == 0) {
      final localProvider = context.read<LocalTerminalProvider>();
      currentDir = localProvider.currentDirectory;
    }
    _autocompleteService.addToHistory(command, directory: currentDir);

    _lastCommand = command;

    // Send to appropriate terminal
    if (_tabController.index == 0) {
      // Local terminal
      final localProvider = context.read<LocalTerminalProvider>();
      if (localProvider.isInitialized) {
        localProvider.writeToTerminal('$command\n');
        
        // Track directory changes
        if (command.startsWith('cd ')) {
          final dir = command.substring(3).trim();
          if (dir.isNotEmpty) {
            _autocompleteService.addRecentDirectory(dir);
          }
        }
      }
    } else {
      // SSH terminal
      final terminalProvider = context.read<TerminalProvider>();
      if (terminalProvider.isInitialized && terminalProvider.terminal != null) {
        // Write directly to terminal
        terminalProvider.terminal!.write('$command\r');
      }
    }

    _inputController.clear();
    _hideSuggestions();
    _resetModes();
  }

  /// Check for quick fixes based on command output
  /// This can be called when terminal output is received to suggest fixes
  // ignore: unused_element
  void _checkForQuickFixes(String output) {
    final fixes = _autocompleteService.getQuickFixes(output, _lastCommand);
    if (fixes.isNotEmpty) {
      setState(() {
        _quickFixes = fixes;
        _selectedSuggestionIndex = 0;
      });
      _showQuickFixesOverlay();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ConnectionProvider, TerminalProvider>(
      builder: (context, connectionProvider, terminalProvider, _) {
        return Container(
          color: const Color(0xFF1E1E1E),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context, terminalProvider),
              const Divider(height: 1, color: Colors.grey),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildLocalTerminal(context),
                    _buildSshTerminal(context, connectionProvider, terminalProvider),
                  ],
                ),
              ),
              _buildInputBar(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, TerminalProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: const Color(0xFF2D2D2D),
      child: Row(
        children: [
          const Icon(Icons.terminal, size: 18, color: Colors.white70),
          const SizedBox(width: 8),
          Expanded(
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorColor: Colors.blue,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              dividerColor: Colors.transparent,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.computer,
                        size: 14,
                        color: LocalTerminalService.isSupported 
                            ? Colors.blue 
                            : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      const Text('Local'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud,
                        size: 14,
                        color: context.watch<ConnectionProvider>().isConnected 
                            ? Colors.green 
                            : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      const Text('SSH'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_tabController.index == 0)
            Consumer<LocalTerminalProvider>(
              builder: (context, localProvider, _) {
                if (localProvider.isInitialized) {
                  return IconButton(
                    icon: const Icon(Icons.clear_all, size: 18, color: Colors.white70),
                    onPressed: localProvider.clearTerminal,
                    tooltip: 'Clear terminal',
                    splashRadius: 18,
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          if (_tabController.index == 1 && provider.isInitialized)
            IconButton(
              icon: const Icon(Icons.clear_all, size: 18, color: Colors.white70),
              onPressed: provider.clearTerminal,
              tooltip: 'Clear terminal',
              splashRadius: 18,
            ),
        ],
      ),
    );
  }

  Widget _buildSshTerminal(
    BuildContext context,
    ConnectionProvider connectionProvider,
    TerminalProvider terminalProvider,
  ) {
    final isConnected = connectionProvider.isConnected;
    final isInitialized = terminalProvider.isInitialized;
    final terminal = terminalProvider.terminal;

    if (!isConnected) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_outlined, size: 64, color: Colors.grey.shade600),
            const SizedBox(height: 16),
            Text(
              'Not connected',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Select a connection from the sidebar and connect to start SSH terminal',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (!isInitialized || terminal == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Initializing SSH terminal...', style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }

    return _buildTerminalView(
      terminal,
      _sshTerminalController,
      _sshFocusNode,
      (width, height) => terminalProvider.resizeTerminal(width, height),
    );
  }

  Widget _buildLocalTerminal(BuildContext context) {
    return Consumer<LocalTerminalProvider>(
      builder: (context, localProvider, _) {
        if (!LocalTerminalService.isSupported) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.block, size: 64, color: Colors.grey.shade600),
                const SizedBox(height: 16),
                Text(
                  'Local terminal not available',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Local terminal is only available on desktop platforms\n(Linux, macOS, Windows)',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (localProvider.errorMessage != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
                const SizedBox(height: 16),
                Text(
                  'Failed to start local terminal',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    localProvider.errorMessage!,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _initializeLocalTerminal(localProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (!localProvider.isInitialized || localProvider.terminal == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!localProvider.isInitialized && localProvider.errorMessage == null) {
              _initializeLocalTerminal(localProvider);
            }
          });

          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Starting local terminal...', style: TextStyle(color: Colors.white70)),
              ],
            ),
          );
        }

        return _buildTerminalView(
          localProvider.terminal!,
          _localTerminalController,
          _localFocusNode,
          (width, height) => localProvider.resizeTerminal(width, height),
        );
      },
    );
  }

  void _initializeLocalTerminal(LocalTerminalProvider provider) {
    provider.initializeTerminal(width: 80, height: 24);
  }

  Widget _buildTerminalView(
    Terminal terminal,
    TerminalController controller,
    FocusNode focusNode,
    void Function(int, int) onResize,
  ) {
    const padding = EdgeInsets.all(8);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellSize = _measureTerminalCellSize(context);
        final cellWidth = cellSize.width <= 0 ? 1.0 : cellSize.width;
        final cellHeight = cellSize.height <= 0 ? 1.0 : cellSize.height;

        final usableWidth = (constraints.maxWidth - padding.horizontal).clamp(0.0, double.infinity);
        final usableHeight = (constraints.maxHeight - padding.vertical).clamp(0.0, double.infinity);

        final width = math.max(1, (usableWidth / cellWidth).floor());
        final height = math.max(1, (usableHeight / cellHeight).floor());

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (width > 0 && height > 0) {
            onResize(width, height);
          }
        });

        return GestureDetector(
          onTap: () => focusNode.requestFocus(),
          child: TerminalView(
            terminal,
            controller: controller,
            focusNode: focusNode,
            autofocus: true,
            padding: padding,
            backgroundOpacity: 0,
            theme: _buildTerminalTheme(),
            textStyle: const TerminalStyle(
              fontSize: 14,
              fontFamily: 'monospace',
            ),
          ),
        );
      },
    );
  }

  Size _measureTerminalCellSize(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    final textScaler = mediaQuery?.textScaler ?? TextScaler.noScaling;
    final painter = TextPainter(
      text: const TextSpan(
        text: 'W',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 14,
          height: 1.0,
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )
      ..layout();

    return painter.size;
  }

  Widget _buildInputBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: const Color(0xFF2D2D2D),
      child: CompositedTransformTarget(
        link: _layerLink,
        child: Focus(
          onKeyEvent: (node, event) => _handleKeyEvent(event),
          child: Row(
            children: [
              // Mode indicator
              if (_historySearchMode)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history, size: 14, color: Colors.purple),
                      SizedBox(width: 4),
                      Text(
                        'History',
                        style: TextStyle(color: Colors.purple, fontSize: 11),
                      ),
                    ],
                  ),
                )
              else if (_directorySearchMode)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.folder, size: 14, color: Colors.amber),
                      SizedBox(width: 4),
                      Text(
                        'Directory',
                        style: TextStyle(color: Colors.amber, fontSize: 11),
                      ),
                    ],
                  ),
                )
              else
                Text(
                  _tabController.index == 0 ? 'Local >' : 'SSH >',
                  style: const TextStyle(
                    color: Colors.green,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _inputController,
                  focusNode: _inputFocusNode,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                  ),
                  decoration: InputDecoration(
                    hintText: _historySearchMode 
                        ? 'Search history...' 
                        : _directorySearchMode
                            ? 'Search directories...'
                            : 'Type command... (Tab for autocomplete, Ctrl+R for history)',
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onSubmitted: (_) => _submitCommand(),
                ),
              ),
              // Keyboard shortcuts help
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildShortcutHint('Ctrl+R', Icons.history),
                  const SizedBox(width: 4),
                  _buildShortcutHint('Ctrl+G', Icons.folder),
                ],
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send, size: 18, color: Colors.blue),
                onPressed: _submitCommand,
                tooltip: 'Send command',
                splashRadius: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShortcutHint(String shortcut, IconData icon) {
    return Tooltip(
      message: shortcut,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey.shade800,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, size: 12, color: Colors.grey.shade500),
      ),
    );
  }

  TerminalTheme _buildTerminalTheme() {
    return const TerminalTheme(
      cursor: Color(0xFFFFFFFF),
      selection: Color(0x80FFFFFF),
      foreground: Color(0xFFD4D4D4),
      background: Color(0xFF1E1E1E),
      black: Color(0xFF000000),
      red: Color(0xFFCD3131),
      green: Color(0xFF0DBC79),
      yellow: Color(0xFFE5E510),
      blue: Color(0xFF2472C8),
      magenta: Color(0xFFBC3FBC),
      cyan: Color(0xFF11A8CD),
      white: Color(0xFFE5E5E5),
      brightBlack: Color(0xFF666666),
      brightRed: Color(0xFFF14C4C),
      brightGreen: Color(0xFF23D18B),
      brightYellow: Color(0xFFF5F543),
      brightBlue: Color(0xFF3B8EEA),
      brightMagenta: Color(0xFFD670D6),
      brightCyan: Color(0xFF29B8DB),
      brightWhite: Color(0xFFFFFFFF),
      searchHitBackground: Color(0xFFFFFF00),
      searchHitBackgroundCurrent: Color(0xFFFF6600),
      searchHitForeground: Color(0xFF000000),
    );
  }
}
