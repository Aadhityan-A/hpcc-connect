import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ssh_connection.dart';
import '../models/command_snippet.dart';
import '../providers/connection_provider.dart';
import '../providers/file_browser_provider.dart';
import '../providers/terminal_provider.dart';
import '../providers/snippet_provider.dart';
import '../providers/local_terminal_provider.dart';
import '../providers/terminal_mode_provider.dart';
import 'connection_dialog.dart';
import 'snippet_dialog.dart';

class ConnectionSidebar extends StatefulWidget {
  const ConnectionSidebar({super.key});

  @override
  State<ConnectionSidebar> createState() => _ConnectionSidebarState();
}

class _ConnectionSidebarState extends State<ConnectionSidebar> {
  bool _snippetsExpanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF252526)
          : Colors.grey.shade100,
      child: Column(
        children: [
          _buildHeader(context),
          const Divider(height: 1),
          Expanded(
            flex: 2,
            child: _buildConnectionList(context),
          ),
          const Divider(height: 1),
          _buildSnippetsSection(context),
        ],
      ),
    );
  }

  Widget _buildSnippetsSection(BuildContext context) {
    return Consumer<SnippetProvider>(
      builder: (context, provider, _) {
        final snippets = provider.snippets;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Snippets header
            InkWell(
              onTap: () {
                setState(() {
                  _snippetsExpanded = !_snippetsExpanded;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      _snippetsExpanded
                          ? Icons.expand_more
                          : Icons.chevron_right,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.code, size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'Snippets',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.add, size: 20),
                      onPressed: () => _showAddSnippetDialog(context),
                      tooltip: 'Add Snippet',
                      splashRadius: 20,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Snippets list
            if (_snippetsExpanded)
              snippets.isEmpty
                  ? _buildEmptySnippets(context)
                  : Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.only(bottom: 8),
                        itemCount: snippets.length,
                        itemBuilder: (context, index) {
                          final snippet = snippets[index];
                          return _SnippetTile(
                            snippet: snippet,
                            onTap: () => _executeSnippet(context, snippet),
                            onEdit: () =>
                                _showEditSnippetDialog(context, snippet),
                            onDelete: () =>
                                _showDeleteSnippetConfirmation(context, snippet),
                          );
                        },
                      ),
                    ),
          ],
        );
      },
    );
  }

  Widget _buildEmptySnippets(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Column(
        children: [
          Icon(
            Icons.code_off,
            size: 32,
            color: Theme.of(context).hintColor,
          ),
          const SizedBox(height: 8),
          Text(
            'No snippets',
            style: TextStyle(
              color: Theme.of(context).hintColor,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () => _showAddSnippetDialog(context),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Snippet', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          ),
        ],
      ),
    );
  }

  void _executeSnippet(BuildContext context, CommandSnippet snippet) {
    final terminalModeProvider = context.read<TerminalModeProvider>();
    final command = snippet.command;

    if (terminalModeProvider.isLocalTerminalActive) {
      // Send to local terminal
      final localProvider = context.read<LocalTerminalProvider>();
      if (localProvider.isInitialized) {
        localProvider.writeToTerminal('$command\r');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Executed: ${snippet.name}'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            width: 200,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Local terminal not initialized'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } else {
      // Send to SSH terminal
      final terminalProvider = context.read<TerminalProvider>();
      if (terminalProvider.isInitialized) {
        terminalProvider.writeToShell('$command\r');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Executed: ${snippet.name}'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            width: 200,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SSH terminal not connected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _showAddSnippetDialog(BuildContext context) {
    final provider = context.read<SnippetProvider>();
    final newSnippet = provider.createNewSnippet();

    showDialog(
      context: context,
      builder: (context) => SnippetDialog(
        snippet: newSnippet,
        isNew: true,
      ),
    );
  }

  void _showEditSnippetDialog(BuildContext context, CommandSnippet snippet) {
    showDialog(
      context: context,
      builder: (context) => SnippetDialog(
        snippet: snippet,
        isNew: false,
      ),
    );
  }

  void _showDeleteSnippetConfirmation(
      BuildContext context, CommandSnippet snippet) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Snippet'),
        content: Text('Are you sure you want to delete "${snippet.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<SnippetProvider>().deleteSnippet(snippet.id);
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

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.dns_outlined, size: 20),
          const SizedBox(width: 8),
          const Text(
            'Connections',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.add, size: 20),
            onPressed: () => _showAddConnectionDialog(context),
            tooltip: 'Add Connection',
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionList(BuildContext context) {
    return Consumer<ConnectionProvider>(
      builder: (context, provider, _) {
        final connections = provider.connections;

        if (connections.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  size: 48,
                  color: Theme.of(context).hintColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'No connections',
                  style: TextStyle(
                    color: Theme.of(context).hintColor,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _showAddConnectionDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Connection'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: connections.length,
          itemBuilder: (context, index) {
            final connection = connections[index];
            final isSelected = provider.selectedConnection?.id == connection.id;
            final isActive = provider.activeConnection?.id == connection.id;

            return _ConnectionTile(
              connection: connection,
              isSelected: isSelected,
              isActive: isActive,
              isConnecting: provider.isConnecting && isSelected,
              onTap: () {
                provider.selectConnection(connection);
              },
              onDoubleTap: () async {
                provider.selectConnection(connection);
                await _connectToServer(context, provider);
              },
              onEdit: () => _showEditConnectionDialog(context, connection),
              onDelete: () => _showDeleteConfirmation(context, connection),
            );
          },
        );
      },
    );
  }

  Future<void> _connectToServer(
    BuildContext context,
    ConnectionProvider provider,
  ) async {
    await provider.connect();
    
    if (provider.isConnected && context.mounted) {
      // Initialize file browser and terminal
      final fileBrowserProvider = context.read<FileBrowserProvider>();
      final terminalProvider = context.read<TerminalProvider>();
      
      await fileBrowserProvider.initRemoteBrowser();
      
      // Initialize terminal with default size (will be resized)
      await terminalProvider.initializeTerminal(
        width: 80,
        height: 24,
      );
    } else if (provider.connectionError != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection failed: ${provider.connectionError}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAddConnectionDialog(BuildContext context) {
    final provider = context.read<ConnectionProvider>();
    final newConnection = provider.createNewConnection();
    
    showDialog(
      context: context,
      builder: (context) => ConnectionDialog(
        connection: newConnection,
        isNew: true,
      ),
    );
  }

  void _showEditConnectionDialog(BuildContext context, SSHConnection connection) {
    showDialog(
      context: context,
      builder: (context) => ConnectionDialog(
        connection: connection,
        isNew: false,
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, SSHConnection connection) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Connection'),
        content: Text('Are you sure you want to delete "${connection.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<ConnectionProvider>().deleteConnection(connection.id);
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

class _ConnectionTile extends StatelessWidget {
  final SSHConnection connection;
  final bool isSelected;
  final bool isActive;
  final bool isConnecting;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ConnectionTile({
    required this.connection,
    required this.isSelected,
    required this.isActive,
    required this.isConnecting,
    required this.onTap,
    required this.onDoubleTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: isSelected
          ? Theme.of(context).primaryColor.withAlpha(51)
          : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: onTap,
          onDoubleTap: onDoubleTap,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _buildStatusIndicator(),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        connection.name,
                        style: TextStyle(
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${connection.username}@${connection.host}:${connection.port}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).hintColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18),
                  splashRadius: 18,
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        onEdit();
                        break;
                      case 'delete':
                        onDelete();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('Edit'),
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
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    if (isConnecting) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? Colors.green : Colors.grey,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Tile widget for displaying a command snippet
class _SnippetTile extends StatelessWidget {
  final CommandSnippet snippet;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SnippetTile({
    required this.snippet,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.play_arrow,
                  size: 16,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        snippet.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        snippet.command,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).hintColor,
                              fontFamily: 'monospace',
                              fontSize: 11,
                            ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 16),
                  splashRadius: 14,
                  padding: EdgeInsets.zero,
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        onEdit();
                        break;
                      case 'delete':
                        onDelete();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 16),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 16, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
