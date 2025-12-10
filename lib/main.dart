import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'models/ssh_connection.dart';
import 'providers/connection_provider.dart';
import 'providers/file_browser_provider.dart';
import 'providers/terminal_provider.dart';
import 'providers/local_terminal_provider.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

// Current database version for migrations
const int kDatabaseVersion = 1;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive with error handling
  await _initializeHive();
  
  runApp(const HPCCConnectApp());
}

/// Initialize Hive with robust error handling
Future<void> _initializeHive() async {
  try {
    await Hive.initFlutter();
    
    // Register adapters before opening boxes
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(SSHConnectionAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(AuthTypeAdapter());
    }
    
    // Try to open the connections box
    await _openConnectionsBox();
    
  } catch (e) {
    debugPrint('Hive initialization error: $e');
    // If there's any error, try to recover by clearing corrupted data
    await _recoverFromCorruptedData();
  }
}

/// Open the connections box with error recovery
Future<void> _openConnectionsBox() async {
  try {
    await Hive.openBox<SSHConnection>('connections');
  } catch (e) {
    debugPrint('Error opening connections box: $e');
    // Delete corrupted box and create fresh one
    await _deleteAndRecreateBox('connections');
  }
}

/// Delete corrupted Hive data and start fresh
Future<void> _recoverFromCorruptedData() async {
  try {
    // Close all boxes
    await Hive.close();
    
    // Get the Hive directory
    final appDir = await getApplicationDocumentsDirectory();
    final hiveDir = Directory(appDir.path);
    
    // Delete all .hive and .lock files
    if (await hiveDir.exists()) {
      await for (final entity in hiveDir.list()) {
        if (entity is File) {
          final name = entity.path.split('/').last;
          if (name.endsWith('.hive') || name.endsWith('.lock')) {
            try {
              await entity.delete();
              debugPrint('Deleted corrupted file: ${entity.path}');
            } catch (e) {
              debugPrint('Could not delete ${entity.path}: $e');
            }
          }
        }
      }
    }
    
    // Reinitialize Hive
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(SSHConnectionAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(AuthTypeAdapter());
    }
    await Hive.openBox<SSHConnection>('connections');
    
    debugPrint('Successfully recovered from corrupted data');
  } catch (e) {
    debugPrint('Recovery failed: $e');
    // Last resort: just try to open an empty box
    try {
      await Hive.openBox<SSHConnection>('connections');
    } catch (_) {
      // If even this fails, the app will show an error but won't crash
    }
  }
}

/// Delete a specific box and recreate it
Future<void> _deleteAndRecreateBox(String boxName) async {
  try {
    await Hive.deleteBoxFromDisk(boxName);
  } catch (e) {
    debugPrint('Could not delete box $boxName: $e');
  }
  
  try {
    await Hive.openBox<SSHConnection>(boxName);
  } catch (e) {
    debugPrint('Could not recreate box $boxName: $e');
  }
}

class HPCCConnectApp extends StatelessWidget {
  const HPCCConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectionProvider()),
        ChangeNotifierProvider(create: (_) => FileBrowserProvider()),
        ChangeNotifierProvider(create: (_) => TerminalProvider()),
        ChangeNotifierProvider(create: (_) => LocalTerminalProvider()),
      ],
      child: MaterialApp(
        title: 'HPCC Connect',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const HomeScreen(),
      ),
    );
  }
}
