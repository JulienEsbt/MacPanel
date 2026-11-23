# Changelog

## 0.2.1 — 2026-11-23

- Display used storage against total capacity, with free space on a separate line.
- Use filesystem free space consistently, so used and free values add up to total
  capacity; purgeable data remains included in used space.

## 0.2.0 — 2026-11-23

### Added
- Separate System, Displays and Disks views.
- Memory pressure and local Wi-Fi/Ethernet transfer rates.
- Mounted-volume capacity, Finder access and guarded external-volume ejection.
- Per-display brightness: Apple hardware control, Apple Silicon DDC/CI, and software dimming when hardware control is unavailable.
- Brightness changes while dragging, with coalesced hardware requests.
- Configurable global shortcut, including correct letter mapping for AZERTY keyboards.
- English/French documentation and screenshots.

### Fixed
- Off-screen menu panel placement in a multi-display setup with different vertical origins.

## 0.1.0 — 2026-11-23

- Initial local application: CPU/RAM/GPU readings, five quick controls, temporary awake sessions and launch-at-login registration.
- Native AppKit lifecycle and SwiftUI panel, without a privileged helper.
