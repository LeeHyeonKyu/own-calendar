#!/usr/bin/env bash
# Factory gate helper: route test/lint commands to the correct runner based on path prefix.
# Usage: factory-test-router.sh <mode> <file-or-files> [extra-args...]
#   mode = test_files | test_one | lint_file
# server/** paths go to scripts/factory-server-test.sh
# client/** (and everything else) goes to the Flutter helpers
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mode="$1"; shift

case "$mode" in
  test_files)
    # Split files into server and client groups, run each runner once
    server_files=()
    client_args=()
    for f in "$@"; do
      case "$f" in
        server/*) server_files+=("$f") ;;
        *) client_args+=("$f") ;;
      esac
    done
    rc=0
    if [ ${#server_files[@]} -gt 0 ]; then
      "$REPO_ROOT/scripts/factory-server-test.sh" "${server_files[@]}" || rc=$?
    fi
    if [ ${#client_args[@]} -gt 0 ]; then
      "$REPO_ROOT/scripts/factory-flutter-test.sh" "${client_args[@]}" || rc=$?
    fi
    exit $rc
    ;;

  test_one)
    # $1 = file, remaining = extra args (e.g. --plain-name <name>)
    file="$1"; shift
    case "$file" in
      server/*)
        # vitest --testNamePattern for name-based filtering
        name_args=()
        while [ $# -gt 0 ]; do
          case "$1" in
            --plain-name) shift; name_args+=("--testNamePattern" "$1") ;;
            *) name_args+=("$1") ;;
          esac
          shift
        done
        exec "$REPO_ROOT/scripts/factory-server-test.sh" "$file" "${name_args[@]}"
        ;;
      *)
        exec "$REPO_ROOT/scripts/factory-flutter-test.sh" "$file" "$@"
        ;;
    esac
    ;;

  lint_file)
    file="$1"; shift
    case "$file" in
      server/*)
        # No server-specific linter configured; exit 0 (server lint is not gated yet)
        exit 0
        ;;
      *)
        exec "$REPO_ROOT/scripts/factory-flutter-analyze.sh" "$file" "$@"
        ;;
    esac
    ;;

  *)
    echo "factory-test-router: unknown mode '$mode'" >&2
    exit 1
    ;;
esac
