#!/bin/zsh
# Runs the in-app self-test against a fresh store in /tmp. Exit code 0 when every check passed.
set -euo pipefail
# Isolate test identity/window restoration from the running personal app.
# A unique bundle avoids macOS restoring a hidden test window from another run.
mkdir -p "${TMPDIR:-/tmp}/opencode"
work=$(mktemp -d "${TMPDIR:-/tmp}/opencode/FocusNote-selftest.XXXXXX")
preview="$work/FocusNote Preview.app"
ditto "$HOME/Applications/FocusNote.app" "$preview"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.anhpham.focusnote.selftest.$(uuidgen)" "$preview/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleName FocusNote Preview' "$preview/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleDisplayName FocusNote Preview' "$preview/Contents/Info.plist"
codesign --force --sign - "$preview"
store="$work/self.store"
APP_STORE=$store "$preview/Contents/MacOS/FocusNote" --selftest
