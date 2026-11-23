# Third-party notices

MacPanel is an independent MIT-licensed project. It does not embed MonitorControl or Stats.

## m1ddc

- Author: waydabber and contributors
- Source: https://github.com/waydabber/m1ddc
- Reviewed revision: `9d75fb6c407ac60dc77a9e32c43d60fd0e6d1612`
- License: MIT, copyright © 2021 waydabber
- Full notice: [Resources/m1ddc-LICENSE.txt](Resources/m1ddc-LICENSE.txt), also included in the app bundle

`Native/DisplayBridge.m` adapts DDC packet framing, reply validation and Apple Silicon
framebuffer-to-proxy matching. It exposes brightness only. MacPanel adds bounded reads,
fixed request sizes, ownership cleanup, dynamic symbol lookup, per-display request coalescing
and a Swift interface. The upstream CLI, EDID parser, input switching, power and other VCP
commands are not included. There is no downloaded runtime helper or shell command for displays.

Apple frameworks are supplied by macOS and are not redistributed in this repository.
