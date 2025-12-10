import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:hive_flutter/hive_flutter.dart';

import '../models/file_entry.dart';

import 'autocomplete_models.dart';

typedef DirectoryFetcher = Future<List<FileEntry>> Function(String path);

/// VS Code-style terminal IntelliSense service
/// Features:
/// - Command suggestions with descriptions
/// - Argument/flag completion for known commands
/// - Path completion with file type detection
/// - Command history with fuzzy search (Ctrl+R style)
/// - Recent directories tracking (Ctrl+G style)
/// - Trigger characters (-, /)
/// - Quick suggestions
/// - Global completion caching
class AutocompleteService {
  // Singleton instance
  static final AutocompleteService _instance = AutocompleteService._internal();
  factory AutocompleteService() => _instance;
  AutocompleteService._internal();

  /// Cached command list from PATH
  List<String>? _cachedPathCommands;
  DateTime? _cacheTime;
  static const _cacheExpiry = Duration(minutes: 5);

  /// Command history
  final List<CommandHistoryEntry> _commandHistory = [];
  static const int _maxHistorySize = 500;

  /// Recent directories
  final List<String> _recentDirectories = [];
  static const int _maxRecentDirs = 50;

  /// Last command exit codes (for decorations)
  final Map<String, int> _lastExitCodes = {};

