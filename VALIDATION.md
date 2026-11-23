# Local validation

## 0.2.0 — 23 November 2026

**Environment:** MacBook Air M3, 16 GB; macOS 27.3 beta (26C5047e), Xcode 27.2 (27B52).
Local success on this setup does not establish compatibility with every supported macOS version or monitor.

### Automated checks

- **26 XCTest tests passed**, zero failures, in the final local run.
- Signed universal Release build passed (`arm64` and `x86_64`).
- Strict signature verification passed for the installed local Apple Development build.
  This is development signing, not Developer ID notarization or an App Store release.
- CPU counter deltas/wrap, RAM calculation, absent/invalid GPU readings, network timing/reset
  handling, and kernel memory-pressure levels are covered.
- Real Mach readings and stopping publication after the panel closes are covered.
- Internal/unknown-volume ejection guards, invalid capacities, actual root-volume discovery
  and volume-list uniqueness are covered. No real external disk was ejected in these tests.
- DDC checksums, short/null responses, unsupported codes and impossible values are rejected.
- Software dimming scales original color tables; mismatched tables are not treated as owned.
- Multi-display placement is bounded for positive/negative coordinates and screen edges.
- The letter M resolves to key code 41 on the test machine’s AZERTY layout.
- Real temporary sleep assertions are created/replaced/released by the tests.

### Observed UI and hardware behavior

- CPU, GPU, RAM, normal memory pressure and nonzero incoming/outgoing rates are visible in the System view.
- The root disk is listed with available/total capacity and no ejection button.
- Both built-in and external displays are discovered.
- The built-in panel exposes Apple hardware brightness. A temporary change to 90% was
  read back through the app; later user-selected brightness was preserved.
- The connected external display returned invalid DDC responses; hardware brightness
  control is **not validated** for that screen/cable combination. The app rejects those
  responses and offers labelled software image dimming instead of inventing a reading.
- A transient overlay was replaced with public display transfer-table adjustment, with
  saved-table restoration that respects subsequent changes by other apps.
- The user confirmed both the corrected panel placement and brightness changing while
  dragging, before releasing the mouse.
- The user confirmed Control + Option + M opens MacPanel. Launch at login remains enabled.
- System, Displays and Disks screenshots were captured from the real app, without desktop/chat content.
- The previous 0.1 quick-control validation covered light/dark mode, desktop icons,
  Dock/menu bar preferences, mute and awake start/stop, restoring the original settings.

### Remaining practical limits

- Real hardware DDC must be tested with a compatible monitor and connection. MonitorControl
  remains installed; this version has not demonstrated an equivalent replacement on the current external screen.
- No external-drive ejection trial or fresh login/reboot was required for this increment.
- A clean local build and signature do not prove notarized distribution or complete security.
- ColorSync, Night Shift and other brightness tools can change image transfer tables.
  Software dimming is an image adjustment, not backlight or energy-saving control.

## Repository and installation

One app is installed at `/Applications/MacPanel.app`. The working source is in
`~/Dev/MacPanel`. Generated projects, build output, local logs and test result bundles are ignored.

Only luminance-specific adaptations of MIT-licensed m1ddc code are included, with copyright
and license in source and app resources. No upstream executable, shell-based display helper,
network client, root service or new security permission was added in 0.2.

OpenDente and MonitorControl were not modified. Organize was removed at the user’s request;
Homebrew also removed dependencies it classified as unneeded. No user documents were sorted or deleted.
