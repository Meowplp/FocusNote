#!/bin/zsh
# Snapshots of every page in light and dark, with seed data, on a fresh test store.
# Usage: tools/snap.sh            all pages
#        APP_SNAPSHOT_PAGES=all,settings tools/snap.sh
#        tools/snap.sh -AppleShowScrollBars Always     see the scroll bars as people with a mouse see them
set -euo pipefail
# Use a clearly named, separate test bundle. Never reset the real app's saved
# state, open its data, or make another indistinguishable FocusNote Dock icon.
mkdir -p "${TMPDIR:-/tmp}/opencode"
work=$(mktemp -d "${TMPDIR:-/tmp}/opencode/FocusNote-preview.XXXXXX")
store="$work/preview.store"
shots="$work/shots"
preview="$work/FocusNote Preview.app"
ditto "$HOME/Applications/FocusNote.app" "$preview"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.anhpham.focusnote.preview' "$preview/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleName FocusNote Preview' "$preview/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleDisplayName FocusNote Preview' "$preview/Contents/Info.plist"
codesign --force --sign - "$preview"
# Each run has its own private database and output; never delete shared paths.
# LaunchServices gives this isolated copy foreground activation rights. Starting
# the executable directly can leave main-window captures inactive on recent macOS.
launch=(open -n -W --env "APP_STORE=$store" --env APP_SEED=1 --env "APP_SNAPSHOT=$shots")
[[ -n "${APP_SNAPSHOT_PAGES:-}" ]] && launch+=(--env "APP_SNAPSHOT_PAGES=$APP_SNAPSHOT_PAGES")
[[ -n "${APP_ACCENT:-}" ]] && launch+=(--env "APP_ACCENT=$APP_ACCENT")
[[ -n "${APP_GRID:-}" ]] && launch+=(--env "APP_GRID=$APP_GRID")
"${launch[@]}" "$preview" --args "$@"
echo "Snapshots saved to $shots"
