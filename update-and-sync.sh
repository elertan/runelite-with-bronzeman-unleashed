#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPDATE_SCRIPT="$SCRIPT_DIR/update-runelite-tag.sh"
SYNC_SCRIPT="$SCRIPT_DIR/sync-bronzeman.sh"

usage() {
	cat <<'EOF'
Run RuneLite tag update and Bronzeman sync in one command.

Usage:
  ./update-and-sync.sh [update-options]

Behavior:
  1) Runs update-runelite-tag.sh with --into-current-branch by default
  2) If successful, runs sync-bronzeman.sh

Any provided arguments are forwarded to update-runelite-tag.sh.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	usage
	exit 0
fi

[[ -x "$UPDATE_SCRIPT" ]] || { echo "ERROR: Missing or non-executable: $UPDATE_SCRIPT" >&2; exit 1; }
[[ -x "$SYNC_SCRIPT" ]] || { echo "ERROR: Missing or non-executable: $SYNC_SCRIPT" >&2; exit 1; }

"$UPDATE_SCRIPT" --into-current-branch "$@"
"$SYNC_SCRIPT"
