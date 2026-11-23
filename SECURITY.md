# Security

MacPanel operates locally. It has no accounts, telemetry backend, downloaded command execution,
packet capture or administrator helper. Fixed Apple tools implement the quick controls;
display operations call macOS frameworks directly.

Security-sensitive areas include DDC replies from attached hardware, volume identity before
ejection, the global shortcut and the optional System Events automation permission.

Please use GitHub private vulnerability reporting when available. Do not put credentials,
private documents or unnecessary system logs into a public issue. Compatibility reports can
use a normal issue with the macOS version, app version, monitor/dock model and reproduction steps.

The project is an early release. A successful local signature check or test suite is not a guarantee
of security or compatibility. Public binary distribution will require its own signing and notarization process.
