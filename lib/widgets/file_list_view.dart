import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/file_entry.dart';

/// Set of text file extensions that can be opened in the editor
const Set<String> textFileExtensions = {
  'txt', 'md', 'log', 'in', 'out', 'csv', 'tsv',
  'py', 'pyw', 'pyi',
  'js', 'jsx', 'ts', 'tsx', 'mjs', 'cjs',
  'html', 'htm', 'xhtml',
  'css', 'scss', 'sass', 'less',
  'json', 'xml', 'yaml', 'yml', 'toml',
  'sh', 'bash', 'zsh', 'fish', 'bat', 'cmd', 'ps1',
  'c', 'cpp', 'cc', 'cxx', 'h', 'hpp', 'hxx',
  'java', 'kt', 'kts', 'scala', 'groovy',
  'rs', 'go', 'swift', 'dart',
  'rb', 'rake', 'gemspec',
  'php', 'phtml',
  'sql', 'sqlite',
  'r', 'R', 'rmd',
  'lua', 'vim', 'el', 'lisp', 'clj', 'cljs',
  'asm', 's', 'S',
  'tex', 'bib', 'cls', 'sty',
  'ini', 'cfg', 'conf', 'config', 'properties',
  'env', 'gitignore', 'dockerignore', 'editorconfig',
  'makefile', 'cmake', 'gradle',
  'dockerfile',
};

/// Check if a file extension is a text file that can be opened in editor
bool isTextFile(String extension) {
  return textFileExtensions.contains(extension.toLowerCase());
}

class FileListView extends StatelessWidget {
  final List<FileEntry> files;
  final Set<String> selectedFiles;
  final bool isLocal;
  final void Function(FileEntry) onDoubleTap;
  final void Function(String) onToggleSelection;
  final Future<void> Function(String, String) onRename;
  final void Function(FileEntry)? onOpenFile;
  final void Function(List<String>)? onDelete;

  const FileListView({
    super.key,
    required this.files,
    required this.selectedFiles,
    required this.isLocal,
    required this.onDoubleTap,
    required this.onToggleSelection,
    required this.onRename,
    this.onOpenFile,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(context),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index];
              final isSelected = selectedFiles.contains(file.path);
              
              return _FileListItem(
                entry: file,
                isSelected: isSelected,
                onTap: () => onToggleSelection(file.path),
                onDoubleTap: () {
                  if (file.isDirectory) {
                    onDoubleTap(file);
                  } else if (isTextFile(file.extension)) {
                    onOpenFile?.call(file);
                  }
                },
                onRename: (newName) => onRename(file.path, newName),
                onOpenFile: onOpenFile != null && !file.isDirectory && isTextFile(file.extension)
                    ? () => onOpenFile!(file)
                    : null,
                onDelete: onDelete != null
                    ? () => onDelete!([file.path])
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.bold,
      color: Theme.of(context).hintColor,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF252526)
          : Colors.grey.shade100,
      child: Row(
        children: [
          const SizedBox(width: 24), // Checkbox space
          const SizedBox(width: 8),
          const SizedBox(width: 24), // Icon space
          const SizedBox(width: 8),
          Expanded(flex: 4, child: Text('Name', style: textStyle)),
          Expanded(flex: 1, child: Text('Size', style: textStyle, textAlign: TextAlign.right)),
          const SizedBox(width: 16),
          Expanded(flex: 2, child: Text('Modified', style: textStyle)),
        ],
      ),
    );
  }
}

class _FileListItem extends StatefulWidget {
  final FileEntry entry;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final Future<void> Function(String) onRename;
  final VoidCallback? onOpenFile;
  final VoidCallback? onDelete;

  const _FileListItem({
    required this.entry,
    required this.isSelected,
    required this.onTap,
    required this.onDoubleTap,
    required this.onRename,
    this.onOpenFile,
    this.onDelete,
  });

  @override
  State<_FileListItem> createState() => _FileListItemState();
}

class _FileListItemState extends State<_FileListItem> {
  bool _isRenaming = false;
  late TextEditingController _renameController;

  @override
  void initState() {
    super.initState();
    _renameController = TextEditingController(text: widget.entry.name);
  }

