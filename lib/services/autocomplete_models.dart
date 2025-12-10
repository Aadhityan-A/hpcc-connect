/// Shared models used by the Autocomplete service and terminal UI.
class CommandInfo {
  final String description;
  final List<String> flags;
  final Map<String, String> subcommands;
  final ArgType argType;
  final Map<String, FlagMetadata> flagMetadata;

  const CommandInfo({
    this.description = '',
    this.flags = const [],
    this.subcommands = const {},
    this.argType = ArgType.none,
    this.flagMetadata = const {},
  });

  factory CommandInfo.fromParsedHelp(ParsedHelpDocument doc) {
    final commandMap = <String, String>{
      for (final command in doc.subcommands) command.name: command.description,
    };

    final flagList = <String>[];
    final metadata = <String, FlagMetadata>{};
    for (final flag in doc.flags) {
      final entry = FlagMetadata(
        primary: flag.name,
        displayName: flag.name,
        description: flag.description,
        expectsValue: flag.expectsValue,
      );
      if (flag.name.isNotEmpty) {
        flagList.add(flag.name);
        metadata[flag.name] = entry;
      }
      if (flag.alias != null && flag.alias!.isNotEmpty) {
        flagList.add(flag.alias!);
        metadata[flag.alias!] = entry.copyWith(displayName: flag.alias!);
      }
    }

    return CommandInfo(
      description: doc.description ?? 'Dynamically parsed command',
      flags: flagList,
      subcommands: commandMap,
      flagMetadata: metadata,
    );
  }
}

/// Argument type for commands.
enum ArgType { none, file, directory, path }

/// Represents a command history entry.
class CommandHistoryEntry {
  final String command;
  final DateTime timestamp;
  final String? directory;
  final int? exitCode;

  CommandHistoryEntry({
    required this.command,
    required this.timestamp,
    this.directory,
    this.exitCode,
  });

  bool get succeeded => exitCode == null || exitCode == 0;
}

/// Suggestion categories rendered in the UI.
enum SuggestionType {
  command,
  subcommand,
  flag,
  history,
  directory,
  file,
  codeFile,
  configFile,
  document,
  image,
  archive,
  script,
  executable,
}

/// Represents an autocomplete suggestion entry.
class AutocompleteSuggestion {
  final String text;
  final String displayText;
  final String description;
  final SuggestionType type;
  final bool isDirectory;
  final String? fullPath;
  final String sortKey;
  final bool requiresValue;

  AutocompleteSuggestion({
    required this.text,
    required this.displayText,
    this.description = '',
    this.type = SuggestionType.file,
    this.isDirectory = false,
    this.fullPath,
    String? sortKey,
    this.requiresValue = false,
  }) : sortKey = sortKey ?? text;

  bool get isCommand => type == SuggestionType.command ||
      type == SuggestionType.subcommand ||
      type == SuggestionType.history;
}

/// Metadata for a parsed flag.
class FlagMetadata {
  final String primary;
  final String displayName;
  final String description;
  final bool expectsValue;

  const FlagMetadata({
    required this.primary,
    required this.displayName,
    this.description = '',
    this.expectsValue = false,
  });

  FlagMetadata copyWith({String? displayName}) {
    return FlagMetadata(
      primary: primary,
      displayName: displayName ?? this.displayName,
      description: description,
      expectsValue: expectsValue,
    );
  }
}

/// Quick fix suggestion for command errors.
class QuickFixSuggestion {
  final String title;
  final String command;
  final String description;

  QuickFixSuggestion({
    required this.title,
    required this.command,
    required this.description,
  });
}

/// Parsed representation of a help document.
class ParsedHelpDocument {
  final String? description;
  final List<ParsedHelpCommand> subcommands;
  final List<ParsedHelpFlag> flags;

  const ParsedHelpDocument({
    this.description,
    this.subcommands = const [],
    this.flags = const [],
  });

  bool get hasContent => subcommands.isNotEmpty || flags.isNotEmpty;
}

/// Represents a parsed subcommand entry.
class ParsedHelpCommand {
  final String name;
  final String description;

  const ParsedHelpCommand({
    required this.name,
    this.description = '',
  });
}

/// Represents a parsed flag/option entry.
class ParsedHelpFlag {
  final String name;
  final String? alias;
  final String description;
  final bool expectsValue;

  const ParsedHelpFlag({
    required this.name,
    this.alias,
    this.description = '',
    this.expectsValue = false,
  });
}
