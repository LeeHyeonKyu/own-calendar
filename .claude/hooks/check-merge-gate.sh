#!/usr/bin/env bash
# know-thy-build merge gate — blocks git merge when feature gate is not fully passed

# Only check if the command contains git merge
if ! echo "$TOOL_INPUT" | grep -qE 'git\s+merge'; then
  exit 0
fi

# Find the active feature spec with gate
FEATURE_FILE=$(ls -t docs/features/*.md 2>/dev/null | head -1)
if [ -z "$FEATURE_FILE" ]; then
  exit 0
fi

# Check gate statuses
PENDING=$(grep -cE '^\s+(architect|designer|qa):\s*pending' "$FEATURE_FILE" 2>/dev/null || echo "0")

if [ "$PENDING" -gt 0 ]; then
  echo "❌ Merge gate blocked — pending reviews exist:"
  grep -E '^\s+(architect|designer|qa):' "$FEATURE_FILE" 2>/dev/null
  echo ""
  echo "Run /know-thy-build:finish to check gate status."
  exit 2
fi

exit 0
