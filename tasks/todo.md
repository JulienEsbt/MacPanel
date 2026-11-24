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
