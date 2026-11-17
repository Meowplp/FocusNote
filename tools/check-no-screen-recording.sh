#!/bin/zsh
# The app/test renderer must never request screen or system-audio recording.
set -euo pipefail
here=${0:A:h:h}
if grep -REn 'import ScreenCaptureKit|CGRequestScreenCaptureAccess[[:space:]]*\(|CGPreflightScreenCaptureAccess[[:space:]]*\(|CGWindowListCreateImage[[:space:]]*\(|SCStream[[:space:]]*\(|SCScreenshotManager[.]|"/usr/sbin/screencapture"' "$here/Sources"; then
  echo "FAIL: screen-recording path found"
  exit 1
fi
echo "PASS no screen-recording API or capture subprocess in app sources"
