import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/file_entry.dart';
import '../providers/connection_provider.dart';
import '../providers/file_browser_provider.dart';
import 'file_list_view.dart';

class FileBrowserPanel extends StatefulWidget {
  const FileBrowserPanel({super.key});

  @override
  State<FileBrowserPanel> createState() => _FileBrowserPanelState();
}

class _FileBrowserPanelState extends State<FileBrowserPanel> {
  double _localPanelWidth = 0.5; // Percentage

  @override
  Widget build(BuildContext context) {
    return Consumer2<ConnectionProvider, FileBrowserProvider>(
      builder: (context, connectionProvider, fileBrowserProvider, _) {
        final isConnected = connectionProvider.isConnected;

        return Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (isConnected) {
                // Dual pane view when connected
                return Row(
                  children: [
                    // Local file browser
                    SizedBox(
                      width: constraints.maxWidth * _localPanelWidth - 2,
                      child: _LocalFileBrowser(
                        provider: fileBrowserProvider,
                        onFileDrop: (entries) {
                          _handleDropToRemote(entries, fileBrowserProvider);
                        },
                      ),
                    ),
                    // Resizable divider
                    MouseRegion(
                      cursor: SystemMouseCursors.resizeColumn,
                      child: GestureDetector(
                        onHorizontalDragUpdate: (details) {
                          setState(() {
                            _localPanelWidth = ((_localPanelWidth * constraints.maxWidth + details.delta.dx) / constraints.maxWidth)
                                .clamp(0.2, 0.8);
                          });
                        },
                        child: Container(
                          width: 4,
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                    ),
                    // Remote file browser
                    Expanded(
                      child: _RemoteFileBrowser(
                        provider: fileBrowserProvider,
                        onFileDrop: (entries) {
                          _handleDropToLocal(entries, fileBrowserProvider);
                        },
                      ),
                    ),
                  ],
                );
              } else {
                // Single pane (local only) when not connected
                return _LocalFileBrowser(
                  provider: fileBrowserProvider,
                  onFileDrop: null,
                );
              }
            },
          ),
        );
      },
    );
  }

  void _handleDropToRemote(List<FileEntry> entries, FileBrowserProvider provider) {
    final paths = entries.where((e) => e.isLocal && !e.isDirectory).map((e) => e.path).toList();
    if (paths.isNotEmpty) {
      provider.uploadFiles(paths);
    }
  }

  void _handleDropToLocal(List<FileEntry> entries, FileBrowserProvider provider) {
    final paths = entries.where((e) => !e.isLocal && !e.isDirectory).map((e) => e.path).toList();
    if (paths.isNotEmpty) {
      provider.downloadFiles(paths);
    }
  }
}

class _LocalFileBrowser extends StatelessWidget {
  final FileBrowserProvider provider;
  final void Function(List<FileEntry>)? onFileDrop;

  const _LocalFileBrowser({
    required this.provider,
    this.onFileDrop,
  });

  @override
  Widget build(BuildContext context) {
    return _FileBrowserPane(
      title: 'Local',
      icon: Icons.computer,
      path: provider.localPath,
      files: provider.localFiles,
      isLoading: provider.isLoadingLocal,
      error: provider.localError,
      selectedFiles: provider.selectedLocalFiles,
      isLocal: true,
      onNavigateUp: provider.navigateLocalUp,
      onNavigateInto: (entry) => provider.navigateLocalInto(entry),
      onRefresh: () => provider.loadLocalDirectory(provider.localPath),
      onPathChange: (path) => provider.loadLocalDirectory(path),
      onToggleSelection: (path) => provider.toggleLocalSelection(path),
      onSelectAll: provider.selectAllLocal,
      onClearSelection: provider.clearLocalSelection,
      onCreateFolder: (name) => provider.createLocalFolder(name),
      onDelete: (paths) => provider.deleteLocalFiles(paths),
      onRename: (path, name) => provider.renameLocal(path, name),
      onFileDrop: onFileDrop,
      onUpload: (paths) => provider.uploadFiles(paths),
    );
  }
}

class _RemoteFileBrowser extends StatelessWidget {
  final FileBrowserProvider provider;
  final void Function(List<FileEntry>)? onFileDrop;

  const _RemoteFileBrowser({
    required this.provider,
    this.onFileDrop,
  });

  @override
  Widget build(BuildContext context) {
    return _FileBrowserPane(
      title: 'Remote (HPCC)',
      icon: Icons.cloud,
      path: provider.remotePath,
      files: provider.remoteFiles,
      isLoading: provider.isLoadingRemote,
      error: provider.remoteError,
      selectedFiles: provider.selectedRemoteFiles,
      isLocal: false,
      onNavigateUp: provider.navigateRemoteUp,
      onNavigateInto: (entry) => provider.navigateRemoteInto(entry),
      onRefresh: () => provider.loadRemoteDirectory(provider.remotePath),
      onPathChange: (path) => provider.loadRemoteDirectory(path),
      onToggleSelection: (path) => provider.toggleRemoteSelection(path),
      onSelectAll: provider.selectAllRemote,
      onClearSelection: provider.clearRemoteSelection,
      onCreateFolder: (name) => provider.createRemoteFolder(name),
      onDelete: (paths) => provider.deleteRemoteFiles(paths),
      onRename: (path, name) => provider.renameRemote(path, name),
      onFileDrop: onFileDrop,
      onDownload: (paths) => provider.downloadFiles(paths),
    );
  }
}

