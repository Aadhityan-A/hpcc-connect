import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:hpcc_connect/services/autocomplete_models.dart';
import 'package:hpcc_connect/services/autocomplete_service.dart';

void main() {
  const fooHelp = '''
Usage: foo [OPTIONS] COMMAND [ARGS]...

Commands:
  install  Install components
''';

  const fooInstallHelp = '''
Options:
  -s, --short-flag <value>  Example short flag
  -f, --force               Force the operation
  --long-only               Long-only flag
  -p, --path <path>         Destination path
''';

  Future<String> fakeRunner(String command) async {
    if (command == 'foo --help') {
      return fooHelp;
    }
    if (command == 'foo install --help') {
      return fooInstallHelp;
    }
    return '';
  }

  test('single dash prioritizes short flags', () async {
    final service = AutocompleteService();

    final suggestions = await service.getSuggestions(
      'foo install -',
      '/',
      commandRunner: fakeRunner,
    );

    expect(suggestions, isNotEmpty);
    expect(suggestions.first.text.startsWith('--'), isFalse,
        reason: 'Short aliases should be offered before long forms.');
    expect(suggestions.map((s) => s.text), contains('-s'));
    expect(suggestions.map((s) => s.text), contains('-f'));
  });

  test('double dash prioritizes long flags', () async {
    final service = AutocompleteService();

    final suggestions = await service.getSuggestions(
      'foo install --',
      '/',
      commandRunner: fakeRunner,
    );

    expect(suggestions, isNotEmpty);
    expect(suggestions.first.text.startsWith('--'), isTrue,
        reason: 'Long form prefix should lift long options to the top.');
    expect(suggestions.map((s) => s.text), contains('--short-flag'));
    expect(suggestions.map((s) => s.text), contains('--long-only'));
  });

  test('flag requiring value suppresses additional flag suggestions', () async {
    final service = AutocompleteService();

    final suggestions = await service.getSuggestions(
      'foo install --short-flag ',
      Directory.systemTemp.path,
      commandRunner: fakeRunner,
      autoTrigger: true,
    );

    expect(
      suggestions.where((s) => s.type == SuggestionType.flag),
      isEmpty,
      reason: 'After inserting a value-taking flag we should prompt for the value, not more flags.',
    );
  });

  test('path-like flags surface directory suggestions', () async {
    final tempDir = Directory.systemTemp.createTempSync('autocomplete_test_');
    try {
      Directory('${tempDir.path}/alpha').createSync();
      final service = AutocompleteService();

      final suggestions = await service.getSuggestions(
        'foo install --path ',
        tempDir.path,
        commandRunner: fakeRunner,
        autoTrigger: true,
      );

      expect(
        suggestions.any((s) => s.type == SuggestionType.directory),
        isTrue,
        reason: 'Path-like flags should reuse the file-system completion engine.',
      );
    } finally {
      tempDir.delete(recursive: true);
    }
  });
}
