import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/command_snippet.dart';

/// Provider for managing command snippets
class SnippetProvider extends ChangeNotifier {
  Box<CommandSnippet>? _snippetsBox;
  bool _isInitialized = false;
  String? _errorMessage;

  /// List of all snippets
  List<CommandSnippet> get snippets {
    try {
      final list = _snippetsBox?.values.toList() ?? [];
      // Sort by name for consistent display
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    } catch (e) {
      debugPrint('Error reading snippets: $e');
      return [];
    }
  }

  /// Whether the provider is initialized
  bool get isInitialized => _isInitialized;

  /// Error message if initialization failed
  String? get errorMessage => _errorMessage;

  SnippetProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Try to get the box (it should already be opened in main.dart)
      if (Hive.isBoxOpen('snippets')) {
        _snippetsBox = Hive.box<CommandSnippet>('snippets');
      } else {
        _snippetsBox = await Hive.openBox<CommandSnippet>('snippets');
      }

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('SnippetProvider initialization error: $e');
      _errorMessage = 'Failed to load saved snippets. Starting fresh.';
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Create a new snippet with default values
  CommandSnippet createNewSnippet() {
    return CommandSnippet(
      id: const Uuid().v4(),
      name: '',
      command: '',
    );
  }

  /// Add a new snippet
  Future<void> addSnippet(CommandSnippet snippet) async {
    try {
      await _snippetsBox?.put(snippet.id, snippet);
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding snippet: $e');
      _errorMessage = 'Failed to save snippet';
      notifyListeners();
    }
  }

  /// Update an existing snippet
  Future<void> updateSnippet(CommandSnippet snippet) async {
    try {
      final updated = snippet.copyWith(updatedAt: DateTime.now());
      await _snippetsBox?.put(updated.id, updated);
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating snippet: $e');
      _errorMessage = 'Failed to update snippet';
      notifyListeners();
    }
  }

  /// Delete a snippet
  Future<void> deleteSnippet(String id) async {
    try {
      await _snippetsBox?.delete(id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting snippet: $e');
      _errorMessage = 'Failed to delete snippet';
      notifyListeners();
    }
  }

  /// Get a snippet by ID
  CommandSnippet? getSnippet(String id) {
    try {
      return _snippetsBox?.get(id);
    } catch (e) {
      debugPrint('Error getting snippet: $e');
      return null;
    }
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
