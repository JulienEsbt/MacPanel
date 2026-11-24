# Delivery checklist

- [x] Native local app with quick controls, CPU/RAM/GPU and temporary awake sessions
- [x] Memory pressure and local network transfer rates
- [x] Mounted volumes, capacity, Finder access and guarded external-volume ejection
- [x] Per-display brightness with live sliders and bounded/coalesced hardware writes
- [x] Explicit software-dimming fallback and restoration without root privileges
- [x] Global shortcut with AZERTY mapping and conflict handling
- [x] Correct multi-display placement, confirmed by the user
- [x] Final local suite: 27 tests passed; signed Release build installed
- [x] English/French README, real screenshots, MIT credits and source-build instructions
- [x] GitHub Actions workflow prepared for build and tests

Hardware follow-up: validate DDC with a compatible monitor/cable. MonitorControl was
removed at the owner’s explicit request on 23 November. Optional real-login observation
remains separate from this delivery.


## 0.3 — external brightness shortcuts

- [x] Dedicated Control + Option + Up/Down registration without input observation
- [x] Bounded external-display adjustment using the existing display controller
- [x] Optional persisted switch and shortcut conflict status
- [x] Route the panel and brightness shortcuts to their own handlers
- [x] MonitorControl stopped and moved to Trash without emptying it
- [x] Runtime shortcut registration active; no external screen means no built-in brightness change
- [ ] Physical external-display key test (no external screen connected this session)


## 0.3.1 — native brightness updates

- [x] Follow native brightness while the panel is visible
- [x] Stop observation on close without cancelling background display discovery
- [x] Short caption and secondary help in tooltip
- [x] 34 native tests passed; owner confirmed live native-key updates
- [x] Signed Release installed and relaunched; source and docs remain local pending Git signing

## 0.4 — daily extensions

- [x] Section/control order and visibility, persisted and resettable
- [x] CPU/resident-memory app ranking with accessible children and PID reuse guard
- [x] Stop app collection on panel close, hidden section and non-System tabs
- [x] Optional linked brightness sliders and explicit per-display fixed offsets
- [x] Serialized, capability-checked DDC speaker-volume writes
- [x] Confirmed batch ejection, identity revalidation and partial errors
- [x] Native logic tests and signed Release build
- [x] Linked sliders verified on the current external screen; DDC audio unsupported on this connection
- [x] Signed local installation with one app copy in Applications
- [x] Live linked-slider observation completed; final 0.4.2 layout checked separately below

## 0.4.2 — final display polish

- [x] Brightness controls before persistent linking/keyboard options
- [x] Explicit fixed-offset stepper, whole-point persistence
- [x] Hide unsupported display-audio row, retain compatible hardware support
- [x] 42 native tests, signed Release installed and running
- [x] Final layout observed; fixed +21-point offset unchanged from either brightness slider
