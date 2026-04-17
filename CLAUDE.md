# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project status

PaywallKit is a Swift Package in scaffold state — `Sources/PaywallKit/PaywallKit.swift` is empty aside from header comments, and `Package.swift` declares a single library target with no dependencies and no test target. Any non-trivial request will require creating the initial module structure from scratch.

## Toolchain

- `Package.swift` pins `swift-tools-version: 6.2`. Use a Swift 6.2+ toolchain; Swift 6 strict concurrency applies by default.
- No platform constraints are declared, so the package currently builds for every Apple platform the host toolchain supports. Add a `platforms:` clause to `Package.swift` before introducing platform-specific APIs (StoreKit, SwiftUI paywall views, etc.).

## Common commands

```bash
swift build                              # build the PaywallKit library
swift test                               # runs once a test target exists — none today
swift test --filter PaywallKitTests.SomeTest/testCase   # single test (after tests are added)
swift package clean                      # wipe .build/
swift package resolve                    # refresh Package.resolved after editing dependencies
```

There is no Xcode project checked in; open the folder directly in Xcode (it reads `Package.swift`) or use `xed .`.

## When adding tests

`Package.swift` has no `.testTarget` yet. Adding tests requires editing `Package.swift` to append a test target (conventional path: `Tests/PaywallKitTests/`) — `swift test` will fail until that target exists.