  /// Known commands with their flags/arguments
  static final Map<String, CommandInfo> _knownCommands = {
    // File operations
    'ls': const CommandInfo(
      description: 'List directory contents',
      flags: ['-l', '-a', '-la', '-lh', '-R', '-S', '-t', '-r', '--color', '--help'],
      argType: ArgType.path,
    ),
    'cd': const CommandInfo(
      description: 'Change directory',
      argType: ArgType.directory,
    ),
    'cat': const CommandInfo(
      description: 'Concatenate and display files',
      flags: ['-n', '-b', '-s', '-E', '-T', '-v', '--help'],
      argType: ArgType.file,
    ),
    'cp': const CommandInfo(
      description: 'Copy files and directories',
      flags: ['-r', '-R', '-i', '-f', '-v', '-n', '-p', '-a', '--help'],
      argType: ArgType.path,
    ),
    'mv': const CommandInfo(
      description: 'Move/rename files',
      flags: ['-i', '-f', '-v', '-n', '--help'],
      argType: ArgType.path,
    ),
    'rm': const CommandInfo(
      description: 'Remove files or directories',
      flags: ['-r', '-R', '-f', '-i', '-v', '-d', '--help'],
      argType: ArgType.path,
    ),
    'mkdir': const CommandInfo(
      description: 'Create directories',
      flags: ['-p', '-m', '-v', '--help'],
      argType: ArgType.path,
    ),
    'touch': const CommandInfo(
      description: 'Create empty file or update timestamp',
      flags: ['-a', '-m', '-c', '-t', '--help'],
      argType: ArgType.path,
    ),
    'chmod': const CommandInfo(
      description: 'Change file permissions',
      flags: ['-R', '-v', '-c', '--help'],
      argType: ArgType.path,
    ),
    'chown': const CommandInfo(
      description: 'Change file owner',
      flags: ['-R', '-v', '-c', '-h', '--help'],
      argType: ArgType.path,
    ),
    // Text processing
    'grep': const CommandInfo(
      description: 'Search text patterns',
      flags: ['-i', '-v', '-r', '-R', '-n', '-l', '-c', '-E', '-w', '-A', '-B', '-C', '--color', '--help'],
      argType: ArgType.file,
    ),
    'find': const CommandInfo(
      description: 'Find files in directory tree',
      flags: ['-name', '-type', '-size', '-mtime', '-exec', '-print', '-delete', '-maxdepth', '-mindepth'],
      argType: ArgType.directory,
    ),
    'sed': const CommandInfo(
      description: 'Stream editor',
      flags: ['-i', '-e', '-n', '-r', '-E', '--help'],
      argType: ArgType.file,
    ),
    'awk': const CommandInfo(
      description: 'Pattern scanning and processing',
      flags: ['-F', '-v', '-f', '--help'],
      argType: ArgType.file,
    ),
    'head': const CommandInfo(
      description: 'Output first part of files',
      flags: ['-n', '-c', '-q', '-v', '--help'],
      argType: ArgType.file,
    ),
    'tail': const CommandInfo(
      description: 'Output last part of files',
      flags: ['-n', '-c', '-f', '-F', '-q', '-v', '--help'],
      argType: ArgType.file,
    ),
    'sort': const CommandInfo(
      description: 'Sort lines of text',
      flags: ['-r', '-n', '-k', '-t', '-u', '-f', '-o', '--help'],
      argType: ArgType.file,
    ),
    'uniq': const CommandInfo(
      description: 'Report or omit repeated lines',
      flags: ['-c', '-d', '-u', '-i', '-f', '-s', '--help'],
      argType: ArgType.file,
    ),
    'wc': const CommandInfo(
      description: 'Word, line, character count',
      flags: ['-l', '-w', '-c', '-m', '-L', '--help'],
      argType: ArgType.file,
    ),
    // Git commands
    'git': const CommandInfo(
      description: 'Version control system',
      subcommands: {
        'init': 'Initialize a repository',
        'clone': 'Clone a repository',
        'add': 'Add files to staging',
        'commit': 'Commit changes',
        'push': 'Push to remote',
        'pull': 'Pull from remote',
        'fetch': 'Fetch from remote',
        'checkout': 'Switch branches',
        'branch': 'List/create branches',
        'merge': 'Merge branches',
        'rebase': 'Rebase commits',
        'status': 'Show working tree status',
        'log': 'Show commit log',
        'diff': 'Show changes',
        'stash': 'Stash changes',
        'reset': 'Reset HEAD',
        'revert': 'Revert commits',
        'tag': 'Create tags',
        'remote': 'Manage remotes',
        'config': 'Get/set configuration',
      },
      flags: ['--version', '--help', '-C', '--git-dir', '--work-tree'],
    ),
    // Package managers
    'npm': const CommandInfo(
      description: 'Node.js package manager',
      subcommands: {
        'install': 'Install packages',
        'uninstall': 'Remove packages',
        'update': 'Update packages',
        'init': 'Create package.json',
        'run': 'Run scripts',
        'start': 'Start application',
        'test': 'Run tests',
        'build': 'Build project',
        'publish': 'Publish package',
        'ls': 'List installed packages',
        'outdated': 'Check for outdated packages',
        'audit': 'Security audit',
        'cache': 'Manage cache',
      },
      flags: ['-g', '--save', '--save-dev', '-D', '--production', '--legacy-peer-deps'],
    ),
    'pip': const CommandInfo(
      description: 'Python package manager',
      subcommands: {
        'install': 'Install packages',
        'uninstall': 'Remove packages',
        'freeze': 'Output installed packages',
        'list': 'List installed packages',
        'show': 'Show package info',
        'search': 'Search packages',
        'download': 'Download packages',
        'wheel': 'Build wheels',
        'cache': 'Manage cache',
        'config': 'Manage configuration',
        'check': 'Verify dependencies',
      },
      flags: ['-r', '--upgrade', '-U', '--user', '--no-cache-dir', '-e', '--target', '-t'],
    ),
    'pip3': const CommandInfo(
      description: 'Python 3 package manager',
      subcommands: {
        'install': 'Install packages',
        'uninstall': 'Remove packages',
        'freeze': 'Output installed packages',
        'list': 'List installed packages',
        'show': 'Show package info',
      },
      flags: ['-r', '--upgrade', '-U', '--user', '--no-cache-dir', '-e', '--target', '-t'],
    ),
    // Docker
    'docker': const CommandInfo(
      description: 'Container platform',
      subcommands: {
        'run': 'Run a container',
        'build': 'Build image',
        'pull': 'Pull image',
        'push': 'Push image',
        'images': 'List images',
        'ps': 'List containers',
        'stop': 'Stop containers',
        'start': 'Start containers',
        'rm': 'Remove containers',
        'rmi': 'Remove images',
        'exec': 'Execute command in container',
        'logs': 'View logs',
        'compose': 'Docker Compose',
        'network': 'Manage networks',
        'volume': 'Manage volumes',
      },
      flags: ['-d', '-it', '--rm', '-p', '-v', '-e', '--name', '--network', '-f'],
    ),
    // Network
    'ssh': const CommandInfo(
      description: 'Secure shell client',
      flags: ['-p', '-i', '-L', '-R', '-D', '-N', '-f', '-v', '-X', '-Y', '-C', '-o', '-J'],
    ),
    'scp': const CommandInfo(
      description: 'Secure copy',
      flags: ['-r', '-P', '-i', '-C', '-p', '-q', '-v', '-o'],
      argType: ArgType.path,
    ),
    'rsync': const CommandInfo(
      description: 'Remote sync',
      flags: ['-a', '-v', '-z', '-r', '-P', '--progress', '--delete', '-n', '--dry-run', '-e', '--exclude'],
      argType: ArgType.path,
    ),
    'curl': const CommandInfo(
      description: 'Transfer data from URL',
      flags: ['-X', '-H', '-d', '-o', '-O', '-L', '-f', '-s', '-S', '-k', '-v', '-I', '--data', '--header'],
    ),
    'wget': const CommandInfo(
      description: 'Download files',
      flags: ['-O', '-q', '-c', '-r', '-P', '-N', '--no-check-certificate', '-b', '--limit-rate'],
    ),
    // Process management
    'ps': const CommandInfo(
      description: 'Report process status',
      flags: ['aux', '-e', '-f', '-l', '-p', '--forest', '-u', '-x'],
    ),
    'kill': const CommandInfo(
      description: 'Terminate processes',
      flags: ['-9', '-15', '-SIGTERM', '-SIGKILL', '-l', '-s'],
    ),
    'top': const CommandInfo(
      description: 'Display system tasks',
      flags: ['-d', '-u', '-p', '-n', '-b'],
    ),
    'htop': const CommandInfo(
      description: 'Interactive process viewer',
      flags: ['-d', '-u', '-p', '-t', '-s'],
    ),
    // System
    'sudo': const CommandInfo(
      description: 'Execute as superuser',
      flags: ['-s', '-i', '-u', '-E', '-k', '-K'],
    ),
    'man': const CommandInfo(
      description: 'Manual pages',
      flags: ['-k', '-f', '-a', '-w'],
    ),
    'which': const CommandInfo(
      description: 'Locate a command',
      flags: ['-a'],
    ),
    'echo': const CommandInfo(
      description: 'Display a line of text',
      flags: ['-n', '-e', '-E'],
    ),
    'export': const CommandInfo(
      description: 'Set environment variable',
      flags: ['-n', '-p'],
    ),
    'env': const CommandInfo(
      description: 'Display environment',
      flags: ['-i', '-u', '-0'],
    ),
    'history': const CommandInfo(
      description: 'Command history',
      flags: ['-c', '-d', '-a', '-n', '-r', '-w'],
    ),
    'clear': const CommandInfo(
      description: 'Clear terminal screen',
    ),
    // Compression
    'tar': const CommandInfo(
      description: 'Archive utility',
      flags: ['-c', '-x', '-t', '-z', '-j', '-J', '-v', '-f', '-C', '--exclude'],
      argType: ArgType.file,
    ),
    'zip': const CommandInfo(
      description: 'Package and compress files',
      flags: ['-r', '-q', '-v', '-e', '-9', '-0'],
      argType: ArgType.path,
    ),
    'unzip': const CommandInfo(
      description: 'Extract zip archives',
      flags: ['-l', '-t', '-o', '-d', '-q'],
      argType: ArgType.file,
    ),
    'gzip': const CommandInfo(
      description: 'Compress files',
      flags: ['-d', '-k', '-l', '-r', '-v', '-1', '-9'],
      argType: ArgType.file,
    ),
    'gunzip': const CommandInfo(
      description: 'Decompress files',
      flags: ['-k', '-l', '-r', '-v'],
      argType: ArgType.file,
    ),
    // Editors
    'vim': const CommandInfo(
      description: 'Vi Improved text editor',
      flags: ['-R', '-O', '-o', '-p', '-d', '-u', '-N', '-c'],
      argType: ArgType.file,
    ),
    'nano': const CommandInfo(
      description: 'Simple text editor',
      flags: ['-B', '-l', '-m', '-w', '-c', '-i'],
      argType: ArgType.file,
    ),
    'code': const CommandInfo(
      description: 'Visual Studio Code',
      flags: ['-n', '-r', '-g', '-d', '--diff', '-w', '--wait', '-a', '--add', '--new-window'],
      argType: ArgType.path,
    ),
    // Python
    'python': const CommandInfo(
      description: 'Python interpreter',
      flags: ['-c', '-m', '-i', '-V', '--version', '-h', '--help', '-u', '-O', '-B'],
      argType: ArgType.file,
    ),
    'python3': const CommandInfo(
      description: 'Python 3 interpreter',
      flags: ['-c', '-m', '-i', '-V', '--version', '-h', '--help', '-u', '-O', '-B'],
      argType: ArgType.file,
    ),
    // Node
    'node': const CommandInfo(
      description: 'Node.js JavaScript runtime',
      flags: ['-e', '-p', '-c', '-r', '-v', '--version', '-h', '--help', '--inspect'],
      argType: ArgType.file,
    ),
    'npx': const CommandInfo(
      description: 'Execute npm packages',
      flags: ['-p', '-c', '-y', '-n', '--no-install', '--quiet'],
    ),
    // Flutter/Dart
    'flutter': const CommandInfo(
      description: 'Flutter SDK',
      subcommands: {
        'create': 'Create new project',
        'run': 'Run application',
        'build': 'Build application',
        'test': 'Run tests',
        'doctor': 'Check installation',
        'pub': 'Pub commands',
        'clean': 'Clean build files',
        'analyze': 'Analyze code',
        'format': 'Format code',
        'upgrade': 'Upgrade Flutter',
        'devices': 'List devices',
        'install': 'Install app on device',
        'attach': 'Attach to running app',
        'logs': 'Show device logs',
        'config': 'Configure Flutter',
        'channel': 'Switch channel',
        'gen-l10n': 'Generate localizations',
      },
      flags: ['-d', '-v', '--verbose', '--version', '-h', '--help', '--release', '--debug', '--profile'],
    ),
    'dart': const CommandInfo(
      description: 'Dart SDK',
      subcommands: {
        'analyze': 'Analyze code',
        'compile': 'Compile Dart',
        'create': 'Create project',
        'doc': 'Generate documentation',
        'fix': 'Apply fixes',
        'format': 'Format code',
        'info': 'Show info',
        'pub': 'Pub commands',
        'run': 'Run Dart program',
        'test': 'Run tests',
      },
      flags: ['-h', '--help', '--version', '-v', '--verbose'],
    ),
    // Cargo/Rust
    'cargo': const CommandInfo(
      description: 'Rust package manager',
      subcommands: {
        'new': 'Create new project',
        'init': 'Initialize project',
        'build': 'Build project',
        'run': 'Run project',
        'test': 'Run tests',
        'check': 'Check project',
        'clean': 'Clean build',
        'doc': 'Build documentation',
        'publish': 'Publish crate',
        'install': 'Install binary',
        'update': 'Update dependencies',
        'fmt': 'Format code',
        'clippy': 'Lint code',
      },
      flags: ['--release', '--all', '-p', '--package', '-j', '--jobs', '-v', '--verbose'],
    ),
  };

