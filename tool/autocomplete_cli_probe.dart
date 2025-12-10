import 'dart:io';

import 'package:hpcc_connect/services/autocomplete_service.dart';
import 'package:hpcc_connect/services/autocomplete_models.dart';

Future<void> main() async {
  await runAutocompleteProbe(onLine: stdout.writeln);
}

Future<List<String>> runAutocompleteProbe({
  List<String>? inputs,
  String? workingDirectory,
  void Function(String line)? onLine,
}) async {
  final scenarios = inputs ?? <String>[
    'verdi',
    'verdi ',
    'verdi code',
    'verdi code ',
    'verdi code l',
    'verdi code list',
    'verdi code list ',
    'verdi code list --',
    'verdi code list -',
    'verdi computer',
    'verdi computer ',
    'verdi computer list',
    'verdi computer list --',
    'pip3',
    'pip3 ',
    'pip3 in',
    'pip3 install',
    'pip3 install ',
    'pip3 install --',
    'pip3 install -',
    'pip3 uninstall',
    'pip3 uninstall ',
    'pip3 uninstall --',
    'pip3 uninstall -',
    'pip3 list',
    'pip3 list ',
    'pip3 list --',
    'pip3 list --cache-dir ',
    'pip3 list --path ',
  ];

  final buffer = <String>[];
  void emit(String line) {
    buffer.add(line);
    onLine?.call(line);
  }

  final service = AutocompleteService();
  final cwd = workingDirectory ?? Directory.current.path;

  emit('Running autocomplete probe from $cwd');
  emit('--------------------------------------------------------');

  for (final input in scenarios) {
    final autoTrigger = input.endsWith(' ');
    emit('\nInput: "$input"');
    emit('Auto trigger: $autoTrigger');

    try {
      final suggestions = await service.getSuggestions(
        input,
        cwd,
        autoTrigger: autoTrigger,
        commandRunner: _runCommand,
      );

      if (suggestions.isEmpty) {
        emit('  (no suggestions)');
        continue;
      }

      for (final suggestion in suggestions) {
        emit(
          '  - ${_labelForType(suggestion.type)} ${suggestion.text} (${suggestion.description})',
        );
      }
    } catch (e, st) {
      emit('  !! Error while resolving "$input": $e');
      emit(st.toString());
    }
  }

  return buffer;
}

Future<String> _runCommand(String command) async {
  final result = await Process.run('/bin/bash', ['-lc', command]);
  if (result.exitCode != 0) {
    stderr.writeln('Command failed: $command');
    stderr.write(result.stderr);
    return '';
  }
  return result.stdout.toString();
}

String _labelForType(SuggestionType type) {
  switch (type) {
    case SuggestionType.command:
      return '[cmd]';
    case SuggestionType.subcommand:
      return '[sub]';
    case SuggestionType.flag:
      return '[flag]';
    case SuggestionType.history:
      return '[hist]';
    case SuggestionType.directory:
      return '[dir]';
    case SuggestionType.file:
      return '[file]';
    case SuggestionType.codeFile:
      return '[code]';
    case SuggestionType.configFile:
      return '[conf]';
    case SuggestionType.document:
      return '[doc]';
    case SuggestionType.image:
      return '[img]';
    case SuggestionType.archive:
      return '[arch]';
    case SuggestionType.script:
      return '[script]';
    case SuggestionType.executable:
      return '[exe]';
  }
}
