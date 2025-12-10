import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/connection_provider.dart';
import '../providers/file_browser_provider.dart';
import '../providers/terminal_provider.dart';
import '../widgets/connection_sidebar.dart';
import '../widgets/file_browser_panel.dart';
import '../widgets/terminal_panel.dart';
import '../widgets/transfer_status_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double _sidebarWidth = 250;
  double _terminalHeightRatio = 0.5; // Percentage of right panel reserved for terminal

  @override
  void initState() {
    super.initState();
    _setupProviders();
  }

  void _setupProviders() {
    final connectionProvider = context.read<ConnectionProvider>();
    final fileBrowserProvider = context.read<FileBrowserProvider>();
    final terminalProvider = context.read<TerminalProvider>();

    // Link SSH service to other providers
    fileBrowserProvider.setSshService(connectionProvider.sshService);
    terminalProvider.setSshService(connectionProvider.sshService);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildAppBar(),
          Expanded(
            child: Row(
              children: [
                // Left sidebar - Connection list
                SizedBox(
                  width: _sidebarWidth,
                  child: const ConnectionSidebar(),
                ),
                // Resizable divider
                MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        _sidebarWidth = (_sidebarWidth + details.delta.dx)
                            .clamp(200, 400);
                      });
                    },
                    child: Container(
                      width: 4,
                      color: Theme.of(context).dividerColor,
                    ),
                  ),
                ),
                // Right panel - File browser and Terminal
                Expanded(
                  child: _buildRightPanel(),
                ),
              ],
            ),
          ),
          // Transfer status bar
          const TransferStatusBar(),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      height: 48,
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(
            Icons.terminal,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 8),
          Text(
            'HPCC Connect',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Consumer<ConnectionProvider>(
            builder: (context, provider, _) {
              if (provider.isConnected) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Connected to ${provider.activeConnection?.name ?? "Unknown"}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(width: 16),
                    TextButton.icon(
                      onPressed: () async {
                        final terminalProvider = context.read<TerminalProvider>();
                        final fileBrowserProvider = context.read<FileBrowserProvider>();
                        await provider.disconnect();
                        if (mounted) {
                          terminalProvider.disposeTerminal();
                          fileBrowserProvider.clearRemoteState();
                        }
                      },
                      icon: const Icon(Icons.power_off, size: 16),
                      label: const Text('Disconnect'),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                    ),
                  ],
                );
              }
              return const SizedBox();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRightPanel() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final terminalPixelHeight = constraints.maxHeight * _terminalHeightRatio;
        final fileBrowserPixelHeight = constraints.maxHeight - terminalPixelHeight;

        return Column(
          children: [
            // Terminal (top)
            SizedBox(
              height: (terminalPixelHeight - 2).clamp(0.0, double.infinity),
              child: const TerminalPanel(),
            ),
            // Resizable divider
            MouseRegion(
              cursor: SystemMouseCursors.resizeRow,
              child: GestureDetector(
                onVerticalDragUpdate: (details) {
                  setState(() {
                    final currentHeightPx = _terminalHeightRatio * constraints.maxHeight;
                    final newHeightPx = (currentHeightPx + details.delta.dy)
                        .clamp(constraints.maxHeight * 0.2, constraints.maxHeight * 0.8);
                    _terminalHeightRatio = newHeightPx / constraints.maxHeight;
                  });
                },
                child: Container(
                  height: 4,
                  color: Theme.of(context).dividerColor,
                ),
              ),
            ),
            // File browser (bottom)
            SizedBox(
              height: (fileBrowserPixelHeight - 2).clamp(0.0, double.infinity),
              child: const FileBrowserPanel(),
            ),
          ],
        );
      },
    );
  }
}
