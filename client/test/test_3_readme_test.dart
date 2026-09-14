// Guard test for issue #3 — the root README.md is the only entry point a new
// contributor has, and nothing else in the repository gates it. These tests
// read the README as data and assert the properties the issue contracted:
// the five sections exist, the commands they publish actually resolve, the
// `.env` prerequisite points at docs/TECHNICAL.md without leaking variable
// names, and `## Test` warns that the server suite is destructive.
//
// Every assertion here reads files only — no clock, no network, no ordering
// between tests — so the suite is deterministic under parallel repeats.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Walks up from the current directory until it finds the monorepo root
/// (the directory holding both `client/pubspec.yaml` and `server/package.json`).
///
/// Resolving this way instead of hard-coding `../` keeps the guard working
/// whether it is run as `cd client && flutter test` (the required unit gate)
/// or as `flutter test client/test/...` from the repository root.
Directory _repoRoot() {
  var dir = Directory.current.absolute;
  while (true) {
    final hasClient = File('${dir.path}/client/pubspec.yaml').existsSync();
    final hasServer = File('${dir.path}/server/package.json').existsSync();
    if (hasClient && hasServer) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      fail(
        'Could not locate the monorepo root (a directory containing both '
        'client/pubspec.yaml and server/package.json) walking up from '
        '${Directory.current.absolute.path}',
      );
    }
    dir = parent;
  }
}

File _readmeFile() => File('${_repoRoot().path}/README.md');

String _readme() {
  final file = _readmeFile();
  if (!file.existsSync()) {
    fail(
      'Expected a root README.md at ${file.path} documenting how to run and '
      'test the client and the server (issue #3), but the file does not exist.',
    );
  }
  return file.readAsStringSync();
}

/// Splits the README into `## `-level sections, keyed by heading text.
///
/// `###` sub-headings stay inside the body of their parent section.
Map<String, List<String>> _sections(String markdown) {
  final headingPattern = RegExp(r'^## +(.+?)\s*$');
  final sections = <String, List<String>>{};
  var current = '';
  sections[current] = <String>[];
  for (final line in const LineSplitter().convert(markdown)) {
    final match = headingPattern.firstMatch(line);
    if (match != null) {
      current = match.group(1)!;
      sections[current] = <String>[];
      continue;
    }
    sections[current]!.add(line);
  }
  sections.remove('');
  return sections;
}

/// The lines of [sectionLines] that sit inside a fenced code block, i.e. the
/// commands a reader can actually copy and paste.
List<String> _fencedLines(List<String> sectionLines) {
  final fenced = <String>[];
  var inFence = false;
  for (final line in sectionLines) {
    if (line.trimLeft().startsWith('```')) {
      inFence = !inFence;
      continue;
    }
    if (inFence) {
      fenced.add(line);
    }
  }
  return fenced;
}

List<String> _sectionLines(Map<String, List<String>> sections, String name) {
  final lines = sections[name];
  if (lines == null) {
    fail(
      'README.md has no `## $name` section. Present sections: '
      '${sections.keys.map((k) => '## $k').join(', ')}',
    );
  }
  return lines;
}

/// The `scripts` keys declared by server/package.json.
Set<String> _serverScripts() {
  final file = File('${_repoRoot().path}/server/package.json');
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final scripts = json['scripts'] as Map<String, dynamic>? ?? <String, dynamic>{};
  return scripts.keys.toSet();
}

