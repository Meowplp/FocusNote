#!/bin/zsh
# Upgrade a synthetic pre-dashboard schema. Never uses user data or old commits.
set -euo pipefail
here=${0:A:h:h}
mkdir -p "${TMPDIR:-/tmp}/opencode"
work=$(mktemp -d "${TMPDIR:-/tmp}/opencode/FocusNote-migration.XXXXXX")
trap 'echo "Migration logs: $work"' EXIT
swiftc -parse-as-library "$here/tools/legacy-fixture.swift" -o "$work/legacy-fixture" > "$work/build.log" 2>&1
store="$work/legacy.store"
"$work/legacy-fixture" "$store" > "$work/legacy.log" 2>&1
sql='SELECT COUNT(*) FROM ZITEM; SELECT COUNT(*), COALESCE(ROUND(SUM(ZACTIVESECONDS),3),0) FROM ZFOCUSATTEMPT;'
before=$(sqlite3 "$store" "$sql")
APP_STORE="$store" APP_SNAPSHOT="$work/shots" APP_SNAPSHOT_PAGES=all \
  "$HOME/Applications/FocusNote.app/Contents/MacOS/FocusNote" > "$work/upgrade.log" 2>&1
after=$(sqlite3 "$store" "$sql")
[[ "$before" == "$after" ]] || { echo "FAIL migration: record counts or actual seconds changed"; exit 1; }
missing=$(sqlite3 "$store" "SELECT COUNT(*) FROM ZITEM WHERE ZDAYKEY IS NULL OR ZDAYKEY = '';")
[[ "$missing" == 0 ]] || { echo "FAIL migration: missing daily keys"; exit 1; }
echo "PASS synthetic legacy upgrade: item/attempt counts and active seconds unchanged; all daily keys populated"
