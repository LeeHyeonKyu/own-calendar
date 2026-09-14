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

/// The `scripts` map declared by server/package.json, name -> command line.
Map<String, String> _serverScriptCommands() {
  final file = File('${_repoRoot().path}/server/package.json');
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final scripts = json['scripts'] as Map<String, dynamic>? ?? <String, dynamic>{};
  return scripts.map((key, value) => MapEntry(key, '$value'));
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

    // Flutter commands the README *publishes* (i.e. inside a fenced code block,
    // the lines a reader copies and pastes) must be real flutter subcommands.
    // Prose that merely mentions a flutter subcommand is not a published
    // command and must not red the unit gate.
    final fenced = _fencedLines(const LineSplitter().convert(readme)).join('\n');
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
    for (final match in RegExp(r'flutter ([a-z]+)').allMatches(fenced)) {
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

    // The pointer must lead somewhere a reader can actually get the variable
    // names from. docs/TECHNICAL.md is prose about the stack and carries no
    // variable list; the tracked `server/.env.example` is the file that does
    // ("copy to .env and fill in values"), so `## Run` must name it and the
    // file must exist. Naming the file is not enumerating the variables, so
    // the issue's non-goal is untouched.
    final exampleLines =
        run.where((line) => line.contains('server/.env.example')).toList();
    expect(
      exampleLines,
      isNotEmpty,
      reason:
          '`## Run` tells the reader to create `server/.env` but never names '
          '`server/.env.example`, the tracked file that lists the variables to '
          'fill in — a reader following `## Run` cannot start the server.',
    );
    expect(
      File('${_repoRoot().path}/server/.env.example').existsSync(),
      isTrue,
      reason:
          '`## Run` points the reader at `server/.env.example`, but that file '
          'does not exist in the repository — the pointer has rotted.',
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
    // immediately followed by a file extension does not count — nor does a
    // markdown link label (`[QA_CHECKLIST](docs/QA_CHECKLIST.md)`), which is a
    // document pointer rather than a variable. The explicit forbidden list
    // above still covers real variable names written in either position.
    final notAVariable = RegExp(r'^(\.[a-z]{1,4}\b|\]\()');
    final envShaped = RegExp(r'\b[A-Z][A-Z0-9]*_[A-Z0-9_]+\b')
        .allMatches(readme)
        .where((m) => !notAVariable.hasMatch(readme.substring(m.end)))
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

    // server/tests/setup.ts runs deleteMany() over the user/family/calendar/
    // event/token tables in a global beforeEach against whatever database
    // server/.env points at — which `## Run` just told the reader to create.
    //
    // This is the only assertion in this change that stands between a reader
    // and irreversible data loss, so it has to be fail-closed: a warning that
    // merely mentions "db" and "setup" in the same breath must NOT satisfy it.
    // Each signal below therefore carries meaning that a benign setup sentence
    // cannot accidentally supply, and the tokens are word-bounded so that
    // `db:migrate` or `backup-db.sh` do not stand in for "your database".
    //
    // The warning must sit next to the command (within 6 lines), not in some
    // other corner of `## Test`.
    const proximity = 6;
    final window = <String>[];
    for (var i = 0; i < testSection.length; i++) {
      if ((i - commandIndex).abs() <= proximity) window.add(testSection[i]);
    }

    // (a) WHICH database is at risk — the one `server/.env` points at.
    final dbToken = RegExp(
      r'(\bdatabases?\b|\bdbs?\b|\bpostgres(ql)?\b|데이터베이스)',
      caseSensitive: false,
    );
    expect(
      window.any(
        (line) => line.contains('server/.env') && dbToken.hasMatch(line),
      ),
      isTrue,
      reason:
          'The warning next to `cd server && npm test` must say WHICH database '
          'is at risk — the one `server/.env` points at. No line within '
          '$proximity lines of the command names `server/.env` together with '
          'the database.',
    );

    // (b) WHAT happens — deletion, and of everything, on the same line. A
    // neutral verb ("초기화한다", "set up") or a bare verb without the scope
    // does not warn anybody: both halves must be in one sentence.
    final destructionToken = RegExp(
      r'(\bdeletes?\b|\bdeleted\b|\bwipes?\b|\btruncates?\b|\bdestroys?\b'
      r'|\berases?\b|삭제|지운다|지웁니다|날린다)',
      caseSensitive: false,
    );
    final scopeToken = RegExp(
      r'(every row|all rows|all the rows|all data|모든 행|전체 행|모든 데이터)',
      caseSensitive: false,
    );
    expect(
      window.any(
        (line) =>
            destructionToken.hasMatch(line) && scopeToken.hasMatch(line),
      ),
      isTrue,
      reason:
          'The warning must say that running the server suite DELETES EVERY '
          'ROW (server/tests/setup.ts calls deleteMany() on the user, family, '
          'calendar, event and token tables in a global beforeEach) — one line '
          'within $proximity lines of the command must carry both the deletion '
          'and its scope. A sentence that only says the database is "set up" '
          'or "initialised" warns nobody.',
    );

    // (c) THAT IT CANNOT BE UNDONE — the property that makes this the one
    // irreversible consequence of an otherwise revertible docs change.
    final irreversibleToken = RegExp(
      r'(irreversible|cannot be (undone|recovered|reverted)'
      r'|되돌릴 수 없|복구할 수 없|복구되지 않)',
      caseSensitive: false,
    );
    expect(
      window.any(irreversibleToken.hasMatch),
      isTrue,
      reason:
          'The warning must say the deletion cannot be undone. Without that, a '
          'reader weighs it as a normal setup step.',
    );

    // (d) WHAT TO DO INSTEAD — point the suite at a throwaway database, which
    // is the action dw4 exists to make the reader take before they run it.
    final throwawayToken = RegExp(
      r'(throwaway|disposable|scratch|dedicated test|전용 테스트|버려도|일회용)',
      caseSensitive: false,
    );
    expect(
      window.any(throwawayToken.hasMatch),
      isTrue,
      reason:
          'The warning must tell the reader to point `server/.env` at a '
          'throwaway/dedicated test database before running the server suite.',
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

  test('test_3_readme_client_run_targets_local_server', () {
    final run = _sectionLines(_sections(_readme()), 'Run');
    final runCommands = _fencedLines(run);

    final clientRun = runCommands.firstWhere(
      (line) => line.contains('flutter run'),
      orElse: () => fail(
        '`## Run` must publish a `flutter run` command inside a fenced code '
        'block. Fenced lines found: $runCommands',
      ),
    );

    // The client compiles its backend address in at build time
    // (client/lib/services/api_service.dart reads it from the environment and
    // falls back to the deployed server), so a bare `flutter run` talks to the
    // deployed API — NOT to the server `## Run` tells the reader to start three
    // lines below. The repository's mechanism for choosing is
    // `--dart-define-from-file=<config>`; the README must publish it.
    final defineFromFile =
        RegExp(r'--dart-define-from-file=([^\s&|]+)').firstMatch(clientRun);
    expect(
      defineFromFile,
      isNotNull,
      reason:
          '`## Run` publishes `$clientRun`, which builds the client against '
          'its compiled-in default backend — the deployed server — while the '
          'local server the very next command starts sits idle. The published '
          'client command must select a build config with '
          '`--dart-define-from-file=<config>`.',
    );

    // The config it names must exist, resolved the way the reader resolves it:
    // relative to the `cd client` the same line performs.
    final configPath = defineFromFile!.group(1)!;
    final configFile = File('${_repoRoot().path}/client/$configPath');
    expect(
      configFile.existsSync(),
      isTrue,
      reason:
          '`## Run` runs the client with `--dart-define-from-file=$configPath`, '
          'but ${configFile.path} does not exist — the reader\'s first command '
          'fails outright.',
    );

    // ...and it must point the client at the local server, not at a remote
    // one. Anything non-loopback here means following `## Run` writes to
    // somebody else's database. The port is deliberately not pinned: the
    // config and the server both default to the same one today, and pinning it
    // would red the client's unit gate for a legitimate server-side change.
    final defines =
        jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
    final urls = defines.values
        .whereType<String>()
        .where((value) => value.contains('://'))
        .toList();
    expect(
      urls,
      isNotEmpty,
      reason:
          'client/$configPath defines no backend URL, so `## Run`\'s client '
          'command does not actually redirect the client anywhere.',
    );
    const loopbackHosts = {'localhost', '127.0.0.1', '0.0.0.0', '::1', '[::1]'};
    for (final url in urls) {
      final host = Uri.parse(url).host;
      expect(
        loopbackHosts,
        contains(host),
        reason:
            '`## Run` tells the reader to run the client with '
            '`--dart-define-from-file=$configPath`, but that config points the '
            'client at `$host` instead of the local server `## Run` just told '
            'them to start. Following the README would send their registration '
            'and calendar writes to a remote database.',
      );
    }
  });

  test('test_3_readme_server_run_bootstraps_schema', () {
    final sections = _sections(_readme());
    final runCommands = _fencedLines(_sectionLines(sections, 'Run'));

    final serverRun = runCommands.firstWhere(
      (line) => line.contains('cd server') && line.contains('npm run dev'),
      orElse: () => fail(
        '`## Run` must publish a `cd server && … npm run dev` command inside a '
        'fenced code block. Fenced lines found: $runCommands',
      ),
    );

    // On a fresh clone the database is empty and the Prisma client is not
    // generated (server/.gitignore ignores the generated output), so starting
    // the server without those two steps yields a process that listens and
    // then fails every request with "table does not exist". Which scripts do
    // them is read out of server/package.json rather than hard-coded here, so
    // renaming a script reds this guard instead of silently rotting the README.
    final scriptCommands = _serverScriptCommands();
    List<String> scriptsMatching(RegExp pattern) => scriptCommands.entries
        .where((entry) => pattern.hasMatch(entry.value))
        .map((entry) => entry.key)
        .toList();

    final migrateScripts = scriptsMatching(RegExp(r'prisma\s+migrate'));
    final generateScripts = scriptsMatching(RegExp(r'prisma\s+generate'));
    expect(
      migrateScripts,
      isNotEmpty,
      reason:
          'server/package.json declares no script running `prisma migrate`, so '
          'this guard cannot check the README against it — the schema '
          'bootstrap moved and the README must be revisited.',
    );
    expect(
      generateScripts,
      isNotEmpty,
      reason:
          'server/package.json declares no script running `prisma generate`, '
          'so this guard cannot check the README against it — the client '
          'generation step moved and the README must be revisited.',
    );

    int indexOfAnyScript(String line, List<String> scripts) {
      var found = -1;
      for (final script in scripts) {
        final at = line.indexOf('npm run $script');
        if (at >= 0 && (found < 0 || at < found)) found = at;
      }
      return found;
    }

    final migrateAt = indexOfAnyScript(serverRun, migrateScripts);
    expect(
      migrateAt,
      greaterThanOrEqualTo(0),
      reason:
          '`## Run` publishes `$serverRun`, which never applies the migrations '
          'in server/prisma/migrations — the server starts against a schema-'
          'less database and every request fails. Name one of '
          '${migrateScripts.map((s) => '`npm run $s`').join(' / ')}.',
    );
    final generateAt = indexOfAnyScript(serverRun, generateScripts);
    expect(
      generateAt,
      greaterThanOrEqualTo(0),
      reason:
          '`## Run` publishes `$serverRun`, which never generates the Prisma '
          'client that server/src imports. Name one of '
          '${generateScripts.map((s) => '`npm run $s`').join(' / ')}.',
    );

    final devAt = serverRun.indexOf('npm run dev');
    expect(
      migrateAt < devAt && generateAt < devAt,
      isTrue,
      reason:
          'The schema bootstrap must run BEFORE `npm run dev` in '
          '`$serverRun` — a migration started after the server is watching '
          'does not help the requests it is already failing.',
    );

    // The server suite is in the same boat: server/tests/setup.ts truncates
    // tables that only exist once the migrations have been applied, so `##
    // Test` must name the bootstrap too rather than leaving the reader to
    // discover it from a Prisma error code.
    final testSection = _sectionLines(sections, 'Test').join('\n');
    expect(
      migrateScripts.any((s) => testSection.contains('npm run $s')),
      isTrue,
      reason:
          '`## Test` publishes the server suite but never tells the reader to '
          'apply the migrations to the throwaway database first; '
          'server/tests/setup.ts deletes rows from tables that do not exist '
          'yet, so the suite fails before it can run a single test. Name one '
          'of ${migrateScripts.map((s) => '`npm run $s`').join(' / ')}.',
    );
  });
}