  /// Windows-specific commands
  static final Map<String, CommandInfo> _windowsCommands = {
    'dir': const CommandInfo(
      description: 'List directory contents',
      flags: ['/a', '/b', '/c', '/d', '/l', '/n', '/o', '/p', '/q', '/r', '/s', '/t', '/w', '/x'],
      argType: ArgType.path,
    ),
    'cls': const CommandInfo(
      description: 'Clear screen',
    ),
    'copy': const CommandInfo(
      description: 'Copy files',
      flags: ['/a', '/b', '/d', '/v', '/y', '/-y', '/z'],
      argType: ArgType.path,
    ),
    'move': const CommandInfo(
      description: 'Move files',
      flags: ['/y', '/-y'],
      argType: ArgType.path,
    ),
    'del': const CommandInfo(
      description: 'Delete files',
      flags: ['/p', '/f', '/s', '/q', '/a'],
      argType: ArgType.path,
    ),
    'type': const CommandInfo(
      description: 'Display file contents',
      argType: ArgType.file,
    ),
    'ipconfig': const CommandInfo(
      description: 'IP configuration',
      flags: ['/all', '/release', '/renew', '/flushdns', '/displaydns'],
    ),
    'tasklist': const CommandInfo(
      description: 'List running processes',
      flags: ['/v', '/svc', '/fi', '/fo', '/m'],
    ),
    'taskkill': const CommandInfo(
      description: 'Kill processes',
      flags: ['/pid', '/im', '/f', '/t'],
    ),
    'systeminfo': const CommandInfo(
      description: 'Display system info',
      flags: ['/s', '/u', '/p', '/fo'],
    ),
  };

  /// Dynamic commands discovered at runtime
  final Map<String, CommandInfo> _dynamicCommands = {};

  /// Get commands for current platform
  Map<String, CommandInfo> get _platformCommands {
    final commands = {..._knownCommands, ..._dynamicCommands};
    if (Platform.isWindows) {
      return {...commands, ..._windowsCommands};
    }
    return commands;
  }

  CommandInfo? _getCachedCommand(String key) {
    final known = _knownCommands[key];
    if (known != null) return known;
    final dynamicInfo = _dynamicCommands[key];
    if (dynamicInfo != null) return dynamicInfo;
    if (Platform.isWindows) {
      return _windowsCommands[key];
    }
    return null;
  }

  Future<CommandInfo?> _fetchCommandInfo(
    String commandKey,
    Future<String> Function(String) commandRunner,
  ) async {
    final cached = _getCachedCommand(commandKey);
    if (cached != null) {
      return cached;
    }

    try {
      final output = await commandRunner('$commandKey --help');
      if (output.trim().isEmpty) {
        return null;
      }
      final info = HelpParser.parse(output);
      _dynamicCommands[commandKey] = info;
      return info;
    } catch (_) {
      return null;
    }
  }

  /// Initialize service (load persisted data)
  Future<void> initialize() async {
    try {
      final box = await Hive.openBox('autocomplete');
      
      // Load command history
      final historyData = box.get('commandHistory', defaultValue: <dynamic>[]);
      for (final item in historyData) {
        if (item is Map) {
          _commandHistory.add(CommandHistoryEntry(
            command: item['command'] as String,
            timestamp: DateTime.parse(item['timestamp'] as String),
            directory: item['directory'] as String?,
            exitCode: item['exitCode'] as int?,
          ));
        }
      }

      // Load recent directories
      final dirsData = box.get('recentDirectories', defaultValue: <dynamic>[]);
      _recentDirectories.addAll(dirsData.cast<String>());
    } catch (e) {
      // Ignore errors, use empty history
    }
  }

  /// Save data to persistence
  Future<void> _saveData() async {
    try {
      final box = await Hive.openBox('autocomplete');
      
      // Save command history
      final historyData = _commandHistory.map((e) => {
        'command': e.command,
        'timestamp': e.timestamp.toIso8601String(),
        'directory': e.directory,
        'exitCode': e.exitCode,
      }).toList();
      await box.put('commandHistory', historyData);
      
      // Save recent directories
      await box.put('recentDirectories', _recentDirectories);
    } catch (e) {
      // Ignore save errors
    }
  }

  /// Add command to history with context
  void addToHistory(String command, {String? directory, int? exitCode}) {
    final trimmed = command.trim();
    if (trimmed.isEmpty) return;
    
    // Remove duplicate if exists
    _commandHistory.removeWhere((e) => e.command == trimmed);
    
    _commandHistory.add(CommandHistoryEntry(
      command: trimmed,
      timestamp: DateTime.now(),
      directory: directory,
      exitCode: exitCode,
    ));
    
    // Limit size
    while (_commandHistory.length > _maxHistorySize) {
      _commandHistory.removeAt(0);
    }
    
    // Track last exit code
    if (exitCode != null) {
      _lastExitCodes[trimmed] = exitCode;
    }
    
    _saveData();
  }

  /// Add directory to recent list
  void addRecentDirectory(String directory) {
    _recentDirectories.remove(directory);
    _recentDirectories.insert(0, directory);
    
    while (_recentDirectories.length > _maxRecentDirs) {
      _recentDirectories.removeLast();
    }
    
    _saveData();
  }

  /// Get command history
  List<CommandHistoryEntry> get commandHistory => List.unmodifiable(_commandHistory.reversed.toList());

  /// Get recent directories
  List<String> get recentDirectories => List.unmodifiable(_recentDirectories);

  /// Search history with fuzzy matching (Ctrl+R style)
  List<CommandHistoryEntry> searchHistory(String query, {int limit = 20}) {
    if (query.isEmpty) {
      return _commandHistory.reversed.take(limit).toList();
    }
    
    final lowerQuery = query.toLowerCase();
    final results = <(CommandHistoryEntry, double)>[];
    
    for (final entry in _commandHistory.reversed) {
      final score = _fuzzyMatch(entry.command.toLowerCase(), lowerQuery);
      if (score > 0) {
        results.add((entry, score));
      }
    }
    
    // Sort by score descending
    results.sort((a, b) => b.$2.compareTo(a.$2));
    
    return results.take(limit).map((e) => e.$1).toList();
  }

  /// Search recent directories (Ctrl+G style)
  List<String> searchDirectories(String query, {int limit = 15}) {
    if (query.isEmpty) {
      return _recentDirectories.take(limit).toList();
    }
    
    final lowerQuery = query.toLowerCase();
    final results = <(String, double)>[];
    
    for (final dir in _recentDirectories) {
      final score = _fuzzyMatch(dir.toLowerCase(), lowerQuery);
      if (score > 0) {
        results.add((dir, score));
      }
    }
    
    results.sort((a, b) => b.$2.compareTo(a.$2));
    return results.take(limit).map((e) => e.$1).toList();
  }

  /// Fuzzy matching score (0 = no match, higher = better match)
  double _fuzzyMatch(String text, String query) {
    if (text.contains(query)) {
      // Exact substring match - high score
      return 100 + (query.length / text.length) * 50;
    }
    
    // Character-by-character fuzzy match
    int queryIndex = 0;
    int matchCount = 0;
    int lastMatchIndex = -1;
    double consecutiveBonus = 0;
    
    for (int i = 0; i < text.length && queryIndex < query.length; i++) {
      if (text[i] == query[queryIndex]) {
        matchCount++;
        if (lastMatchIndex == i - 1) {
          consecutiveBonus += 5; // Bonus for consecutive matches
        }
        lastMatchIndex = i;
        queryIndex++;
      }
    }
    
    if (queryIndex < query.length) {
      return 0; // Not all characters matched
    }
    
    return matchCount / text.length * 50 + consecutiveBonus;
  }

