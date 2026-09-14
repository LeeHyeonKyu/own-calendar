#!/usr/bin/env bash
# Factory gate helper: run `flutter analyze` inside client/ with repo-root-relative paths.
# The factory substitutes {file} as a path from the repository root (e.g. client/lib/x.dart);
# `flutter analyze` must run in the package dir, so strip the leading `client/` (same as factory-flutter-test.sh).
# Found by the first `factory rehearse` (1.3.0): `cd client && flutter analyze {file}` produced client/client/lib/…
set -euo pipefail
cd "$(dirname "$0")/../client"
args=()
for a in "$@"; do args+=("${a#client/}"); done
exec flutter analyze --no-fatal-infos "${args[@]}"
