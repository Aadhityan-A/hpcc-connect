import 'package:flutter_test/flutter_test.dart';

import 'package:hpcc_connect/services/autocomplete_service.dart';

void main() {
  group('HelpParser', () {
    const standardHelp = '''
Acme CLI helps manage compute nodes.

Usage: acme computer [OPTIONS] COMMAND [ARGS]...

Options:
  -c, --config PATH     Path to config file
  --debug               Enable debug logging
  -h, --help            Show this message and exit

Commands:
  list                  List registered computers
  show                  Show computer details
  sync-data             Synchronize remote data
''';

    const multilineHelp = '''
Subcommands:
  setup-remote          Configure remote host
                        Requires SSH credentials.
  install               Install dependencies

Flags:
  --output <PATH>       Write manifest to PATH
                        Defaults to ./manifest.json
  -f, --force           Force the operation
''';

    const pipStyleHelp = '''
Install Options:
  -r, --requirement <file>    Install from requirements file
Package Index Options:
  -i, --index-url <url>       Base URL of the Python Package Index
General Options:
  -h, --help                  Show help
''';

    test('parses commands and flags from standard help text', () {
      final doc = HelpParser.parseDocument(standardHelp);
      expect(doc.subcommands.map((c) => c.name), containsAll(['list', 'show', 'sync-data']));
      expect(doc.flags.map((f) => f.name), containsAll(['--config', '--debug', '--help']));

      final configFlag = doc.flags.firstWhere((f) => f.name == '--config');
      expect(configFlag.alias, equals('-c'));
      expect(configFlag.expectsValue, isTrue);

      final info = HelpParser.parse(standardHelp);
      expect(info.subcommands.keys, contains('list'));
      expect(info.flags, contains('-c'));
      expect(info.flags, contains('--config'));
    });

    test('captures multiline descriptions and value expectations', () {
      final doc = HelpParser.parseDocument(multilineHelp);
      final setup = doc.subcommands.firstWhere((command) => command.name == 'setup-remote');
      expect(setup.description, contains('SSH credentials'));

      final outputFlag = doc.flags.firstWhere((flag) => flag.name == '--output');
      expect(outputFlag.expectsValue, isTrue);
      expect(outputFlag.description, contains('Defaults to ./manifest.json'));

      final forceFlag = doc.flags.firstWhere((flag) => flag.name == '--force');
      expect(forceFlag.alias, equals('-f'));
    });

    test('falls back gracefully when sections are missing', () {
      const minimal = 'custom tool 1.0';
      final info = HelpParser.parse(minimal);
      expect(info.flags, isEmpty);
      expect(info.subcommands, isEmpty);
    });

    test('parses option sections with descriptive headers', () {
      final doc = HelpParser.parseDocument(pipStyleHelp);
      final flags = doc.flags.map((f) => f.name).toList();
      expect(flags, containsAll(['--requirement', '--index-url', '--help']));

      final info = HelpParser.parse(pipStyleHelp);
      expect(info.flags, contains('-r'));
      expect(info.flags, contains('--requirement'));
      expect(info.flags, contains('--index-url'));
    });
  });
}
