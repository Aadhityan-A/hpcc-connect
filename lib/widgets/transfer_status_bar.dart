import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/file_entry.dart';
import '../providers/file_browser_provider.dart';

class TransferStatusBar extends StatelessWidget {
  const TransferStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FileBrowserProvider>(
      builder: (context, provider, _) {
        final transfers = provider.transfers;
        
        if (transfers.isEmpty) {
          return const SizedBox.shrink();
        }

        final activeTransfers = transfers.where(
          (t) => t.status == TransferStatus.pending || t.status == TransferStatus.inProgress,
        ).toList();
        
        final completedCount = transfers.where(
          (t) => t.status == TransferStatus.completed,
        ).length;
        
        final failedCount = transfers.where(
          (t) => t.status == TransferStatus.failed,
        ).length;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF2D2D2D)
              : Colors.grey.shade200,
          child: Row(
            children: [
              const Icon(Icons.sync, size: 18),
              const SizedBox(width: 8),
              if (activeTransfers.isNotEmpty) ...[
                Expanded(
                  child: _buildActiveTransfer(activeTransfers.first),
                ),
              ] else ...[
                Text(
                  'Transfers: $completedCount completed',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (failedCount > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    ', $failedCount failed',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.red,
                    ),
                  ),
                ],
              ],
              const Spacer(),
              if (activeTransfers.length > 1)
                Text(
                  '+${activeTransfers.length - 1} more',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: provider.clearCompletedTransfers,
                child: const Text('Clear'),
              ),
              IconButton(
                icon: const Icon(Icons.list, size: 18),
                onPressed: () => _showTransferDetails(context, provider),
                tooltip: 'View all transfers',
                splashRadius: 18,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActiveTransfer(FileTransfer transfer) {
    final fileName = transfer.sourcePath.split('/').last;
    final isUpload = transfer.operation == TransferOperation.upload;
    
    return Row(
      children: [
        Icon(
          isUpload ? Icons.upload : Icons.download,
          size: 16,
          color: isUpload ? Colors.green : Colors.blue,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                fileName,
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              LinearProgressIndicator(
                value: transfer.progress,
                minHeight: 4,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          transfer.progressText,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  void _showTransferDetails(BuildContext context, FileBrowserProvider provider) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _TransferDetailsSheet(provider: provider),
    );
  }
}

class _TransferDetailsSheet extends StatelessWidget {
  final FileBrowserProvider provider;

  const _TransferDetailsSheet({required this.provider});

  @override
  Widget build(BuildContext context) {
    final transfers = provider.transfers;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'File Transfers',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  provider.clearCompletedTransfers();
                  Navigator.of(context).pop();
                },
                child: const Text('Clear Completed'),
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: transfers.isEmpty
                ? const Center(child: Text('No transfers'))
                : ListView.builder(
                    itemCount: transfers.length,
                    itemBuilder: (context, index) {
                      final transfer = transfers[index];
                      return _TransferListItem(transfer: transfer);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _TransferListItem extends StatelessWidget {
  final FileTransfer transfer;

  const _TransferListItem({required this.transfer});

  @override
  Widget build(BuildContext context) {
    final isUpload = transfer.operation == TransferOperation.upload;
    
    return ListTile(
      leading: Icon(
        isUpload ? Icons.upload : Icons.download,
        color: _getStatusColor(),
      ),
      title: Text(
        transfer.sourcePath.split('/').last,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${isUpload ? "To" : "From"}: ${transfer.destinationPath}',
            style: Theme.of(context).textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
          if (transfer.status == TransferStatus.inProgress)
            LinearProgressIndicator(value: transfer.progress),
          if (transfer.error != null)
            Text(
              transfer.error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
        ],
      ),
      trailing: _buildStatusIcon(),
    );
  }

  Color _getStatusColor() {
    switch (transfer.status) {
      case TransferStatus.pending:
        return Colors.grey;
      case TransferStatus.inProgress:
        return Colors.blue;
      case TransferStatus.completed:
        return Colors.green;
      case TransferStatus.failed:
        return Colors.red;
      case TransferStatus.cancelled:
        return Colors.orange;
    }
  }

  Widget _buildStatusIcon() {
    switch (transfer.status) {
      case TransferStatus.pending:
        return const Icon(Icons.hourglass_empty, color: Colors.grey);
      case TransferStatus.inProgress:
        return SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            value: transfer.progress,
            strokeWidth: 2,
          ),
        );
      case TransferStatus.completed:
        return const Icon(Icons.check_circle, color: Colors.green);
      case TransferStatus.failed:
        return const Icon(Icons.error, color: Colors.red);
      case TransferStatus.cancelled:
        return const Icon(Icons.cancel, color: Colors.orange);
    }
  }
}
