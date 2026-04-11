# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

Open `Conatus.xcodeproj` in Xcode and build with Cmd+B, or via CLI:

```bash
xcodebuild -scheme Conatus -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16'
```

There are no test targets or linting tools configured yet.

## Architecture

This is a UIKit-based iOS app (no SwiftUI) targeting iOS 26.4. The project is a bare Xcode template — no external dependencies, no custom architecture layers yet.

**App startup flow:**
```
AppDelegate → SceneDelegate → UIWindow(rootViewController: ViewController())
```

**Key Swift compiler settings enabled by default:**
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — all code runs on MainActor unless otherwise annotated
- `SWIFT_APPROACHABLE_CONCURRENCY = YES` — modern Swift concurrency is the expected model
- `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES`

**Bundle ID:** `me.ozdes.seymen.Conatus`
