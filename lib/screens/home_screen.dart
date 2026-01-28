import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/connection_provider.dart';
import '../providers/file_browser_provider.dart';
import '../providers/terminal_provider.dart';
import '../providers/editor_provider.dart';
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
  bool _sidebarCollapsed = false;
  
  // Responsive breakpoints
  static const double _narrowScreenThreshold = 600; // Below this, use mobile layout
  static const double _minSidebarWidth = 200;
  static const double _maxSidebarWidth = 400;
  static const double _collapsedSidebarWidth = 56;


  @override
  void initState() {
    super.initState();
    _setupProviders();
  }

  void _setupProviders() {
    final connectionProvider = context.read<ConnectionProvider>();
    final fileBrowserProvider = context.read<FileBrowserProvider>();
    final terminalProvider = context.read<TerminalProvider>();
    final editorProvider = context.read<EditorProvider>();

    // Link SSH service to other providers
    fileBrowserProvider.setSshService(connectionProvider.sshService);
    terminalProvider.setSshService(connectionProvider.sshService);
    editorProvider.setSshService(connectionProvider.sshService);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrowScreen = screenWidth < _narrowScreenThreshold;
    
    // Auto-collapse sidebar on narrow screens
    if (isNarrowScreen && !_sidebarCollapsed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _sidebarCollapsed = true);
      });
    }
    
    return Scaffold(
      body: Column(
        children: [
          _buildAppBar(isNarrowScreen),
          Expanded(
            child: isNarrowScreen 
                ? _buildNarrowLayout() 
                : _buildWideLayout(),
          ),
          // Transfer status bar
          const TransferStatusBar(),
        ],
      ),
      // Drawer for narrow screens
      drawer: isNarrowScreen ? _buildDrawerSidebar() : null,
    );
  }
  
  Widget _buildNarrowLayout() {
    return Column(
      children: [
        // Collapsible sidebar icons row
        if (_sidebarCollapsed) _buildCollapsedSidebar(),
        // Main content area - stacked vertically
        Expanded(
          child: _buildRightPanel(),
        ),
      ],
    );
  }
  
  Widget _buildCollapsedSidebar() {
    return Container(
      height: _collapsedSidebarWidth,
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF252526)
          : Colors.grey.shade100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.dns_outlined),
            tooltip: 'Connections',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
          IconButton(
            icon: const Icon(Icons.code),
            tooltip: 'Snippets',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
          Consumer<ConnectionProvider>(
            builder: (context, provider, _) {
              return IconButton(
                icon: Icon(
                  provider.isConnected ? Icons.cloud_done : Icons.cloud_off,
                  color: provider.isConnected ? Colors.green : null,
                ),
                tooltip: provider.isConnected 
                    ? 'Connected to ${provider.activeConnection?.name ?? "Unknown"}'
                    : 'Not connected',
                onPressed: () => Scaffold.of(context).openDrawer(),
              );
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildDrawerSidebar() {
    return Drawer(
      child: SafeArea(
        child: const ConnectionSidebar(),
      ),
    );
  }
  
  Widget _buildWideLayout() {
    return Row(
      children: [
        // Left sidebar - Connection list
        SizedBox(
          width: _sidebarCollapsed ? _collapsedSidebarWidth : _sidebarWidth,
          child: _sidebarCollapsed 
              ? _buildCollapsedSidebarVertical()
              : const ConnectionSidebar(),
        ),
        // Resizable divider (only when not collapsed)
        if (!_sidebarCollapsed)
          MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _sidebarWidth = (_sidebarWidth + details.delta.dx)
                      .clamp(_minSidebarWidth, _maxSidebarWidth);
                });
              },
              child: Container(
                width: 4,
                color: Theme.of(context).dividerColor,
              ),
            ),
          ),
        // Collapse/expand toggle
        Container(
          width: 4,
          color: Theme.of(context).dividerColor,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onDoubleTap: () {
                setState(() => _sidebarCollapsed = !_sidebarCollapsed);
              },
            ),
          ),
        ),
        // Right panel - File browser and Terminal
        Expanded(
          child: _buildRightPanel(),
        ),
      ],
    );
  }
  
  Widget _buildCollapsedSidebarVertical() {
    return Container(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF252526)
          : Colors.grey.shade100,
      child: Column(
        children: [
          const SizedBox(height: 8),
          IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Expand sidebar',
            onPressed: () => setState(() => _sidebarCollapsed = false),
          ),
          const Divider(),
          IconButton(
            icon: const Icon(Icons.dns_outlined),
            tooltip: 'Connections',
            onPressed: () => setState(() => _sidebarCollapsed = false),
          ),
          IconButton(
            icon: const Icon(Icons.code),
            tooltip: 'Snippets',
            onPressed: () => setState(() => _sidebarCollapsed = false),
          ),
          const Spacer(),
          Consumer<ConnectionProvider>(
            builder: (context, provider, _) {
              return IconButton(
                icon: Icon(
                  provider.isConnected ? Icons.cloud_done : Icons.cloud_off,
                  color: provider.isConnected ? Colors.green : null,
                ),
                tooltip: provider.isConnected 
                    ? 'Connected'
                    : 'Not connected',
                onPressed: () => setState(() => _sidebarCollapsed = false),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildAppBar(bool isNarrowScreen) {
    return Container(
      height: 48,
      color: Theme.of(context).colorScheme.surface,
      padding: EdgeInsets.symmetric(horizontal: isNarrowScreen ? 8 : 16),
      child: Row(
        children: [
          // Menu button for narrow screens
          if (isNarrowScreen)
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
                tooltip: 'Open menu',
              ),
            ),
          Icon(
            Icons.terminal,
            color: Theme.of(context).primaryColor,
          ),
          if (!isNarrowScreen) const SizedBox(width: 8),
          if (!isNarrowScreen)
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
                if (isNarrowScreen) {
                  // Compact connection status for narrow screens
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
                      IconButton(
                        onPressed: () async {
                          final terminalProvider = context.read<TerminalProvider>();
                          final fileBrowserProvider = context.read<FileBrowserProvider>();
                          await provider.disconnect();
                          if (mounted) {
                            terminalProvider.disposeTerminal();
                            fileBrowserProvider.clearRemoteState();
                          }
                        },
                        icon: const Icon(Icons.power_off, size: 18, color: Colors.red),
                        tooltip: 'Disconnect',
                      ),
                    ],
                  );
                }
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
