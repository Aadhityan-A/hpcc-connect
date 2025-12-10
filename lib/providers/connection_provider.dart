import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/ssh_connection.dart';
import '../services/ssh_service.dart';

class ConnectionProvider extends ChangeNotifier {
  final SSHService _sshService = SSHService();
  Box<SSHConnection>? _connectionsBox;
  
  SSHConnection? _selectedConnection;
  bool _isConnecting = false;
  String? _connectionError;
  bool _isInitialized = false;

  List<SSHConnection> get connections {
    try {
      return _connectionsBox?.values.toList() ?? [];
    } catch (e) {
      debugPrint('Error reading connections: $e');
      return [];
    }
  }
  
  SSHConnection? get selectedConnection => _selectedConnection;
  SSHConnection? get activeConnection => _sshService.currentConnection;
  bool get isConnected => _sshService.isConnected;
  bool get isConnecting => _isConnecting;
  String? get connectionError => _connectionError;
  SSHService get sshService => _sshService;
  bool get isInitialized => _isInitialized;

  ConnectionProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Register adapter for AuthType if not already registered
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(AuthTypeAdapter());
      }
      
      // Try to get the box (it should already be opened in main.dart)
      if (Hive.isBoxOpen('connections')) {
        _connectionsBox = Hive.box<SSHConnection>('connections');
      } else {
        _connectionsBox = await Hive.openBox<SSHConnection>('connections');
      }
      
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('ConnectionProvider initialization error: $e');
      _connectionError = 'Failed to load saved connections. Starting fresh.';
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Add new connection
  Future<void> addConnection(SSHConnection connection) async {
    try {
      await _connectionsBox?.put(connection.id, connection);
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding connection: $e');
      _connectionError = 'Failed to save connection';
      notifyListeners();
    }
  }

  /// Update existing connection
  Future<void> updateConnection(SSHConnection connection) async {
    try {
      await _connectionsBox?.put(connection.id, connection);
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating connection: $e');
    }
  }

  /// Delete connection
  Future<void> deleteConnection(String id) async {
    try {
      if (_selectedConnection?.id == id) {
        await disconnect();
        _selectedConnection = null;
      }
      await _connectionsBox?.delete(id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting connection: $e');
    }
  }

  /// Select a connection
  void selectConnection(SSHConnection connection) {
    _selectedConnection = connection;
    _connectionError = null;
    notifyListeners();
  }

  /// Connect to selected connection
  Future<void> connect() async {
    if (_selectedConnection == null) return;

    _isConnecting = true;
    _connectionError = null;
    notifyListeners();

    try {
      await _sshService.connect(_selectedConnection!);
      
      // Update last connected time
      final updated = _selectedConnection!.copyWith(
        lastConnected: DateTime.now(),
      );
      await updateConnection(updated);
      _selectedConnection = updated;
      
    } catch (e) {
      _connectionError = e.toString();
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  /// Disconnect current connection
  Future<void> disconnect() async {
    await _sshService.disconnect();
    notifyListeners();
  }

  /// Create a new connection with default values
  SSHConnection createNewConnection() {
    return SSHConnection(
      id: const Uuid().v4(),
      name: 'New Connection',
      host: '',
      port: 22,
      username: '',
      authType: AuthType.password,
    );
  }

  /// Test connection without saving
  Future<bool> testConnection(SSHConnection connection) async {
    final testService = SSHService();
    try {
      await testService.connect(connection);
      await testService.disconnect();
      return true;
    } catch (e) {
      return false;
    } finally {
      testService.dispose();
    }
  }

  /// Clear all saved connections (for troubleshooting)
  Future<void> clearAllConnections() async {
    try {
      await _connectionsBox?.clear();
      _selectedConnection = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing connections: $e');
    }
  }

  @override
  void dispose() {
    _sshService.dispose();
    super.dispose();
  }
}
