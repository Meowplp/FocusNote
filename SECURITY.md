# Security

FocusNote is an early beta, with no independent security assessment.
No supported security-update schedule is promised yet.

Please do not post secrets, personal task databases, or private screenshots in
public issues. If GitHub private vulnerability reporting is available, use the
repository's Security → Report a vulnerability page. Otherwise open a minimal
issue requesting a private contact without including sensitive details.

## Boundaries

- All app data stays in the current macOS account; no application-level
  database encryption, authentication, server, or cloud backup is provided.
- Developer environment overrides are trusted local input, not a sandbox.
  Automated seed, snapshot, performance, and self-test modes refuse the normal
  database, require a private owner-only temporary parent, and reject database
  symlinks before opening a model container.
- Never run untrusted scripts or set APP_STORE to your personal database for tests.
- Source builds are locally signed, not notarized or App Store reviewed.
- Back up the complete data directory with the app closed before upgrades.

The pre-publication pattern scan found no high-signal credentials in reviewed
source/history. This is not a guarantee that no vulnerability or secret exists.
The public repository starts from a reviewed snapshot; private development
history and personal author email addresses are intentionally excluded.