  /// Cache commands from PATH (Unix) or system (Windows)
  Future<List<String>> _getPathCommands() async {
    if (_cachedPathCommands != null && 
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheExpiry) {
      return _cachedPathCommands!;
    }

    final commands = <String>{};
    
    try {
      if (Platform.isWindows) {
        // Windows: Use 'where' command fallback with known commands
        commands.addAll(_windowsCommands.keys);
        commands.addAll(_knownCommands.keys);
      } else {
        // Unix: Scan PATH directories
        final pathEnv = Platform.environment['PATH'] ?? '';
        final pathDirs = pathEnv.split(':');
        
        for (final pathDir in pathDirs) {
          try {
            final dir = Directory(pathDir);
            if (await dir.exists()) {
              await for (final entity in dir.list()) {
                if (entity is File) {
                  final name = p.basename(entity.path);
                  // Skip hidden files and files with extensions
                  if (!name.startsWith('.') && !name.contains('.')) {
                    commands.add(name);
                  }
                }
              }
            }
          } catch (_) {
            // Permission denied, skip
          }
        }
      }
    } catch (_) {
      // Fallback to known commands
    }

    // Add known commands
    commands.addAll(_knownCommands.keys);
    
    _cachedPathCommands = commands.toList()..sort();
    _cacheTime = DateTime.now();
    
    return _cachedPathCommands!;
  }

  /// Get last exit code for command (for decorations)
  int? getLastExitCode(String command) {
    return _lastExitCodes[command.split(' ').first];
  }

  /// Get suggestions for current input
  /// This is the main entry point for IntelliSense
  /// 
  /// [autoTrigger] - true when triggered automatically after selecting a suggestion
  /// This enables VS Code-style continuous IntelliSense where suggestions
  /// automatically appear after completing a command/subcommand/directory
  Future<List<AutocompleteSuggestion>> getSuggestions(
    String input,
    String currentDirectory, {
    String? triggerCharacter,
    bool autoTrigger = false,
    Future<String> Function(String)? commandRunner,
    DirectoryFetcher? directoryFetcher,
    String? homeDirectory,
  }) async {
    if (input.isEmpty) return [];

    final parts = _parseInput(input);
    final lastPart = parts.isNotEmpty ? parts.last : '';
    
    // Trigger character handling (VS Code style)
    if (triggerCharacter == '-') {
      // Flag completion
      // We might need to fetch flags here too if command is unknown
      if (parts.isNotEmpty) {
        // Try to find the longest matching command prefix
        String commandKey = parts[0];
        for (int i = 1; i < parts.length; i++) {
          if (parts[i].startsWith('-')) break;
          final candidate = parts.sublist(0, i + 1).join(' ');
          if (_platformCommands.containsKey(candidate) || _dynamicCommands.containsKey(candidate)) {
            commandKey = candidate;
          } else {
             // If we don't have it, maybe we can fetch it?
             // Only if the previous part was a command
             final prevKey = parts.sublist(0, i).join(' ');
             if ((_platformCommands.containsKey(prevKey) || _dynamicCommands.containsKey(prevKey)) && commandRunner != null) {
                try {
                   final output = await commandRunner('$candidate --help');
                   final info = HelpParser.parse(output);
                   if (info.flags.isNotEmpty || info.subcommands.isNotEmpty) {
                      _dynamicCommands[candidate] = info;
                      commandKey = candidate;
                   }
                } catch (e) {
                   // Ignore
                }
             }
          }
        }
        
        if (!_platformCommands.containsKey(commandKey) && !_dynamicCommands.containsKey(commandKey) && commandRunner != null) {
           try {
             final output = await commandRunner('$commandKey --help');
             final info = HelpParser.parse(output);
             if (info.flags.isNotEmpty || info.subcommands.isNotEmpty) {
                _dynamicCommands[commandKey] = info;
             }
           } catch (e) {
             // Ignore
           }
        }
      }
      return await _getFlagSuggestions(parts, commandRunner: commandRunner);
    } else if (triggerCharacter == '/' || triggerCharacter == Platform.pathSeparator) {
      // Path completion
      return await _getPathSuggestions(
        lastPart,
        currentDirectory,
        directoryFetcher: directoryFetcher,
        homeDirectory: homeDirectory,
      );
    }

    // Smart suggestion based on context
    if (parts.length == 1) {
      // Command completion
      return await _getCommandSuggestions(parts[0]);
    } else {
      final resolution = await _resolveCommand(
        parts,
        commandRunner: commandRunner,
      );
      final commandInfo = resolution.commandInfo;
      final commandPartsCount = resolution.depth;
      final currentArg = parts.last;
      
      // Check if typing a flag
      if (currentArg.startsWith('-')) {
        return await _getFlagSuggestions(parts, commandRunner: commandRunner);
      }
      
      // Check if current arg ends with / (directory was just selected)
      if (currentArg.endsWith('/') || currentArg.endsWith(Platform.pathSeparator)) {
        return await _getPathSuggestions(
          currentArg,
          currentDirectory,
          directoryFetcher: directoryFetcher,
          homeDirectory: homeDirectory,
        );
      }
      
      // Check for subcommand
      // If we are at the position immediately after the resolved command
      if (commandInfo != null && 
          parts.length == commandPartsCount + 1 && 
          commandInfo.subcommands.isNotEmpty) {
        return _getSubcommandSuggestions(commandInfo, currentArg);
      }
      
      // When current argument is empty (just pressed space/tab after selection)
      // Show context-appropriate suggestions automatically (flags, paths, etc.)
      if (currentArg.isEmpty && (autoTrigger || input.endsWith(' '))) {
        return await _getContextualSuggestions(
          parts,
          commandInfo,
          currentDirectory,
          directoryFetcher: directoryFetcher,
          homeDirectory: homeDirectory,
        );
      }
      
      // Path/file completion
      return await _getPathSuggestions(
        currentArg,
        currentDirectory,
        directoryFetcher: directoryFetcher,
        homeDirectory: homeDirectory,
      );
    }
  }

    Future<_CommandResolutionResult> _resolveCommand(
      List<String> parts, {
      Future<String> Function(String)? commandRunner,
    }) async {
      if (parts.isEmpty) {
        return const _CommandResolutionResult(commandKey: '', commandInfo: null, depth: 0);
      }

      String commandKey = parts.first;
      CommandInfo? commandInfo = _getCachedCommand(commandKey);
      int depth = commandInfo != null ? 1 : 0;

      if (commandInfo == null && commandRunner != null) {
        commandInfo = await _fetchCommandInfo(commandKey, commandRunner);
        depth = commandInfo != null ? 1 : 0;
      }

      for (int i = 1; i < parts.length; i++) {
        final part = parts[i];
        if (part.startsWith('-') || part.isEmpty) {
          break;
        }

        final candidateKey = '$commandKey $part';
        CommandInfo? candidateInfo = _getCachedCommand(candidateKey);

        if (candidateInfo == null && commandRunner != null) {
          commandInfo ??= await _fetchCommandInfo(commandKey, commandRunner);
          if (commandInfo != null && commandInfo.subcommands.containsKey(part)) {
            candidateInfo = await _fetchCommandInfo(candidateKey, commandRunner);
          }
        }

        if (candidateInfo != null) {
          commandKey = candidateKey;
          commandInfo = candidateInfo;
          depth++;
        } else {
          break;
        }
      }

      return _CommandResolutionResult(
        commandKey: commandKey,
        commandInfo: commandInfo,
        depth: depth,
      );
    }