  @override
  void dispose() {
    _renameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LongPressDraggable<List<FileEntry>>(
      data: [widget.entry],
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getFileIcon(),
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                widget.entry.name,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.5,
        child: _buildContent(context),
      ),
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy HH:mm');
    final textStyle = Theme.of(context).textTheme.bodySmall;

    return Material(
        color: widget.isSelected
          ? Theme.of(context).primaryColor.withAlpha(26)
          : Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        onSecondaryTap: () => _showContextMenu(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Checkbox(
                value: widget.isSelected,
                onChanged: (_) => widget.onTap(),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 8),
              Icon(
                _getFileIcon(),
                size: 20,
                color: _getIconColor(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: _isRenaming
                    ? TextField(
                        controller: _renameController,
                        autofocus: true,
                        style: textStyle,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                        onSubmitted: _submitRename,
                        onEditingComplete: () {
                          setState(() => _isRenaming = false);
                        },
                      )
                    : Text(
                        widget.entry.name,
                        style: textStyle,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  widget.entry.displaySize,
                  style: textStyle,
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Text(
                  widget.entry.modifiedTime != null
                      ? dateFormat.format(widget.entry.modifiedTime!)
                      : '--',
                  style: textStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getFileIcon() {
    if (widget.entry.isDirectory) {
      return Icons.folder;
    }

    switch (widget.entry.extension) {
      case 'txt':
      case 'md':
      case 'log':
        return Icons.description;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'svg':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'mkv':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
      case 'flac':
      case 'aac':
        return Icons.audio_file;
      case 'zip':
      case 'tar':
      case 'gz':
      case 'rar':
      case '7z':
        return Icons.archive;
      case 'py':
        return Icons.code;
      case 'js':
      case 'ts':
      case 'jsx':
      case 'tsx':
        return Icons.javascript;
      case 'html':
      case 'htm':
        return Icons.html;
      case 'css':
      case 'scss':
      case 'sass':
        return Icons.css;
      case 'json':
      case 'xml':
      case 'yaml':
      case 'yml':
        return Icons.data_object;
      case 'sh':
      case 'bash':
      case 'zsh':
        return Icons.terminal;
      case 'exe':
      case 'app':
      case 'dmg':
        return Icons.apps;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getIconColor(BuildContext context) {
    if (widget.entry.isDirectory) {
      return Colors.amber;
    }

    switch (widget.entry.extension) {
      case 'py':
        return Colors.blue;
      case 'js':
      case 'ts':
      case 'jsx':
      case 'tsx':
        return Colors.yellow.shade700;
      case 'html':
        return Colors.orange;
      case 'css':
      case 'scss':
      case 'sass':
        return Colors.blue.shade300;
      case 'json':
        return Colors.green;
      case 'pdf':
        return Colors.red;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Colors.purple;
      default:
        return Theme.of(context).hintColor;
    }
  }

  void _showContextMenu(BuildContext context) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RenderBox itemBox = context.findRenderObject() as RenderBox;
    final Offset position = itemBox.localToGlobal(Offset.zero, ancestor: overlay);

    final items = <PopupMenuEntry<String>>[
      // Show "Open" option for text files
      if (widget.onOpenFile != null)
        const PopupMenuItem(
          value: 'open',
          child: Row(
            children: [
              Icon(Icons.edit_document, size: 18),
              SizedBox(width: 8),
              Text('Open in Editor'),
            ],
          ),
        ),
      const PopupMenuItem(
        value: 'rename',
        child: Row(
          children: [
            Icon(Icons.edit, size: 18),
            SizedBox(width: 8),
            Text('Rename'),
          ],
        ),
      ),
      const PopupMenuItem(
        value: 'delete',
        child: Row(
          children: [
            Icon(Icons.delete, size: 18, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete', style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
    ];

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx + 100,
        position.dy,
        position.dx + 200,
        position.dy + 50,
      ),
      items: items,
    ).then((value) {
      switch (value) {
        case 'open':
          widget.onOpenFile?.call();
          break;
        case 'rename':
          setState(() => _isRenaming = true);
          break;
        case 'delete':
          widget.onDelete?.call();
          break;
      }
    });
  }

  void _submitRename(String newName) {
    if (newName.isNotEmpty && newName != widget.entry.name) {
      widget.onRename(newName);
    }
    setState(() => _isRenaming = false);
  }
}
