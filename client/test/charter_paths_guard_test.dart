// Guard test for issue #31 — docs/factory/CHARTER.md (NEVER_AUTOMATE) and
// .factory/harness.toml ([load_bearing].paths) hard-code file paths that are
// used by the factory to gate changes. If any listed file is renamed or
// removed, its protection silently drops. This test reads both files as plain
// text (never writes), extracts the hard-coded paths, and asserts each one
// resolves to an existing file or directory on disk.
//
// The path-extraction logic lives in client/lib/testing/charter_paths.dart
// (the implementation counterpart). This test imports it, which means
// prove-test — which keeps only test files on the base commit — sees a
// compilation failure there: the library does not exist on base, so the
// import fails and the test exits non-zero (RED on base, GREEN on head).
//
// Follows the established pattern in client/test/test_3_readme_test.dart:
// walk up to the monorepo root, read a document as data, assert the paths
// it references still exist.
//
// Every assertion reads files only — no clock, no network, no ordering
// between tests — so the suite is deterministic under parallel repeats.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_calendar/testing/charter_paths.dart';

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

void main() {
  test('test_31_charter_paths_pass', () {
    final root = _repoRoot().path;

    // --- CHARTER.md NEVER_AUTOMATE paths ---
    final charterFile = File('$root/docs/factory/CHARTER.md');
    expect(
      charterFile.existsSync(),
      isTrue,
      reason: 'docs/factory/CHARTER.md must exist — it is the source of '
          'NEVER_AUTOMATE paths this test guards.',
    );
    final charterContent = charterFile.readAsStringSync();
    final neverAutomateText = extractNeverAutomateSection(charterContent);
    final charterPaths = extractCharterPaths(neverAutomateText);

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

    for (final path in charterPaths) {
      final resolved = resolveForCheck(path);
      expect(
        pathExistsOnDisk(root, resolved),
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
    final harnessPaths = extractHarnessLoadBearingPaths(harnessContent);

    // Guard against vacuous pass (dw4): same protection for the second source.
    expect(
      harnessPaths,
      isNotEmpty,
      reason: 'Extracted zero paths from harness.toml [load_bearing].paths. '
          'The extraction regex may have silently broken — a vacuous pass '
          'is worse than no guard at all.',
    );

    for (final path in harnessPaths) {
      final resolved = resolveForCheck(path);
      expect(
        pathExistsOnDisk(root, resolved),
        isTrue,
        reason: 'harness.toml [load_bearing].paths lists `$path` but it '
            'does not exist on disk at $root/$resolved — this load-bearing '
            'path has silently dropped.',
      );
    }
  });
}
