#!/usr/bin/env bash
# Factory gate helper: run `flutter test` inside client/ with repo-root-relative test paths.
# The factory substitutes {files}/{file} as paths from the repository root (e.g. client/test/x_test.dart);
# `flutter test` must run in the package dir, so strip the leading `client/`.
set -euo pipefail
cd "$(dirname "$0")/../client"
args=()
for a in "$@"; do args+=("${a#client/}"); done
exec flutter test "${args[@]}"
