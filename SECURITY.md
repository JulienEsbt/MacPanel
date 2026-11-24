# Security

MacPanel operates locally. It has no accounts, telemetry backend, downloaded command execution,
packet capture or administrator helper. Fixed Apple tools implement the quick controls;
display operations call macOS frameworks directly.

Security-sensitive areas include DDC replies from attached hardware, volume identity before
ejection, global shortcuts and System Events automation.
External brightness uses two explicitly registered Carbon hot keys, not a keyboard event
tap. Their identifiers are checked before dispatch, separately from the panel shortcut.
There is no ordinary-key listener or key logging, and no Accessibility, Input Monitoring,
System & App Protection Override, Screen Recording or Full Disk Access requirement.
Native media-key interception was not retained because the owner chose to avoid the
broader permission shown by macOS 27.3 beta.

Please use GitHub private vulnerability reporting when available. Do not put credentials,
private documents or unnecessary system logs into a public issue. Compatibility reports can
use a normal issue with the macOS version, app version, monitor/dock model and reproduction steps.

The project is an early release. A successful local signature check or test suite is not a guarantee
of security or compatibility. Public binary distribution will require its own signing and notarization process.
