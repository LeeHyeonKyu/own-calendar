// Guard test for issue #31 — docs/factory/CHARTER.md (NEVER_AUTOMATE) and
// .factory/harness.toml ([load_bearing].paths) hard-code file paths that are
// used by the factory to gate changes. If any listed file is renamed or
// removed, its protection silently drops. This test reads both files as plain
// text (never writes), extracts the hard-coded paths, and asserts each one
// resolves to an existing file or directory on disk.
//
// Follows the established pattern in client/test/test_3_readme_test.dart:
// walk up to the monorepo root, read a document as data, assert the paths
// it references still exist.
//
// Every assertion reads files only — no clock, no network, no ordering
// between tests — so the suite is deterministic under parallel repeats.

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

/// Extracts the text of the `## NEVER_AUTOMATE` section from CHARTER.md.
/// Returns all lines from that heading until the next `## ` heading or EOF.
String _neverAutomateSection(String charter) {
  final lines = charter.split('\n');
  final sectionStart = lines.indexWhere(
    (line) => RegExp(r'^## NEVER_AUTOMATE\b').hasMatch(line),
  );
  if (sectionStart < 0) {
    fail(
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
List<String> _charterNeverAutomatePaths(String sectionText) {
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
/// extraction to yield zero paths, which the non-empty assertion catches
/// (a vacuous pass is worse than no guard).
List<String> _harnessLoadBearingPaths(String toml) {
  final lines = toml.split('\n');
  final sectionStart = lines.indexWhere(
    (line) => line.trim() == '[load_bearing]',
  );
  if (sectionStart < 0) {
    fail(
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
bool _existsOnDisk(String repoRoot, String resolvedPath) {
  final fullPath = '$repoRoot/$resolvedPath';
  return File(fullPath).existsSync() || Directory(fullPath).existsSync();
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
    final neverAutomateText = _neverAutomateSection(charterContent);
    final charterPaths = _charterNeverAutomatePaths(neverAutomateText);

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
      final resolved = _resolveForCheck(path);
      expect(
        _existsOnDisk(root, resolved),
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
    final harnessPaths = _harnessLoadBearingPaths(harnessContent);

    // Guard against vacuous pass (dw4): same protection for the second source.
    expect(
      harnessPaths,
      isNotEmpty,
      reason: 'Extracted zero paths from harness.toml [load_bearing].paths. '
          'The extraction regex may have silently broken — a vacuous pass '
          'is worse than no guard at all.',
    );

    for (final path in harnessPaths) {
      final resolved = _resolveForCheck(path);
      expect(
        _existsOnDisk(root, resolved),
        isTrue,
        reason: 'harness.toml [load_bearing].paths lists `$path` but it '
            'does not exist on disk at $root/$resolved — this load-bearing '
            'path has silently dropped.',
      );
    }
  });
}
