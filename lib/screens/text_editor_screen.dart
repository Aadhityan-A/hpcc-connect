import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../providers/editor_provider.dart';
import '../providers/connection_provider.dart';

/// A full-featured text editor screen for viewing and editing files
class TextEditorScreen extends StatefulWidget {
  const TextEditorScreen({super.key});

  @override
  State<TextEditorScreen> createState() => _TextEditorScreenState();
}

class _TextEditorScreenState extends State<TextEditorScreen> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  
  String? _lastSyncedContent;
  bool _showLineNumbers = true;
  double _fontSize = 14.0;
  bool _wordWrap = true;
  
  // Search state
  bool _showSearch = false;
  final TextEditingController _searchController = TextEditingController();
  List<int> _searchMatches = [];
  int _currentMatchIndex = -1;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final provider = context.read<EditorProvider>();
    if (_textController.text != _lastSyncedContent) {
      provider.updateContent(_textController.text);
      _lastSyncedContent = _textController.text;
    }
  }

  void _syncFromProvider(OpenFile? file) {
    if (file != null && file.content != _lastSyncedContent) {
      _lastSyncedContent = file.content;
      _textController.text = file.content;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EditorProvider>(
      builder: (context, provider, _) {
        final activeFile = provider.activeFile;
        
        // Sync content from provider
        _syncFromProvider(activeFile);
        
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Column(
            children: [
              _buildAppBar(context, provider, activeFile),
              if (provider.openFiles.isNotEmpty)
                _buildTabBar(context, provider),
              if (_showSearch)
                _buildSearchBar(context),
              Expanded(
                child: activeFile == null
                    ? _buildEmptyState(context)
                    : activeFile.isLoading
                        ? _buildLoadingState(context)
                        : activeFile.error != null
                            ? _buildErrorState(context, activeFile, provider)
                            : _buildEditor(context, activeFile),
              ),
              _buildStatusBar(context, activeFile),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAppBar(BuildContext context, EditorProvider provider, OpenFile? activeFile) {
    final isConnected = context.watch<ConnectionProvider>().isConnected;
    
    return Container(
      height: 48,
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _handleBack(context, provider),
            tooltip: 'Back',
          ),
          const SizedBox(width: 8),
          Icon(Icons.edit_document, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          Text(
            'Text Editor',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 24),
          // Toolbar buttons
          _ToolbarButton(
            icon: Icons.save,
            tooltip: 'Save (Ctrl+S)',
            onPressed: activeFile != null && !activeFile.isSaving
                ? () => provider.saveActiveFile()
                : null,
          ),
          _ToolbarButton(
            icon: Icons.save_as,
            tooltip: 'Save As',
            onPressed: activeFile != null
                ? () => _showSaveAsDialog(context, provider, activeFile, isConnected)
                : null,
          ),
          const SizedBox(width: 8),
          const VerticalDivider(width: 16),
          const SizedBox(width: 8),
          _ToolbarButton(
            icon: Icons.undo,
            tooltip: 'Undo (Ctrl+Z)',
            onPressed: activeFile != null ? () => _undo() : null,
          ),
          _ToolbarButton(
            icon: Icons.redo,
            tooltip: 'Redo (Ctrl+Y)',
            onPressed: activeFile != null ? () => _redo() : null,
          ),
          const SizedBox(width: 8),
          const VerticalDivider(width: 16),
          const SizedBox(width: 8),
          _ToolbarButton(
            icon: Icons.content_cut,
            tooltip: 'Cut (Ctrl+X)',
            onPressed: activeFile != null ? () => _cut() : null,
          ),
          _ToolbarButton(
            icon: Icons.content_copy,
            tooltip: 'Copy (Ctrl+C)',
            onPressed: activeFile != null ? () => _copy() : null,
          ),
          _ToolbarButton(
            icon: Icons.content_paste,
            tooltip: 'Paste (Ctrl+V)',
            onPressed: activeFile != null ? () => _paste() : null,
          ),
          _ToolbarButton(
            icon: Icons.select_all,
            tooltip: 'Select All (Ctrl+A)',
            onPressed: activeFile != null ? () => _selectAll() : null,
          ),
          const SizedBox(width: 8),
          const VerticalDivider(width: 16),
          const SizedBox(width: 8),
          _ToolbarButton(
            icon: Icons.search,
            tooltip: 'Find (Ctrl+F)',
            onPressed: activeFile != null ? () => _toggleSearch() : null,
            isActive: _showSearch,
          ),
          const Spacer(),
          // View options
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings, size: 20),
            tooltip: 'Editor Settings',
            onSelected: (value) {
              switch (value) {
                case 'line_numbers':
                  setState(() => _showLineNumbers = !_showLineNumbers);
                  break;
                case 'word_wrap':
                  setState(() => _wordWrap = !_wordWrap);
                  break;
                case 'font_increase':
                  setState(() => _fontSize = (_fontSize + 1).clamp(10, 32));
                  break;
                case 'font_decrease':
                  setState(() => _fontSize = (_fontSize - 1).clamp(10, 32));
                  break;
              }
            },
            itemBuilder: (context) => [
              CheckedPopupMenuItem(
                value: 'line_numbers',
                checked: _showLineNumbers,
                child: const Text('Show Line Numbers'),
              ),
              CheckedPopupMenuItem(
                value: 'word_wrap',
                checked: _wordWrap,
                child: const Text('Word Wrap'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'font_increase',
                child: Row(
                  children: [
                    Icon(Icons.add, size: 18),
                    SizedBox(width: 8),
                    Text('Increase Font Size'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'font_decrease',
                child: Row(
                  children: [
                    Icon(Icons.remove, size: 18),
                    SizedBox(width: 8),
                    Text('Decrease Font Size'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(BuildContext context, EditorProvider provider) {
    return Container(
      height: 36,
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF252526)
          : Colors.grey.shade100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: provider.openFiles.length,
        itemBuilder: (context, index) {
          final file = provider.openFiles[index];
          final isActive = file.id == provider.activeFile?.id;
          
          return _FileTab(
            file: file,
            isActive: isActive,
            onTap: () => provider.setActiveFile(file.id),
            onClose: () => _closeFileTab(context, provider, file),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF2D2D2D)
          : Colors.grey.shade200,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: TextStyle(fontSize: _fontSize),
              decoration: InputDecoration(
                hintText: 'Search...',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              onChanged: (_) => _performSearch(),
              onSubmitted: (_) => _findNext(),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _searchMatches.isEmpty
                ? 'No matches'
                : '${_currentMatchIndex + 1} of ${_searchMatches.length}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up, size: 20),
            onPressed: _findPrevious,
            tooltip: 'Previous (Shift+Enter)',
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, size: 20),
            onPressed: _findNext,
            tooltip: 'Next (Enter)',
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: _toggleSearch,
            tooltip: 'Close (Esc)',
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.edit_document,
            size: 64,
            color: Theme.of(context).hintColor,
          ),
          const SizedBox(height: 16),
          Text(
            'No file open',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).hintColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Double-click a file in the file browser to open it',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).hintColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading file...'),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, OpenFile file, EditorProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load file',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              file.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              provider.closeFile(file.id);
              if (file.isRemote) {
                provider.openRemoteFile(file.originalPath);
              } else {
                provider.openLocalFile(file.originalPath);
              }
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor(BuildContext context, OpenFile file) {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (event) => _handleKeyEvent(event, context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_showLineNumbers)
            _buildLineNumbers(context),
          Expanded(
            child: _buildTextArea(context, file),
          ),
        ],
      ),
    );
  }

  Widget _buildLineNumbers(BuildContext context) {
    final lineCount = '\n'.allMatches(_textController.text).length + 1;
    
    return Container(
      width: 50,
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1E1E1E)
          : Colors.grey.shade50,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: lineCount,
        itemBuilder: (context, index) {
          return Container(
            height: _fontSize * 1.5,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: _fontSize - 2,
                color: Theme.of(context).hintColor,
                fontFamily: 'monospace',
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextArea(BuildContext context, OpenFile file) {
    return TextField(
      controller: _textController,
      focusNode: _focusNode,
      maxLines: null,
      expands: true,
      keyboardType: TextInputType.multiline,
      textAlignVertical: TextAlignVertical.top,
      style: TextStyle(
        fontSize: _fontSize,
        fontFamily: 'monospace',
        height: 1.5,
      ),
      decoration: const InputDecoration(
        border: InputBorder.none,
        contentPadding: EdgeInsets.all(12),
      ),
      onChanged: (value) {
        // Content update is handled by listener
        setState(() {}); // Update line numbers
      },
    );
  }

  Widget _buildStatusBar(BuildContext context, OpenFile? file) {
    if (file == null) {
      return Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        color: Theme.of(context).primaryColor,
        child: const Row(
          children: [
            Text(
              'Ready',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      );
    }

    final cursorPosition = _getCursorPosition();
    final lineCount = '\n'.allMatches(_textController.text).length + 1;
    final charCount = _textController.text.length;

    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: Theme.of(context).primaryColor,
      child: Row(
        children: [
          if (file.isSaving) ...[
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Saving...',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ] else if (file.isModified) ...[
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Modified',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ] else ...[
            const Icon(Icons.check, color: Colors.white, size: 14),
            const SizedBox(width: 4),
            const Text(
              'Saved',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
          const Spacer(),
          if (file.isRemote) ...[
            const Icon(Icons.cloud, color: Colors.white, size: 14),
            const SizedBox(width: 4),
            const Text(
              'Remote',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
            const SizedBox(width: 16),
          ],
          Text(
            'Ln ${cursorPosition.$1}, Col ${cursorPosition.$2}',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          const SizedBox(width: 16),
          Text(
            '$lineCount lines, $charCount chars',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          const SizedBox(width: 16),
          Text(
            'Font: ${_fontSize.toInt()}px',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  (int, int) _getCursorPosition() {
    final text = _textController.text;
    final selection = _textController.selection;
    
    if (!selection.isValid) return (1, 1);
    
    final beforeCursor = text.substring(0, selection.start);
    final lines = beforeCursor.split('\n');
    final line = lines.length;
    final column = lines.last.length + 1;
    
    return (line, column);
  }

  void _handleKeyEvent(KeyEvent event, BuildContext context) {
    if (event is! KeyDownEvent) return;
    
    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    
    if (isCtrl) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.keyS:
          context.read<EditorProvider>().saveActiveFile();
          break;
        case LogicalKeyboardKey.keyF:
          _toggleSearch();
          break;
        case LogicalKeyboardKey.keyA:
          _selectAll();
          break;
        case LogicalKeyboardKey.keyZ:
          if (isShift) {
            _redo();
          } else {
            _undo();
          }
          break;
        case LogicalKeyboardKey.keyY:
          _redo();
          break;
      }
    }
    
    if (event.logicalKey == LogicalKeyboardKey.escape && _showSearch) {
      _toggleSearch();
    }
  }

  void _handleBack(BuildContext context, EditorProvider provider) {
    if (provider.hasUnsavedChanges) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unsaved Changes'),
          content: const Text(
            'You have unsaved changes. Do you want to save before leaving?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Discard'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await provider.saveActiveFile();
                if (context.mounted) {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  void _closeFileTab(BuildContext context, EditorProvider provider, OpenFile file) {
    if (file.isModified) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unsaved Changes'),
          content: Text(
            'Do you want to save changes to ${file.displayName}?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                provider.closeFile(file.id);
              },
              child: const Text('Discard'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await provider.saveActiveFile();
                if (context.mounted) {
                  Navigator.of(context).pop();
                  provider.closeFile(file.id);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );
    } else {
      provider.closeFile(file.id);
    }
  }

  void _showSaveAsDialog(BuildContext context, EditorProvider provider, OpenFile file, bool isConnected) {
    showDialog(
      context: context,
      builder: (context) => _SaveAsDialog(
        currentPath: file.originalPath,
        isRemote: file.isRemote,
        isConnected: isConnected,
        onSave: (path, asRemote) {
          provider.saveActiveFileAs(path, asRemote: asRemote);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _undo() {
    // Platform native undo via TextField
  }

  void _redo() {
    // Platform native redo via TextField
  }

  void _cut() {
    final selection = _textController.selection;
    if (selection.isCollapsed) return;
    
    final text = _textController.text;
    final selectedText = text.substring(selection.start, selection.end);
    Clipboard.setData(ClipboardData(text: selectedText));
    
    _textController.text = text.substring(0, selection.start) +
        text.substring(selection.end);
    _textController.selection = TextSelection.collapsed(offset: selection.start);
  }

  void _copy() {
    final selection = _textController.selection;
    if (selection.isCollapsed) return;
    
    final text = _textController.text;
    final selectedText = text.substring(selection.start, selection.end);
    Clipboard.setData(ClipboardData(text: selectedText));
  }

  void _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null) return;
    
    final selection = _textController.selection;
    final text = _textController.text;
    
    _textController.text = text.substring(0, selection.start) +
        data!.text! +
        text.substring(selection.end);
    _textController.selection = TextSelection.collapsed(
      offset: selection.start + data.text!.length,
    );
  }

  void _selectAll() {
    _textController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _textController.text.length,
    );
  }

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (!_showSearch) {
        _searchController.clear();
        _searchMatches.clear();
        _currentMatchIndex = -1;
      }
    });
  }

  void _performSearch() {
    final query = _searchController.text;
    if (query.isEmpty) {
      setState(() {
        _searchMatches.clear();
        _currentMatchIndex = -1;
      });
      return;
    }
    
    final text = _textController.text.toLowerCase();
    final searchQuery = query.toLowerCase();
    final matches = <int>[];
    
    int index = 0;
    while (true) {
      index = text.indexOf(searchQuery, index);
      if (index == -1) break;
      matches.add(index);
      index += searchQuery.length;
    }
    
    setState(() {
      _searchMatches = matches;
      _currentMatchIndex = matches.isNotEmpty ? 0 : -1;
    });
    
    if (_searchMatches.isNotEmpty) {
      _highlightMatch();
    }
  }

  void _findNext() {
    if (_searchMatches.isEmpty) return;
    
    setState(() {
      _currentMatchIndex = (_currentMatchIndex + 1) % _searchMatches.length;
    });
    _highlightMatch();
  }

  void _findPrevious() {
    if (_searchMatches.isEmpty) return;
    
    setState(() {
      _currentMatchIndex = (_currentMatchIndex - 1 + _searchMatches.length) %
          _searchMatches.length;
    });
    _highlightMatch();
  }

  void _highlightMatch() {
    if (_currentMatchIndex < 0 || _currentMatchIndex >= _searchMatches.length) {
      return;
    }
    
    final start = _searchMatches[_currentMatchIndex];
    final end = start + _searchController.text.length;
    
    _textController.selection = TextSelection(
      baseOffset: start,
      extentOffset: end,
    );
    _focusNode.requestFocus();
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isActive;

  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20),
      onPressed: onPressed,
      tooltip: tooltip,
      splashRadius: 18,
      color: isActive ? Theme.of(context).primaryColor : null,
    );
  }
}

class _FileTab extends StatelessWidget {
  final OpenFile file;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _FileTab({
    required this.file,
    required this.isActive,
    required this.onTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).scaffoldBackgroundColor
              : Colors.transparent,
          border: Border(
            top: BorderSide(
              color: isActive
                  ? Theme.of(context).primaryColor
                  : Colors.transparent,
              width: 2,
            ),
            right: BorderSide(
              color: Theme.of(context).dividerColor,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (file.isRemote)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.cloud, size: 14),
              ),
            if (file.isModified)
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 4),
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
            Text(
              file.displayName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: onClose,
              borderRadius: BorderRadius.circular(10),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.close, size: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaveAsDialog extends StatefulWidget {
  final String currentPath;
  final bool isRemote;
  final bool isConnected;
  final void Function(String path, bool asRemote) onSave;

  const _SaveAsDialog({
    required this.currentPath,
    required this.isRemote,
    required this.isConnected,
    required this.onSave,
  });

  @override
  State<_SaveAsDialog> createState() => _SaveAsDialogState();
}

class _SaveAsDialogState extends State<_SaveAsDialog> {
  late TextEditingController _pathController;
  late bool _saveAsRemote;

  @override
  void initState() {
    super.initState();
    _pathController = TextEditingController(text: widget.currentPath);
    _saveAsRemote = widget.isRemote;
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Save As'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _pathController,
            decoration: const InputDecoration(
              labelText: 'File Path',
              hintText: 'Enter file path',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Save to: '),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Local'),
                selected: !_saveAsRemote,
                onSelected: (_) => setState(() => _saveAsRemote = false),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Remote'),
                selected: _saveAsRemote,
                onSelected: widget.isConnected
                    ? (_) => setState(() => _saveAsRemote = true)
                    : null,
              ),
            ],
          ),
          if (!widget.isConnected && _saveAsRemote)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Not connected to server',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          const SizedBox(height: 16),
          if (!_saveAsRemote)
            ElevatedButton.icon(
              onPressed: () async {
                final result = await FilePicker.platform.saveFile(
                  dialogTitle: 'Save As',
                  fileName: p.basename(_pathController.text),
                );
                if (result != null) {
                  _pathController.text = result;
                }
              },
              icon: const Icon(Icons.folder_open, size: 18),
              label: const Text('Browse...'),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _pathController.text.isNotEmpty
              ? () => widget.onSave(_pathController.text, _saveAsRemote)
              : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
