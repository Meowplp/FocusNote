#!/bin/zsh
# Build first with ./build.sh. This probe never opens the user's normal store.
set -euo pipefail
root="${TMPDIR:-/tmp}/opencode"
mkdir -p "$root"
work=$(mktemp -d "$root/FocusNote-performance.XXXXXX")
APP_STORE="$work/probe.store" "$HOME/Applications/FocusNote.app/Contents/MacOS/FocusNote" --timer-performance
