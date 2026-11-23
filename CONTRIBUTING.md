# Contributing

MacPanel aims to remain a small, local macOS utility. Please discuss substantial new capabilities
before adding dependencies, background services or permissions.

1. Install Xcode 16+ and XcodeGen.
2. Run `bash scripts/test.sh` and `bash scripts/build.sh`.
3. Include a focused regression test for calculation, protocol or lifecycle changes.
4. Verify affected UI behavior on hardware. Never describe a simulated protocol response as a tested monitor.
5. Document compatibility limits, new permissions and third-party licenses.

Tests are hostless XCTest bundles. A small number briefly create real sleep assertions and release them.
Display tests read capabilities and validate malformed responses; they do not change hardware brightness.
Do not introduce forced unmounts, automatic file deletion, packet inspection or credential collection.

Use small changes and explain the observed problem, resulting behavior and relevant validation.