class _FileBrowserPane extends StatefulWidget {
  final String title;
  final IconData icon;
  final String path;
  final List<FileEntry> files;
  final bool isLoading;
  final String? error;
  final Set<String> selectedFiles;
  final bool isLocal;
  final VoidCallback onNavigateUp;
  final void Function(FileEntry) onNavigateInto;
  final VoidCallback onRefresh;
  final void Function(String) onPathChange;
  final void Function(String) onToggleSelection;
  final VoidCallback onSelectAll;
  final VoidCallback onClearSelection;
  final Future<void> Function(String) onCreateFolder;
  final Future<void> Function(List<String>) onDelete;
  final Future<void> Function(String, String) onRename;
  final void Function(List<FileEntry>)? onFileDrop;
  final void Function(List<String>)? onUpload;
  final void Function(List<String>)? onDownload;

  const _FileBrowserPane({
    required this.title,
    required this.icon,
    required this.path,
    required this.files,
    required this.isLoading,
    this.error,
    required this.selectedFiles,
    required this.isLocal,
    required this.onNavigateUp,
    required this.onNavigateInto,
    required this.onRefresh,
    required this.onPathChange,
    required this.onToggleSelection,
    required this.onSelectAll,
    required this.onClearSelection,
    required this.onCreateFolder,
    required this.onDelete,
    required this.onRename,
    this.onFileDrop,
    this.onUpload,
    this.onDownload,
  });

  @override
  State<_FileBrowserPane> createState() => _FileBrowserPaneState();
}

class _FileBrowserPaneState extends State<_FileBrowserPane> {
  final TextEditingController _pathController = TextEditingController();
  bool _isDragOver = false;

  @override
  void initState() {
    super.initState();
    _pathController.text = widget.path;
  }

  @override
  void didUpdateWidget(covariant _FileBrowserPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _pathController.text = widget.path;
    }
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<List<FileEntry>>(
      onWillAcceptWithDetails: (details) {
        final entries = details.data;
        // Accept if dragging from opposite panel
        final isFromOpposite = entries.isNotEmpty && entries.first.isLocal != widget.isLocal;
        if (isFromOpposite) {
          setState(() => _isDragOver = true);
        }
        return isFromOpposite;
      },
      onLeave: (_) => setState(() => _isDragOver = false),
      onAcceptWithDetails: (details) {
        setState(() => _isDragOver = false);
        widget.onFileDrop?.call(details.data);
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: _isDragOver
                ? Border.all(color: Theme.of(context).primaryColor, width: 2)
                : null,
          ),
          child: Column(
            children: [
              _buildHeader(),
              _buildToolbar(),
              _buildPathBar(),
              const Divider(height: 1),
              Expanded(
                child: _buildFileList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF2D2D2D)
          : Colors.grey.shade200,
      child: Row(
        children: [
          Icon(widget.icon, size: 18),
          const SizedBox(width: 8),
          Text(
            widget.title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          if (widget.isLoading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_upward, size: 18),
            onPressed: widget.onNavigateUp,
            tooltip: 'Go up',
            splashRadius: 18,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            onPressed: widget.onRefresh,
            tooltip: 'Refresh',
            splashRadius: 18,
          ),
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined, size: 18),
            onPressed: () => _showCreateFolderDialog(),
            tooltip: 'New folder',
            splashRadius: 18,
          ),
          const Spacer(),
          if (widget.selectedFiles.isNotEmpty) ...[
            Text(
              '${widget.selectedFiles.length} selected',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(width: 8),
            if (widget.isLocal && widget.onUpload != null)
              IconButton(
                icon: const Icon(Icons.upload, size: 18),
                onPressed: () => widget.onUpload!(widget.selectedFiles.toList()),
                tooltip: 'Upload to remote',
                splashRadius: 18,
              ),
            if (!widget.isLocal && widget.onDownload != null)
              IconButton(
                icon: const Icon(Icons.download, size: 18),
                onPressed: () => widget.onDownload!(widget.selectedFiles.toList()),
                tooltip: 'Download to local',
                splashRadius: 18,
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
              onPressed: () => _showDeleteConfirmation(),
              tooltip: 'Delete selected',
              splashRadius: 18,
            ),
            IconButton(
              icon: const Icon(Icons.clear, size: 18),
              onPressed: widget.onClearSelection,
              tooltip: 'Clear selection',
              splashRadius: 18,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPathBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.folder_outlined, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _pathController,
              style: Theme.of(context).textTheme.bodySmall,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 4),
              ),
              onSubmitted: widget.onPathChange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileList() {
    if (widget.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              widget.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: widget.onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (widget.files.isEmpty && !widget.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 48,
              color: Theme.of(context).hintColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Empty folder',
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
          ],
        ),
      );
    }

    return FileListView(
      files: widget.files,
      selectedFiles: widget.selectedFiles,
      isLocal: widget.isLocal,
      onDoubleTap: (entry) {
        if (entry.isDirectory) {
          widget.onNavigateInto(entry);
        }
      },
      onToggleSelection: widget.onToggleSelection,
      onRename: widget.onRename,
    );
  }

  void _showCreateFolderDialog() {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Folder name',
            hintText: 'Enter folder name',
          ),
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              widget.onCreateFolder(value);
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                widget.onCreateFolder(controller.text);
                Navigator.of(context).pop();
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Files'),
        content: Text(
          'Are you sure you want to delete ${widget.selectedFiles.length} item(s)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              widget.onDelete(widget.selectedFiles.toList());
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
