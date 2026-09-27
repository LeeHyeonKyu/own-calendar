// Guard test for issue #31 — docs/factory/CHARTER.md (NEVER_AUTOMATE) and
// .factory/harness.toml ([load_bearing].paths) hard-code file paths that are
// used by the factory to gate changes. If any listed file is renamed or
// removed, its protection silently drops. This test reads both files as plain
// text (never writes), extracts the hard-coded paths, and asserts each one
// resolves to an existing file or directory on disk.
//
// All extraction logic is inlined in this file (private functions) so that
// the changeset adds exactly one file: client/test/charter_paths_guard_test.dart.
//
// Follows the established pattern in client/test/test_3_readme_test.dart:
// walk up to the monorepo root, read a document as data, assert the paths
// it references still exist.
//
// Every assertion uses synchronous file reads only — no clock, no network,
// no ordering between tests, no mutable shared state — so the suite is
// deterministic under parallel repeats.
//
// prove-test note: this is a test-only diff (single test file, no
// implementation counterpart), so prove-test runs in *characterization*
// mode — the new test must PASS on main, and that is the proof. The paths
// this test guards exist identically on base and HEAD by design. The issue
// body states: "The test passes on main today (the paths exist) — that is
// the expected outcome."

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Walks up from the current directory until it finds the monorepo root
/// (the directory holding both `client/pubspec.yaml` and `server/package.json`).
Directory _repoRoot() {
  var dir = Directory.current.absolute;
  while (true) {
    final hasClient = File('${dir.path}/client/pubspec.yaml').existsSync();
    final hasServer = File('${dir.path}/server/package.json').existsSync();
    if (hasClient && hasServer) return dir;
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

/// Extracts the text of the `## NEVER_AUTOMATE` section from CHARTER.md
/// content. Returns all lines from that heading until the next `## ` heading
/// or EOF.
///
/// Throws [StateError] if no `## NEVER_AUTOMATE` section is found.
String _extractNeverAutomateSection(String charter) {
  final lines = charter.split('\n');
  final sectionStart = lines.indexWhere(
    (line) => RegExp(r'^## NEVER_AUTOMATE\b').hasMatch(line),
  );
  if (sectionStart < 0) {
    throw StateError(
      'CHARTER.md has no `## NEVER_AUTOMATE` section. Cannot extract '
      'protected paths.',
    );
  }

  final buffer = StringBuffer();
  for (var i = sectionStart + 1; i < lines.length; i++) {
    if (lines[i].startsWith('## ')) break;
    buffer.writeln(lines[i]);
  }
  return buffer.toString();
}

/// Extracts backtick-quoted file paths from the NEVER_AUTOMATE section text.
///
/// A backtick-quoted string qualifies as a file path when it:
///   1. Contains a `/` separator — excludes non-path identifiers like
///      `update-altstore` (a job name) or `main` (a branch name).
///   2. Contains no glob character (`*`) — excludes glob patterns like
///      `src/api/public/**` or `.env*` that describe categories of files
///      rather than paths resolvable on disk. The issue's non_goals explicitly
///      exclude fixing stale/aspirational paths; this heuristic keeps the test
///      passing today while still guarding every concrete file path.
List<String> _extractCharterPaths(String sectionText) {
  final backtickPattern = RegExp(r'`([^`]+)`');
  return backtickPattern
      .allMatches(sectionText)
      .map((m) => m.group(1)!)
      .where((s) => s.contains('/') && !s.contains('*'))
      .toList();
}

/// Extracts the quoted path strings from the `[load_bearing]` section's
/// `paths` array in harness.toml content.
///
/// Dart has no built-in TOML parser. The extraction uses a regex against
/// double-quoted strings within the `paths = [...]` block, anchored to the
/// `[load_bearing]` section header. This is intentionally sensitive to
/// formatting changes: a restructuring that breaks the regex causes the
/// extraction to yield zero paths, which the non-empty assertion in the
/// test catches (a vacuous pass is worse than no guard).
///
/// Throws [StateError] if no `[load_bearing]` section is found.
List<String> _extractHarnessLoadBearingPaths(String toml) {
  final lines = toml.split('\n');
  final sectionStart = lines.indexWhere(
    (line) => line.trim() == '[load_bearing]',
  );
  if (sectionStart < 0) {
    throw StateError(
      'harness.toml has no `[load_bearing]` section. Cannot extract '
      'load-bearing paths.',
    );
  }

  final arrayLines = <String>[];
  var inArray = false;
  for (var i = sectionStart + 1; i < lines.length; i++) {
    final trimmed = lines[i].trim();
    // Stop at any TOML section header: `[word...]`. This pattern matches
    // `[evidence]`, `[test.env]` etc. but NOT a bare `]` (array close) or
    // a quoted array element like `"path"`.
    if (RegExp(r'^\[\w').hasMatch(trimmed)) break;

    if (trimmed.startsWith('paths')) {
      inArray = true;
    }
    if (inArray) {
      arrayLines.add(lines[i]);
      if (trimmed == ']') break;
    }
  }

  final arrayText = arrayLines.join('\n');
  final quotedPattern = RegExp(r'"([^"]+)"');
  return quotedPattern
      .allMatches(arrayText)
      .map((m) => m.group(1)!)
      .toList();
}

/// For a glob pattern ending in `/**`, returns the directory prefix.
/// For concrete paths, returns the path unchanged.
String _resolveForCheck(String path) {
  if (path.endsWith('/**')) {
    return path.substring(0, path.length - 3);
  }
  return path;
}

/// Checks whether a resolved path exists on disk as a file or directory.
bool _pathExistsOnDisk(String repoRoot, String resolvedPath) {
  final fullPath = '$repoRoot/$resolvedPath';
  return File(fullPath).existsSync() || Directory(fullPath).existsSync();
}

void main() {
  // Pre-compute repo root once for all tests in this file. Using a local
  // variable inside main() avoids any top-level initialization order issues
  // and keeps the computation lazy (only runs when tests actually execute).
  late final String root;

  setUpAll(() {
    root = _repoRoot().path;
  });

  test('test_31_charter_paths_pass', () {
    // --- CHARTER.md NEVER_AUTOMATE paths ---
    final charterFile = File('$root/docs/factory/CHARTER.md');
    expect(
      charterFile.existsSync(),
      isTrue,
      reason: 'docs/factory/CHARTER.md must exist — it is the source of '
          'NEVER_AUTOMATE paths this test guards.',
    );
    final charterContent = charterFile.readAsStringSync();
    final neverAutomateText = _extractNeverAutomateSection(charterContent);
    final charterPaths = _extractCharterPaths(neverAutomateText);

    // Guard against vacuous pass (dw4): if the extraction regex silently
    // matches nothing due to a formatting change, the test must fail rather
    // than reporting "all zero paths exist" as success.
    expect(
      charterPaths,
      isNotEmpty,
      reason: 'Extracted zero file paths from CHARTER.md NEVER_AUTOMATE. '
          'The extraction regex may have silently broken — a vacuous pass '
          'is worse than no guard at all.',
    );

    // Guard against silent path removal: CHARTER.md NEVER_AUTOMATE currently
    // lists 6 concrete file paths. A count below this means either a protected
    // path was removed from the section (which should be investigated) or the
    // extraction heuristic was narrowed (which needs review). This number was
    // calibrated when the test was written and should be updated when paths are
    // intentionally added or removed.
    expect(
      charterPaths.length,
      greaterThanOrEqualTo(6),
      reason: 'CHARTER.md NEVER_AUTOMATE should list at least 6 concrete '
          'file paths but found ${charterPaths.length}: $charterPaths. '
          'If paths were intentionally removed, update this minimum. If not, '
          'the extraction heuristic may have broken.',
    );

    for (final path in charterPaths) {
      final resolved = _resolveForCheck(path);
      expect(
        _pathExistsOnDisk(root, resolved),
        isTrue,
        reason: 'CHARTER.md NEVER_AUTOMATE lists `$path` but it does not '
            'exist on disk at $root/$resolved — protection for this path '
            'has silently dropped.',
      );
    }

    // --- harness.toml [load_bearing].paths ---
    final harnessFile = File('$root/.factory/harness.toml');
    expect(
      harnessFile.existsSync(),
      isTrue,
      reason: '.factory/harness.toml must exist — it is the source of '
          '[load_bearing].paths this test guards.',
    );
    final harnessContent = harnessFile.readAsStringSync();
    final harnessPaths = _extractHarnessLoadBearingPaths(harnessContent);

    // Guard against vacuous pass (dw4): same protection for the second source.
    expect(
      harnessPaths,
      isNotEmpty,
      reason: 'Extracted zero paths from harness.toml [load_bearing].paths. '
          'The extraction regex may have silently broken — a vacuous pass '
          'is worse than no guard at all.',
    );

    // Guard against silent path removal: harness.toml [load_bearing].paths
    // currently lists 19 paths. Same reasoning as the charter count above.
    expect(
      harnessPaths.length,
      greaterThanOrEqualTo(19),
      reason: 'harness.toml [load_bearing].paths should list at least 19 '
          'paths but found ${harnessPaths.length}: $harnessPaths. '
          'If paths were intentionally removed, update this minimum. If not, '
          'the extraction logic may have broken.',
    );

    for (final path in harnessPaths) {
      final resolved = _resolveForCheck(path);
      expect(
        _pathExistsOnDisk(root, resolved),
        isTrue,
        reason: 'harness.toml [load_bearing].paths lists `$path` but it '
            'does not exist on disk at $root/$resolved — this load-bearing '
            'path has silently dropped.',
      );
    }
  });

  test('test_31_charter_extraction_filter', () {
    // Verify the extraction logic correctly separates file paths from
    // non-path identifiers in CHARTER.md NEVER_AUTOMATE section text.
    // Uses inline fixture data so this test is independent of file I/O
    // after initial section extraction.

    // Read the real CHARTER.md and extract the NEVER_AUTOMATE section.
    final charterFile = File('$root/docs/factory/CHARTER.md');
    final charterContent = charterFile.readAsStringSync();
    final sectionText = _extractNeverAutomateSection(charterContent);
    final paths = _extractCharterPaths(sectionText);

    // The NEVER_AUTOMATE section contains backtick-quoted strings that are
    // NOT file paths: `update-altstore` (job name), `main` (branch name).
    // These must be excluded by the filter (no `/` separator).
    expect(
      paths.every((p) => p.contains('/')),
      isTrue,
      reason: 'Every extracted charter path must contain a "/" separator. '
          'Non-path identifiers (job names, branch names) should be '
          'filtered out. Extracted: $paths',
    );

    // Glob patterns (`src/api/public/**`, `.env*`) must be excluded
    // (contain `*`). They describe categories, not resolvable paths.
    expect(
      paths.every((p) => !p.contains('*')),
      isTrue,
      reason: 'Extracted charter paths must not contain glob characters. '
          'Glob patterns should be filtered out. Extracted: $paths',
    );

    // Cross-check: known concrete paths from NEVER_AUTOMATE must be present.
    // These are the paths this guard exists to protect. If any is missing
    // from the extraction, the guard has a hole.
    const expectedPaths = [
      'server/src/services/auth.service.ts',
      'server/src/routes/google.ts',
      'server/src/routes/naver.ts',
      'client/lib/services/api_service.dart',
      'scripts/deploy.sh',
    ];
    for (final expected in expectedPaths) {
      expect(
        paths,
        contains(expected),
        reason: 'CHARTER.md NEVER_AUTOMATE must protect `$expected` but the '
            'extraction did not find it. Extracted paths: $paths',
      );
    }

    // Similarly verify the harness [load_bearing] extraction.
    final harnessFile = File('$root/.factory/harness.toml');
    final harnessContent = harnessFile.readAsStringSync();
    final harnessPaths = _extractHarnessLoadBearingPaths(harnessContent);

    // Cross-check: known critical load-bearing paths must be present.
    const expectedHarnessPaths = [
      'server/prisma/schema.prisma',
      'server/src/services/auth.service.ts',
      'client/lib/services/api_service.dart',
      'scripts/deploy.sh',
    ];
    for (final expected in expectedHarnessPaths) {
      expect(
        harnessPaths,
        contains(expected),
        reason: 'harness.toml [load_bearing].paths must include `$expected` '
            'but the extraction did not find it. Extracted paths: '
            '$harnessPaths',
      );
    }
  });

  // ---------------------------------------------------------------------------
  // spec1 rework: Structurally exercise the harness.toml extraction machinery.
  //
  // spec-conformance spec1 identified that every piece of failure-injection
  // evidence for dw2 and dw4 exercised only the CHARTER.md side. The tests
  // below call the private extraction functions directly with fabricated TOML
  // input to prove the harness-side StateError guard (dw4), empty-path guard
  // (dw4), and correct extraction/section-stop logic all work independently
  // of CHARTER.md assertions.
  // ---------------------------------------------------------------------------

  test('test_31_harness_extraction_guards', () {
    // 1. Missing [load_bearing] section -> StateError (dw4 harness-side).
    //    If the section heading is renamed or removed, the extraction must
    //    throw rather than silently returning an empty list.
    const noSection = '[project]\nname = "test"\n';
    expect(
      () => _extractHarnessLoadBearingPaths(noSection),
      throwsStateError,
      reason: 'Missing [load_bearing] section must throw StateError, '
          'not silently yield zero paths (dw4 harness-side guard).',
    );

    // 2. Section exists but paths array is empty -> empty list.
    //    Combined with the isNotEmpty guard in test_31_charter_paths_pass,
    //    this exercises the vacuous-pass protection for the harness side.
    const emptyPaths = '[load_bearing]\npaths = []\n';
    expect(
      _extractHarnessLoadBearingPaths(emptyPaths),
      isEmpty,
      reason: 'Empty paths array must yield an empty list, which the '
          'isNotEmpty guard in the main test then catches.',
    );

    // 3. Section exists but quoted-string regex matches nothing -> empty list.
    //    This simulates a formatting change that breaks the regex.
    const noPaths = '[load_bearing]\n# only comments\npaths = [\n]\n';
    expect(
      _extractHarnessLoadBearingPaths(noPaths),
      isEmpty,
      reason: 'Paths array with no quoted strings must yield an empty list.',
    );

    // 4. Valid section with paths, followed by another TOML section ->
    //    correct extraction and section stop.
    const validToml = '[load_bearing]\n'
        '# Irreversible paths\n'
        'paths = [\n'
        '  "server/prisma/schema.prisma",\n'
        '  "scripts/deploy.sh",\n'
        ']\n'
        '\n'
        '[evidence]\n'
        'qa_artifacts = ".factory/out/qa/**"\n';
    final extracted = _extractHarnessLoadBearingPaths(validToml);
    expect(
      extracted,
      equals(['server/prisma/schema.prisma', 'scripts/deploy.sh']),
      reason: 'Must extract exactly the quoted strings from the paths array '
          'and stop at the next section header [evidence].',
    );

    // 5. Verify the real harness.toml produces harness-only paths.
    //    This confirms the extraction function operates correctly on the
    //    actual file, not just fabricated input.
    final harnessFile = File('$root/.factory/harness.toml');
    final realPaths = _extractHarnessLoadBearingPaths(
      harnessFile.readAsStringSync(),
    );
    expect(
      realPaths,
      isNotEmpty,
      reason: 'Real harness.toml [load_bearing].paths must be non-empty.',
    );
    // auth_provider.dart is in harness.toml [load_bearing].paths but NOT in
    // CHARTER.md NEVER_AUTOMATE — a true harness-only path.
    expect(
      realPaths,
      contains('client/lib/providers/auth_provider.dart'),
      reason: 'harness.toml must include client/lib/providers/auth_provider.dart '
          '— a harness-only path not in CHARTER.md NEVER_AUTOMATE.',
    );
    // google-sync is another harness-only path.
    expect(
      realPaths,
      contains('server/src/services/google-sync.service.ts'),
      reason: 'harness.toml must include google-sync.service.ts '
          '— a harness-only path not in CHARTER.md NEVER_AUTOMATE.',
    );
  });

  test('test_31_charter_extraction_state_error', () {
    // Symmetry test: verify the CHARTER-side StateError guard also fires.
    // While the CHARTER side was already observed to work in dw4-1.log,
    // this exercises the function in isolation with fabricated input.
    const noSection = '# CHARTER\n\n## Definition of Done\nSome content.\n';
    expect(
      () => _extractNeverAutomateSection(noSection),
      throwsStateError,
      reason: 'Missing ## NEVER_AUTOMATE section must throw StateError.',
    );

    // Verify correct extraction stops at the next ## heading.
    const withSection = '## NEVER_AUTOMATE\n'
        '- `server/src/services/auth.service.ts` is protected\n'
        '- `main` is the branch\n'
        '\n'
        '## Definition of Done\n'
        'Not part of NEVER_AUTOMATE.\n';
    final section = _extractNeverAutomateSection(withSection);
    expect(section, isNot(contains('Definition of Done')),
        reason: 'Extraction must stop at the next ## heading.');
    final paths = _extractCharterPaths(section);
    expect(paths, equals(['server/src/services/auth.service.ts']),
        reason: 'Must extract the path with / and exclude `main` (no /).');
  });
}