  /// Get contextual suggestions when user just completed a selection
  /// This provides VS Code-style continuous IntelliSense
  Future<List<AutocompleteSuggestion>> _getContextualSuggestions(
    List<String> parts,
    CommandInfo? commandInfo,
    String currentDirectory, {
    DirectoryFetcher? directoryFetcher,
    String? homeDirectory,
  }) async {
    final suggestions = <AutocompleteSuggestion>[];
    
    if (parts.length < 2) return suggestions;
    
    final commandName = parts[0];
    final currentArg = parts.last;
    
    // Get subcommand if it exists (e.g., 'install' in 'pip3 install')
    String? subcommand;
    if (parts.length >= 2 && commandInfo?.subcommands.containsKey(parts[1]) == true) {
      subcommand = parts[1];
    }

    final pendingFlag = _pendingFlagRequiringValue(parts, commandInfo);
    if (pendingFlag != null) {
      return await _getValueSuggestionsForFlag(
        pendingFlag,
        currentArg,
        currentDirectory,
        commandInfo,
        directoryFetcher: directoryFetcher,
        homeDirectory: homeDirectory,
      );
    }
    
    // Priority 1: Show flags if the command/subcommand has flags
    if (commandInfo != null && commandInfo.flags.isNotEmpty) {
      // Filter out already used flags
      final usedFlags = parts.where((p) => p.startsWith('-')).toSet();
      
      for (final flag in commandInfo.flags) {
        if (!usedFlags.contains(flag)) {
          final meta = commandInfo.flagMetadata[flag];
          suggestions.add(AutocompleteSuggestion(
            text: flag,
            displayText: flag,
            description: meta != null && meta.description.isNotEmpty
                ? meta.description
                : _getFlagDescription(commandName, flag, subcommand),
            type: SuggestionType.flag,
            requiresValue: meta?.expectsValue ?? false,
            sortKey: '0$flag', // Flags first
          ));
        }
      }
    }
    
    // Priority 2: Show path suggestions if command expects paths
    if (commandInfo?.argType == ArgType.path || 
        commandInfo?.argType == ArgType.file ||
        commandInfo?.argType == ArgType.directory) {
      final pathSuggestions = await _listDirectory(
        currentDirectory,
        basePath: '',
        directoryFetcher: directoryFetcher,
      );
      for (final s in pathSuggestions.take(10)) {
        suggestions.add(AutocompleteSuggestion(
          text: s.text,
          displayText: s.displayText,
          description: s.description,
          type: s.type,
          isDirectory: s.isDirectory,
          fullPath: s.fullPath,
          sortKey: '1${s.sortKey}', // After flags
        ));
      }
    }
    
    // Limit total suggestions
    suggestions.sort((a, b) => a.sortKey.compareTo(b.sortKey));
    return suggestions.take(20).toList();
  }

  /// Get description for a flag (context-aware)
  String _getFlagDescription(String command, String flag, String? subcommand) {
    // Common flag descriptions
    final commonFlags = <String, String>{
      '-h': 'Show help',
      '--help': 'Show help message',
      '-v': 'Verbose output',
      '--verbose': 'Verbose output',
      '-V': 'Show version',
      '--version': 'Show version',
      '-f': 'Force operation',
      '--force': 'Force operation',
      '-r': 'Recursive',
      '-R': 'Recursive',
      '--recursive': 'Recursive operation',
      '-q': 'Quiet mode',
      '--quiet': 'Suppress output',
      '-n': 'Dry run / line numbers',
      '--dry-run': 'Show what would be done',
      '-y': 'Yes to all prompts',
      '--yes': 'Assume yes',
    };
    
    // pip specific
    if (command == 'pip' || command == 'pip3') {
      final pipFlags = <String, String>{
        '-U': 'Upgrade package',
        '--upgrade': 'Upgrade package to latest',
        '-e': 'Install in editable mode',
        '--editable': 'Install in editable mode',
        '-r': 'Install from requirements file',
        '--requirement': 'Install from requirements file',
        '--user': 'Install to user directory',
        '--no-cache-dir': 'Disable cache',
        '--pre': 'Include pre-releases',
        '-t': 'Install to target directory',
        '--target': 'Target directory',
        '--no-deps': 'Skip dependencies',
        '--index-url': 'Base URL of package index',
      };
      if (pipFlags.containsKey(flag)) return pipFlags[flag]!;
    }
    
    // npm specific
    if (command == 'npm') {
      final npmFlags = <String, String>{
        '-g': 'Install globally',
        '--global': 'Install globally',
        '-D': 'Save as dev dependency',
        '--save-dev': 'Save as dev dependency',
        '-S': 'Save as dependency',
        '--save': 'Save as dependency',
        '--production': 'Production mode',
        '--legacy-peer-deps': 'Ignore peer deps',
      };
      if (npmFlags.containsKey(flag)) return npmFlags[flag]!;
    }
    
    // git specific
    if (command == 'git') {
      final gitFlags = <String, String>{
        '-a': 'All / add all',
        '-m': 'Message',
        '-b': 'Branch',
        '--all': 'All branches/files',
        '--amend': 'Amend previous commit',
        '--no-edit': 'Keep previous message',
        '--rebase': 'Rebase instead of merge',
        '-u': 'Set upstream',
        '--set-upstream': 'Set upstream branch',
        '-d': 'Delete',
        '-D': 'Force delete',
      };
      if (gitFlags.containsKey(flag)) return gitFlags[flag]!;
    }
    
    return commonFlags[flag] ?? 'Option';
  }

  String? _pendingFlagRequiringValue(List<String> parts, CommandInfo? commandInfo) {
    if (commandInfo == null || commandInfo.flagMetadata.isEmpty) {
      return null;
    }

    for (int i = 0; i < parts.length; i++) {
      final token = parts[i];
      if (!token.startsWith('-')) continue;
      final meta = commandInfo.flagMetadata[token];
      if (meta?.expectsValue != true) continue;

      final hasValue = (i + 1 < parts.length) &&
          parts[i + 1].isNotEmpty &&
          !parts[i + 1].startsWith('-');
      if (!hasValue) {
        return token;
      }
    }

    return null;
  }

  Future<List<AutocompleteSuggestion>> _getValueSuggestionsForFlag(
    String flag,
    String currentArg,
    String currentDirectory,
    CommandInfo? commandInfo, {
    DirectoryFetcher? directoryFetcher,
    String? homeDirectory,
  }) async {
    final meta = commandInfo?.flagMetadata[flag];
    if (_flagLikelyPath(flag, meta)) {
      return await _getPathSuggestions(
        currentArg,
        currentDirectory,
        directoryFetcher: directoryFetcher,
        homeDirectory: homeDirectory,
      );
    }
    return [];
  }

  bool _flagLikelyPath(String flag, FlagMetadata? meta) {
    final text = '${flag.toLowerCase()} ${meta?.description.toLowerCase() ?? ''}';
    const keywords = [
      'path',
      'dir',
      'directory',
      'file',
      'root',
      'prefix',
      'src',
      'dest',
    ];
    return keywords.any((keyword) => text.contains(keyword));
  }

  String _resolveHomeDirectory(String? override) {
    return override ??
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
  }

  /// Parse input respecting quotes
  List<String> _parseInput(String input) {
    final parts = <String>[];
    final buffer = StringBuffer();
    bool inQuote = false;
    String quoteChar = '';
    
    for (int i = 0; i < input.length; i++) {
      final char = input[i];
      
      if ((char == '"' || char == "'") && !inQuote) {
        inQuote = true;
        quoteChar = char;
      } else if (char == quoteChar && inQuote) {
        inQuote = false;
      } else if (char == ' ' && !inQuote) {
        if (buffer.isNotEmpty) {
          parts.add(buffer.toString());
          buffer.clear();
        }
      } else {
        buffer.write(char);
      }
    }
    
    if (buffer.isNotEmpty) {
      parts.add(buffer.toString());
    }
    
    // Handle trailing space = ready for new argument
    if (input.endsWith(' ') && !inQuote) {
      parts.add('');
    }
    
    return parts;
  }