void main() {
  test('test_3_readme_sections', () {
    final sections = _sections(_readme());

    for (final required in const ['What', 'Layout', 'Run', 'Test', 'Docs']) {
      expect(
        sections.keys,
        contains(required),
        reason:
            'README.md must keep the `## $required` section (issue #3). '
            'Present sections: ${sections.keys.map((k) => '## $k').join(', ')}',
      );
    }

    // `## Layout` must describe every top-level directory the issue names,
    // and each of those directories must actually exist in the repository.
    final layout = _sectionLines(sections, 'Layout').join('\n');
    final root = _repoRoot().path;
    for (final dir in const [
      'client/',
      'server/',
      'altstore/',
      'scripts/',
      'docs/',
    ]) {
      expect(
        layout,
        contains(dir),
        reason: '`## Layout` must describe the `$dir` directory.',
      );
      expect(
        Directory('$root/${dir.substring(0, dir.length - 1)}').existsSync(),
        isTrue,
        reason:
            '`## Layout` describes `$dir`, but that directory does not exist '
            'in the repository — the layout description has rotted.',
      );
    }

    // The one-paragraph `## What` must actually say something.
    final what = _sectionLines(sections, 'What').join(' ').trim();
    expect(
      what.length,
      greaterThan(40),
      reason: '`## What` must carry a one-paragraph description, not be empty.',
    );
  });

  test('test_3_readme_commands_resolve', () {
    final readme = _readme();
    final scripts = _serverScripts();

    // `npm run <script>` — the script must exist in server/package.json.
    for (final match in RegExp(r'npm run ([A-Za-z0-9:_-]+)').allMatches(readme)) {
      final script = match.group(1)!;
      expect(
        scripts,
        contains(script),
        reason:
            'README.md tells the reader to run `npm run $script`, but '
            'server/package.json declares no such script. Known scripts: '
            '${scripts.join(', ')}',
      );
    }

    // `npm test` / `npm start` are npm lifecycle aliases: they still need the
    // matching script. `npm ci` / `npm install` are npm built-ins.
    for (final alias in const ['test', 'start']) {
      if (RegExp('npm $alias(\\s|\$)').hasMatch(readme)) {
        expect(
          scripts,
          contains(alias),
          reason:
              'README.md tells the reader to run `npm $alias`, but '
              'server/package.json declares no `$alias` script.',
        );
      }
    }

    // Flutter commands the README publishes must be real flutter subcommands.
    const knownFlutterSubcommands = {
      'run',
      'test',
      'pub',
      'build',
      'analyze',
      'install',
      'clean',
      'doctor',
      'devices',
    };
    for (final match in RegExp(r'flutter ([a-z]+)').allMatches(readme)) {
      expect(
        knownFlutterSubcommands,
        contains(match.group(1)),
        reason:
            'README.md publishes `flutter ${match.group(1)}`, which is not a '
            'flutter subcommand this repository uses.',
      );
    }
  });

  test('test_3_readme_env_pointer', () {
    final readme = _readme();
    final run = _sectionLines(_sections(readme), 'Run');

    // Exactly the contract from the maintainer's 2026-09-14 triage answer:
    // ONE line that names server/.env and points at docs/TECHNICAL.md.
    final pointerLines = run
        .where((line) =>
            line.contains('server/.env') && line.contains('docs/TECHNICAL.md'))
        .toList();
    expect(
      pointerLines,
      hasLength(1),
      reason:
          '`## Run` must carry exactly one line naming `server/.env` and '
          'pointing at `docs/TECHNICAL.md` for the variable list. Found '
          '${pointerLines.length}.',
    );

    // ...and the README must NOT enumerate the variables themselves.
    const forbiddenNames = [
      'DATABASE_URL',
      'JWT_SECRET',
      'GOOGLE_CLIENT_ID',
      'GOOGLE_CLIENT_SECRET',
      'FIREBASE_',
      'POSTGRES_PASSWORD',
    ];
    for (final name in forbiddenNames) {
      expect(
        readme,
        isNot(contains(name)),
        reason:
            'README.md must not enumerate server environment variables '
            '(found `$name`) — docs/TECHNICAL.md owns that list (issue #3 '
            'non-goal).',
      );
    }
    // Generic guard: any SCREAMING_SNAKE_CASE identifier looks like an env var.
    // File names such as `docs/QA_CHECKLIST.md` are not, so a match that is
    // immediately followed by a file extension does not count.
    final fileExtension = RegExp(r'^\.[a-z]{1,4}\b');
    final envShaped = RegExp(r'\b[A-Z][A-Z0-9]*_[A-Z0-9_]+\b')
        .allMatches(readme)
        .where((m) => !fileExtension.hasMatch(readme.substring(m.end)))
        .map((m) => m.group(0))
        .toList();
    expect(
      envShaped,
      isEmpty,
      reason:
          'README.md contains environment-variable-shaped identifiers; the '
          'variable list belongs in docs/TECHNICAL.md, not here.',
    );
  });

  test('test_3_readme_server_test_warns_destructive', () {
    final testSection = _sectionLines(_sections(_readme()), 'Test');

    final commandIndex = testSection.indexWhere(
      (line) => line.contains('npm test') && line.contains('cd server'),
    );
    expect(
      commandIndex,
      greaterThanOrEqualTo(0),
      reason: '`## Test` must publish the server test command (`cd server && '
          'npm test`).',
    );

    // server/tests/setup.ts runs deleteMany() over every table in a global
    // beforeEach against whatever DATABASE_URL server/.env points at — which
    // `## Run` just told the reader to create. The reader must be warned
    // right next to the command, not in some other section.
    final dbWords = ['database', 'db', '데이터베이스'];
    final destructiveWords = [
      'delete',
      'deletes',
      'wipe',
      'wipes',
      'truncate',
      'truncates',
      'destroy',
      'destroys',
      '삭제',
      '초기화',
    ];
    var warningIndex = -1;
    for (var i = 0; i < testSection.length; i++) {
      final lower = testSection[i].toLowerCase();
      final namesDb = dbWords.any((w) => lower.contains(w));
      final namesDestruction = destructiveWords.any((w) => lower.contains(w));
      final namesEnv = testSection[i].contains('server/.env');
      if (namesDb && namesDestruction && namesEnv) {
        warningIndex = i;
        break;
      }
    }
    expect(
      warningIndex,
      greaterThanOrEqualTo(0),
      reason:
          '`## Test` must warn that `cd server && npm test` deletes every row '
          'in the database `server/.env` points at (server/tests/setup.ts '
          'truncates all tables in a global beforeEach). No line in `## Test` '
          'names server/.env, the database and the deletion together.',
    );
    expect(
      (warningIndex - commandIndex).abs(),
      lessThanOrEqualTo(6),
      reason:
          'The destructive-database warning must sit next to the server test '
          'command (within 6 lines), not elsewhere in `## Test`.',
    );
  });

  test('test_3_readme_commands_present', () {
    final sections = _sections(_readme());
    final runCommands = _fencedLines(_sectionLines(sections, 'Run'));
    final testCommands = _fencedLines(_sectionLines(sections, 'Test'));

    // A README that keeps the five headings but empties their bodies must fail
    // here: both halves of the monorepo need a copy-pastable command in each
    // of `## Run` and `## Test`.
    void expectCommand(
      List<String> commands,
      String section,
      List<String> fragments,
    ) {
      final found = commands.any(
        (line) => fragments.every((fragment) => line.contains(fragment)),
      );
      expect(
        found,
        isTrue,
        reason:
            '`## $section` must contain a copy-pastable command line with '
            '${fragments.map((f) => '`$f`').join(' + ')} inside a fenced code '
            'block. Fenced lines found: $commands',
      );
    }

    expectCommand(runCommands, 'Run', ['cd client', 'flutter run']);
    expectCommand(runCommands, 'Run', ['cd client', 'flutter pub get']);
    expectCommand(runCommands, 'Run', ['cd server', 'npm run dev']);
    expectCommand(runCommands, 'Run', ['cd server', 'npm ci']);
    expectCommand(testCommands, 'Test', ['cd client', 'flutter test']);
    expectCommand(testCommands, 'Test', ['cd server', 'npm test']);
  });
}
