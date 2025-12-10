import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ssh_connection.dart';
import '../providers/connection_provider.dart';
import '../providers/file_browser_provider.dart';
import '../providers/terminal_provider.dart';
import 'connection_dialog.dart';

class ConnectionSidebar extends StatelessWidget {
  const ConnectionSidebar({super.key});

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
            child: _buildConnectionList(context),
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