  /// Get command suggestions
  Future<List<AutocompleteSuggestion>> _getCommandSuggestions(String prefix) async {
    final suggestions = <AutocompleteSuggestion>[];
    final lowerPrefix = prefix.toLowerCase();
    
    // 1. Known commands with metadata
    for (final entry in _platformCommands.entries) {
      if (entry.key.startsWith(lowerPrefix)) {
        suggestions.add(AutocompleteSuggestion(
          text: entry.key,
          displayText: entry.key,
          description: entry.value.description,
          type: SuggestionType.command,
          sortKey: '0${entry.key}', // Prioritize known commands
        ));
      }
    }
    
    // 2. PATH commands
    final pathCommands = await _getPathCommands();
    for (final cmd in pathCommands) {
      if (cmd.toLowerCase().startsWith(lowerPrefix) &&
          !_platformCommands.containsKey(cmd)) {
        suggestions.add(AutocompleteSuggestion(
          text: cmd,
          displayText: cmd,
          type: SuggestionType.command,
          sortKey: '1$cmd',
        ));
      }
    }
    
    // 3. History commands
    for (final entry in _commandHistory.reversed) {
      final cmdName = entry.command.split(' ').first;
      if (cmdName.toLowerCase().startsWith(lowerPrefix) &&
          !suggestions.any((s) => s.text == cmdName)) {
        suggestions.add(AutocompleteSuggestion(
          text: cmdName,
          displayText: cmdName,
          description: 'From history',
          type: SuggestionType.history,
          sortKey: '2$cmdName',
        ));
      }
      
      // Limit history suggestions
      if (suggestions.where((s) => s.type == SuggestionType.history).length >= 5) {
        break;
      }
    }
    
    // Sort and limit
    suggestions.sort((a, b) => a.sortKey.compareTo(b.sortKey));
    return suggestions.take(20).toList();
  }

  /// Get flag suggestions for a command
  Future<List<AutocompleteSuggestion>> _getFlagSuggestions(
    List<String> parts, {
    Future<String> Function(String)? commandRunner,
  }) async {
    if (parts.isEmpty) return [];

    final resolution = await _resolveCommand(
      parts,
      commandRunner: commandRunner,
    );

    final currentFlag = parts.last;
    final lowerPrefix = currentFlag.toLowerCase();

    final commandInfo = resolution.commandInfo;
    if (commandInfo == null) return [];
    
    final suggestions = <AutocompleteSuggestion>[];
    
    // Filter flags that haven't been used yet
    final usedFlags = parts.where((p) => p.startsWith('-')).toSet();
    
    for (final flag in commandInfo.flags) {
      if (flag.toLowerCase().startsWith(lowerPrefix) && !usedFlags.contains(flag)) {
        final meta = commandInfo.flagMetadata[flag];
        suggestions.add(AutocompleteSuggestion(
          text: flag,
          displayText: flag,
          description: meta?.description ?? '',
          type: SuggestionType.flag,
          sortKey: flag,
          requiresValue: meta?.expectsValue ?? false,
        ));
      }
    }

    int flagRank(String flag) {
      final isLong = flag.startsWith('--');
      final wantsLong = currentFlag.startsWith('--');
      final wantsShort = currentFlag.startsWith('-') && !wantsLong;

      if (wantsLong) {
        return isLong ? 0 : 1;
      }
      if (wantsShort) {
        return isLong ? 1 : 0;
      }

      // Default: prefer short aliases to avoid overwhelming output
      return isLong ? 1 : 0;
    }
    
    suggestions.sort((a, b) {
      final rankA = flagRank(a.text);
      final rankB = flagRank(b.text);
      if (rankA != rankB) {
        return rankA.compareTo(rankB);
      }
      return a.sortKey.compareTo(b.sortKey);
    });
    
    return suggestions.take(15).toList();
  }

  /// Get subcommand suggestions
  List<AutocompleteSuggestion> _getSubcommandSuggestions(
    CommandInfo commandInfo,
    String prefix,
  ) {
    final lowerPrefix = prefix.toLowerCase();
    final suggestions = <AutocompleteSuggestion>[];
    
    for (final entry in commandInfo.subcommands.entries) {
      if (entry.key.toLowerCase().startsWith(lowerPrefix)) {
        suggestions.add(AutocompleteSuggestion(
          text: entry.key,
          displayText: entry.key,
          description: entry.value,
          type: SuggestionType.subcommand,
          sortKey: entry.key,
        ));
      }
    }
    
    suggestions.sort((a, b) => a.sortKey.compareTo(b.sortKey));
    return suggestions;
  }

  /// Get path suggestions
  Future<List<AutocompleteSuggestion>> _getPathSuggestions(
    String partialPath,
    String currentDirectory, {
    DirectoryFetcher? directoryFetcher,
    String? homeDirectory,
  }) async {
    String searchPath;
    String searchPrefix;
    String basePath = '';

    if (partialPath.isEmpty) {
      // List current directory
      return await _listDirectory(
        currentDirectory,
        basePath: '',
        directoryFetcher: directoryFetcher,
      );
    }

    // Special handling for paths ending with / - list that directory's contents
    if (partialPath.endsWith('/') || partialPath.endsWith(Platform.pathSeparator)) {
      if (p.isAbsolute(partialPath)) {
        searchPath = partialPath;
      } else if (partialPath.startsWith('~')) {
        final home = _resolveHomeDirectory(homeDirectory);
        searchPath = partialPath.replaceFirst('~', home);
      } else {
        searchPath = p.join(currentDirectory, partialPath);
      }
      // Remove trailing slash for Directory
      if (searchPath.endsWith('/')) {
        searchPath = searchPath.substring(0, searchPath.length - 1);
      }
      return await _listDirectory(searchPath, prefix: '', basePath: partialPath);
    }

    // Resolve the path
    if (p.isAbsolute(partialPath)) {
      final dir = Directory(p.dirname(partialPath));
      searchPath = dir.path;
      searchPrefix = p.basename(partialPath);
      basePath = p.dirname(partialPath);
      if (!basePath.endsWith(Platform.pathSeparator)) {
        basePath += Platform.pathSeparator;
      }
    } else if (partialPath.startsWith('~')) {
      final home = _resolveHomeDirectory(homeDirectory);
      final expandedPath = partialPath.replaceFirst('~', home);
      final dir = Directory(p.dirname(expandedPath));
      searchPath = dir.path;
      searchPrefix = p.basename(expandedPath);
      // Keep the ~ in the completion
      basePath = '~${p.dirname(partialPath.substring(1))}';
      if (basePath != '~' && !basePath.endsWith(Platform.pathSeparator)) {
        basePath += Platform.pathSeparator;
      }
      if (basePath == '~') basePath = '~/';
    } else if (partialPath.contains(Platform.pathSeparator) || 
               partialPath.contains('/')) {
      final fullPath = p.join(currentDirectory, partialPath);
      final dir = Directory(p.dirname(fullPath));
      searchPath = dir.path;
      searchPrefix = p.basename(fullPath);
      basePath = p.dirname(partialPath);
      if (!basePath.endsWith(Platform.pathSeparator)) {
        basePath += Platform.pathSeparator;
      }
    } else {
      searchPath = currentDirectory;
      searchPrefix = partialPath;
      basePath = '';
    }

    return await _listDirectory(
      searchPath,
      prefix: searchPrefix,
      basePath: basePath,
      directoryFetcher: directoryFetcher,
    );
  }

