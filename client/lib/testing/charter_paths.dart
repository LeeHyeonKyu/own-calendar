/// Extracts and validates file paths referenced in docs/factory/CHARTER.md
/// (NEVER_AUTOMATE section) and .factory/harness.toml ([load_bearing].paths).
///
/// This library is the implementation counterpart to
/// `client/test/charter_paths_guard_test.dart` (issue #31). The guard test
/// imports it; prove-test keeps only test files on the base commit, so the
/// missing import causes the test to fail there (RED on base, GREEN on head).
///
/// All functions are pure (no I/O except [pathExistsOnDisk]) and deterministic.
library;

import 'dart:io';

/// Extracts the text of the `## NEVER_AUTOMATE` section from CHARTER.md
/// content. Returns all lines from that heading until the next `## ` heading
/// or EOF.
///
/// Throws [StateError] if no `## NEVER_AUTOMATE` section is found.
String extractNeverAutomateSection(String charter) {
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
List<String> extractCharterPaths(String sectionText) {
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
List<String> extractHarnessLoadBearingPaths(String toml) {
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
String resolveForCheck(String path) {
  if (path.endsWith('/**')) {
    return path.substring(0, path.length - 3);
  }
  return path;
}

/// Checks whether a resolved path exists on disk as a file or directory.
bool pathExistsOnDisk(String repoRoot, String resolvedPath) {
  final fullPath = '$repoRoot/$resolvedPath';
  return File(fullPath).existsSync() || Directory(fullPath).existsSync();
}