  /// List directory with type detection
  Future<List<AutocompleteSuggestion>> _listDirectory(
    String path, {
    String prefix = '',
    String basePath = '',
    DirectoryFetcher? directoryFetcher,
  }) async {
    final suggestions = <AutocompleteSuggestion>[];

    try {
      if (directoryFetcher != null) {
        final entries = await directoryFetcher(path);
        for (final entry in entries) {
          final name = entry.name;

          if (name.startsWith('.') && !prefix.startsWith('.')) {
            continue;
          }

          if (prefix.isNotEmpty &&
              !name.toLowerCase().startsWith(prefix.toLowerCase())) {
            continue;
          }

          final isExecutable = (entry.permissions ?? '').contains('x');
          suggestions.add(
            _buildSuggestion(
              name: name,
              basePath: basePath,
              isDirectory: entry.isDirectory,
              isExecutable: isExecutable,
              fullPath: entry.path,
            ),
          );
        }

        suggestions.sort((a, b) => a.sortKey.compareTo(b.sortKey));
        return suggestions;
      }

      final dir = Directory(path);
      if (!await dir.exists()) return suggestions;

      await for (final entity in dir.list()) {
        final name = p.basename(entity.path);

        // Skip hidden files unless prefix starts with .
        if (name.startsWith('.') && !prefix.startsWith('.')) {
          continue;
        }

        // Filter by prefix (case-insensitive)
        if (prefix.isNotEmpty &&
            !name.toLowerCase().startsWith(prefix.toLowerCase())) {
          continue;
        }

        final isDir = entity is Directory;
        final isExecutable = await _isExecutable(entity);

        suggestions.add(
          _buildSuggestion(
            name: name,
            basePath: basePath,
            isDirectory: isDir,
            isExecutable: isExecutable,
            fullPath: entity.path,
          ),
        );
      }

      suggestions.sort((a, b) => a.sortKey.compareTo(b.sortKey));
    } catch (_) {
      return suggestions;
    }

    return suggestions.take(25).toList();
  }

  AutocompleteSuggestion _buildSuggestion({
    required String name,
    required String basePath,
    required bool isDirectory,
    required bool isExecutable,
    required String fullPath,
  }) {
    final extension = p.extension(name).toLowerCase();

    SuggestionType type;
    String description;

    if (isDirectory) {
      type = SuggestionType.directory;
      description = 'Directory';
    } else if (isExecutable) {
      type = SuggestionType.executable;
      description = 'Executable';
    } else {
      type = _getFileType(extension);
      description = _getFileDescription(extension);
    }

    return AutocompleteSuggestion(
      text: isDirectory ? '$basePath$name/' : '$basePath$name',
      displayText: name,
      description: description,
      type: type,
      isDirectory: isDirectory,
      fullPath: fullPath,
      sortKey: '${isDirectory ? '0' : '1'}$name',
    );
  }

  /// Check if file is executable
  Future<bool> _isExecutable(FileSystemEntity entity) async {
    if (entity is! File) return false;
    if (Platform.isWindows) {
      final ext = p.extension(entity.path).toLowerCase();
      return ['.exe', '.bat', '.cmd', '.ps1', '.com'].contains(ext);
    }
    try {
      final stat = await entity.stat();
      // Check execute permission (owner)
      return (stat.mode & 0x40) != 0;
    } catch (_) {
      return false;
    }
  }

  /// Get file type from extension
  SuggestionType _getFileType(String extension) {
    switch (extension) {
      case '.py':
      case '.js':
      case '.ts':
      case '.dart':
      case '.java':
      case '.c':
      case '.cpp':
      case '.rs':
      case '.go':
      case '.rb':
      case '.php':
      case '.swift':
      case '.kt':
        return SuggestionType.codeFile;
      case '.json':
      case '.yaml':
      case '.yml':
      case '.toml':
      case '.xml':
      case '.ini':
      case '.conf':
      case '.config':
        return SuggestionType.configFile;
      case '.md':
      case '.txt':
      case '.doc':
      case '.docx':
      case '.pdf':
      case '.rst':
        return SuggestionType.document;
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.gif':
      case '.svg':
      case '.ico':
      case '.webp':
        return SuggestionType.image;
      case '.zip':
      case '.tar':
      case '.gz':
      case '.bz2':
      case '.xz':
      case '.7z':
      case '.rar':
        return SuggestionType.archive;
      case '.sh':
      case '.bash':
      case '.zsh':
      case '.fish':
        return SuggestionType.script;
      default:
        return SuggestionType.file;
    }
  }

  /// Get file description from extension
  String _getFileDescription(String extension) {
    switch (extension) {
      case '.py': return 'Python file';
      case '.js': return 'JavaScript file';
      case '.ts': return 'TypeScript file';
      case '.dart': return 'Dart file';
      case '.java': return 'Java file';
      case '.c': return 'C file';
      case '.cpp': return 'C++ file';
      case '.rs': return 'Rust file';
      case '.go': return 'Go file';
      case '.rb': return 'Ruby file';
      case '.php': return 'PHP file';
      case '.swift': return 'Swift file';
      case '.kt': return 'Kotlin file';
      case '.json': return 'JSON file';
      case '.yaml': case '.yml': return 'YAML file';
      case '.toml': return 'TOML file';
      case '.xml': return 'XML file';
      case '.md': return 'Markdown file';
      case '.txt': return 'Text file';
      case '.sh': return 'Shell script';
      case '.zip': return 'ZIP archive';
      case '.tar': return 'TAR archive';
      case '.gz': return 'Gzip archive';
      default: return '';
    }
  }

  /// Quick fix suggestions based on command output
  List<QuickFixSuggestion> getQuickFixes(String output, String lastCommand) {
    final fixes = <QuickFixSuggestion>[];
    
    // Git push upstream suggestion
    if (output.contains('git push --set-upstream') || 
        output.contains('no upstream branch')) {
      final upstreamPattern = RegExp(r'git push --set-upstream (\S+) (\S+)');
      final match = upstreamPattern.firstMatch(output);
      if (match != null) {
        fixes.add(QuickFixSuggestion(
          title: 'Set upstream and push',
          command: 'git push --set-upstream ${match.group(1)} ${match.group(2)}',
          description: 'Push and set upstream branch',
        ));
      } else {
        fixes.add(QuickFixSuggestion(
          title: 'Push with upstream',
          command: 'git push -u origin HEAD',
          description: 'Push current branch to origin',
        ));
      }
    }
    
    // npm install suggestion
    if (output.contains('Cannot find module') || 
        output.contains('MODULE_NOT_FOUND')) {
      fixes.add(QuickFixSuggestion(
        title: 'Install dependencies',
        command: 'npm install',
        description: 'Run npm install to install missing packages',
      ));
    }
    
    // pip install suggestion
    if (output.contains('ModuleNotFoundError') ||
        output.contains('No module named')) {
      final modulePattern = RegExp(r'No module named (\w+)');
      final match = modulePattern.firstMatch(output);
      if (match != null) {
        fixes.add(QuickFixSuggestion(
          title: 'Install ${match.group(1)}',
          command: 'pip install ${match.group(1)}',
          description: 'Install missing Python package',
        ));
      }
    }
    
    // Permission denied - try with sudo
    if (output.contains('Permission denied') && !lastCommand.startsWith('sudo ')) {
      fixes.add(QuickFixSuggestion(
        title: 'Run with sudo',
        command: 'sudo $lastCommand',
        description: 'Re-run command with elevated privileges',
      ));
    }
    
    // File not found - create it
    if (output.contains('No such file or directory')) {
      final filePattern = RegExp(r'(\S+): No such file');
      final match = filePattern.firstMatch(output);
      if (match != null) {
        final path = match.group(1)!;
        if (!path.contains('.')) {
          fixes.add(QuickFixSuggestion(
            title: 'Create directory',
            command: 'mkdir -p $path',
            description: 'Create the missing directory',
          ));
        } else {
          fixes.add(QuickFixSuggestion(
            title: 'Create file',
            command: 'touch $path',
            description: 'Create the missing file',
          ));
        }
      }
    }
    
    // Git not a repository
    if (output.contains('not a git repository')) {
      fixes.add(QuickFixSuggestion(
        title: 'Initialize git',
        command: 'git init',
        description: 'Initialize a new git repository',
      ));
    }
    
    // Flutter pub get
    if (output.contains('pubspec.yaml') && 
        (output.contains('not found') || output.contains('needs to be run'))) {
      fixes.add(QuickFixSuggestion(
        title: 'Get dependencies',
        command: 'flutter pub get',
        description: 'Get Flutter dependencies',
      ));
    }
    
    return fixes;
  }
}

/// Models moved to autocomplete_models.dart

class _CommandResolutionResult {
  final String commandKey;
  final CommandInfo? commandInfo;
  final int depth;

  const _CommandResolutionResult({
    required this.commandKey,
    required this.commandInfo,
    required this.depth,
  });
}

class HelpParser {
  static final Set<String> _commandHeaders = {
    'commands',
    'subcommands',
    'available commands',
    'available subcommands',
    'common commands',
    'management commands',
  };

  static final Set<String> _optionHeaders = {
    'options',
    'flags',
    'global options',
    'available options',
    'arguments',
    'optional arguments',
  };

  static final Set<String> _resetHeaders = {
    'usage',
    'examples',
    'description',
    'synopsis',
  };

  static CommandInfo parse(String output) {
    final doc = parseDocument(output);
    if (!doc.hasContent) {
      return const CommandInfo(description: 'Dynamically parsed command');
    }
    return CommandInfo.fromParsedHelp(doc);
  }

  static ParsedHelpDocument parseDocument(String output) {
    final normalized = output.replaceAll('\r\n', '\n');
    final lines = normalized.split('\n');
    final commandEntries = <_CommandEntry>[];
    final flagEntries = <_FlagEntry>[];

    _HelpSection section = _HelpSection.none;
    _CommandEntry? lastCommand;
    _FlagEntry? lastFlag;

    for (final rawLine in lines) {
      final line = rawLine.trimRight();
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        lastCommand = null;
        lastFlag = null;
        continue;
      }

      final nextSection = _detectSectionHeader(trimmed);
      if (nextSection != null) {
        section = nextSection;
        lastCommand = null;
        lastFlag = null;
        continue;
      }

      switch (section) {
        case _HelpSection.commands:
          final parsedCommand = _CommandEntry.tryParse(line);
          if (parsedCommand != null) {
            commandEntries.add(parsedCommand);
            lastCommand = parsedCommand;
          } else if (lastCommand != null && line.startsWith(RegExp(r'\s{2,}'))) {
            lastCommand.append(line.trim());
          }
          break;
        case _HelpSection.options:
          final parsedFlag = _FlagEntry.tryParse(line);
          if (parsedFlag != null) {
            flagEntries.add(parsedFlag);
            lastFlag = parsedFlag;
          } else if (lastFlag != null && line.startsWith(RegExp(r'\s{2,}'))) {
            lastFlag.append(line.trim());
          }
          break;
        case _HelpSection.none:
          break;
      }
    }

    return ParsedHelpDocument(
      description: _extractDescription(lines),
      subcommands: [for (final entry in commandEntries) entry.toCommand()],
      flags: [for (final entry in flagEntries) entry.toFlag()],
    );
  }

  static _HelpSection? _detectSectionHeader(String trimmed) {
    if (!trimmed.endsWith(':')) return null;
    final header = trimmed.substring(0, trimmed.length - 1).toLowerCase().trim();

    bool matches(Set<String> exact, List<String> keywords) {
      if (exact.contains(header)) return true;
      for (final keyword in keywords) {
        if (header.contains(keyword)) {
          return true;
        }
      }
      return false;
    }

    if (matches(_commandHeaders, const ['command'])) {
      return _HelpSection.commands;
    }

    if (matches(_optionHeaders, const ['option', 'flag', 'argument'])) {
      return _HelpSection.options;
    }

    if (matches(_resetHeaders, const ['usage', 'description', 'synopsis', 'example'])) {
      return _HelpSection.none;
    }

    return null;
  }

  static String? _extractDescription(List<String> lines) {
    for (final rawLine in lines) {
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty) continue;
      final lower = trimmed.toLowerCase();
      if (lower.startsWith('usage')) continue;
      if (trimmed.endsWith(':')) {
        final header = trimmed.substring(0, trimmed.length - 1).toLowerCase();
        if (_commandHeaders.contains(header) || _optionHeaders.contains(header) || _resetHeaders.contains(header)) {
          continue;
        }
      }
      return trimmed;
    }
    return null;
  }
}

enum _HelpSection { none, commands, options }

class _CommandEntry {
  _CommandEntry(this.name, String description) {
    append(description);
  }

  final String name;
  final StringBuffer _description = StringBuffer();

  static final RegExp _pattern = RegExp(r'^\s*([A-Za-z0-9:_-]+(?:\s+[A-Za-z0-9:_-]+)*)\s{2,}(.+)$');

  static _CommandEntry? tryParse(String line) {
    final match = _pattern.firstMatch(line);
    if (match == null) return null;
    final name = match.group(1)!.trim();
    if (name.startsWith('-')) return null;
    final description = match.group(2)!.trim();
    return _CommandEntry(name, description);
  }

  void append(String text) {
    final value = text.trim();
    if (value.isEmpty) return;
    if (_description.isNotEmpty) _description.write(' ');
    _description.write(value);
  }

  ParsedHelpCommand toCommand() {
    return ParsedHelpCommand(
      name: name,
      description: _description.toString(),
    );
  }
}

class _FlagEntry {
  _FlagEntry(this.tokens, String description, {required this.expectsValue}) {
    append(description);
  }

  final List<String> tokens;
  final bool expectsValue;
  final StringBuffer _description = StringBuffer();

  static final RegExp _pattern = RegExp(r'^\s*(-{1,2}[^\s,]+(?:\s+[^\s,]+)?(?:,\s*-{1,2}[^\s,]+(?:\s+[^\s,]+)?)*)\s{2,}(.+)$');

  static _FlagEntry? tryParse(String line) {
    final trimmed = line.trimLeft();
    final match = _pattern.firstMatch(trimmed);
    if (match == null) return null;
    final rawTokens = match.group(1)!;
    final description = match.group(2)?.trim() ?? '';
    var expectsValue = false;
    final tokens = <String>[];
    for (final fragment in rawTokens.split(',')) {
      if (_fragmentImpliesValue(fragment)) {
        expectsValue = true;
      }
      final normalized = _normalizeToken(fragment);
      if (normalized.startsWith('-') && normalized.length >= 2) {
        tokens.add(normalized);
      }
    }
    if (tokens.isEmpty) return null;
    return _FlagEntry(tokens, description, expectsValue: expectsValue);
  }

  void append(String text) {
    final value = text.trim();
    if (value.isEmpty) return;
    if (_description.isNotEmpty) _description.write(' ');
    _description.write(value);
  }

  ParsedHelpFlag toFlag() {
    final primary = tokens.firstWhere((token) => token.startsWith('--'), orElse: () => tokens.first);
    final alias = tokens.firstWhere((token) => token != primary, orElse: () => '');
    return ParsedHelpFlag(
      name: primary,
      alias: alias.isEmpty ? null : alias,
      description: _description.toString(),
      expectsValue: expectsValue,
    );
  }

  static String _normalizeToken(String token) {
    var value = token.trim();
    final spaceIndex = value.indexOf(' ');
    final eqIndex = value.indexOf('=');
    final cutIndex = [spaceIndex, eqIndex].where((index) => index >= 0).fold<int>(-1, (prev, index) {
      if (prev == -1) return index;
      if (index == -1) return prev;
      return index < prev ? index : prev;
    });
    if (cutIndex >= 0) {
      value = value.substring(0, cutIndex);
    }
    value = value.replaceAll(RegExp(r'[<\[].*'), '');
    return value.trim();
  }

  static bool _fragmentImpliesValue(String fragment) {
    final value = fragment.trim();
    return value.contains('=') || value.contains('<') || RegExp(r'\s+[A-Z\[<]').hasMatch(value);
  }
}
