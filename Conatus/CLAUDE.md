# CLAUDE.md

This file provides guidance to Claude Code when working with this UIKit iOS project.

## Project Overview

- **Name:** Conatus
- **Type:** UIKit-based iOS app. SwiftUI is used selectively for iOS 26 Liquid Glass surfaces, bridged into UIKit via `UIHostingController` (see `Views/HomeGlassActionBar.swift`).
- **Target OS:** iOS 26.4+
- **Bundle ID:** `me.ozdes.seymen.Conatus`
- **Dependencies:** None (bare Xcode template)
- **Compiler Settings:** MainActor isolation enabled, modern Swift concurrency expected

## Build & Run

**Xcode:**
```bash
Open Conatus.xcodeproj and build with Cmd+B
```

**CLI (Debug on iPhone 16 simulator):**
```bash
xcodebuild -scheme Conatus -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16'
```

**Run tests (when configured):**
```bash
xcodebuild test -scheme Conatus -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Architecture & Patterns

### App Lifecycle
```
AppDelegate
  ├─ application(_:didFinishLaunchingWithOptions:) — app initialization
  └─ SceneDelegate
      ├─ scene(_:willConnectTo:options:) — window setup
      └─ UIWindow(rootViewController: ViewController())
```

### View Controller Lifecycle
Always respect the lifecycle and prefer composition over inheritance:
- `init(coder:)` — storyboard/nib initialization
- `viewDidLoad()` — subview setup (called once)
- `viewWillAppear(_:)` — setup before display
- `viewDidAppear(_:)` — animations and appearance logic
- `viewWillDisappear(_:)` — cleanup before removal
- `viewDidDisappear(_:)` — final teardown
- `deinit` — deallocate observers, cancel async tasks

### Memory Management
- Use weak references in closures that capture `self`: `[weak self] in`
- Cancel URLSession tasks and combine subscriptions in `deinit` or `viewDidDisappear`
- Remove KVO observers and NotificationCenter subscriptions before deallocation
- Avoid retain cycles: don't store completion handlers that capture self strongly

### UIView Hierarchy
- Use auto layout (`NSLayoutConstraint` or `NSLayoutAnchor`) for responsive layouts
- Prefer `safeAreaLayoutGuide` for iPhone notch/Dynamic Island safe areas
- Call `translatesAutoresizingMaskIntoConstraints = false` before using anchors
- Apply constraints in `viewDidLoad()` or `layoutSubviews()`

## Code Style & Conventions

### Swift Concurrency
- Use `@MainActor` for code running on the main thread (default for UIViewController, UIView)
- Use `Task { }` for background work: `Task { await fetchData() }`
- Prefer `async/await` over callbacks for asynchronous operations
- Use `@escaping` closures only when necessary; prefer `async` functions

### Naming
- View controllers: `FooViewController` or `FooScreen`
- Views: `FooView`, `FooButton`, `FooLabel`
- Models: `Foo`, `FooModel`
- Services: `FooService`, `FooManager`, `FooRepository`
- Computed properties for side-effect-free getters
- Prefix private methods with underscore if needed: `_configure()`

### Access Control
- Default to `private` for view controller properties; use `fileprivate` for file-scoped helpers
- Mark IBOutlets `@IBOutlet private weak var foo: UIView?`
- Use `internal` (default) only for cross-module APIs

### File Organization
Group code by responsibility within files:
```swift
// MARK: - Lifecycle
// MARK: - Layout
// MARK: - Actions
// MARK: - Helpers
```

## Common Patterns

### Network Requests
Use `URLSession` with structured concurrency:
```swift
@MainActor
private func fetchData() async {
    do {
        let (data, _) = try await URLSession.shared.data(from: url)
        self.model = try JSONDecoder().decode(Model.self, from: data)
    } catch {
        self.error = error
    }
}
```

### UITableView / UICollectionView
- Implement `UITableViewDataSource` and `UITableViewDelegate` as extensions
- Register cells in `viewDidLoad()`: `tableView.register(Cell.self, forCellReuseIdentifier: "cell")`
- Reload data on main thread: `Task { @MainActor in self.tableView.reloadData() }`

### KVO & Notifications
Prefer property observers when possible:
```swift
@Observable final class ViewModel {
    var count = 0
}

class ViewController: UIViewController {
    private var model = ViewModel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Use Combine or simple property watching
    }
}
```

### Closures & Callbacks
Always use weak self to avoid retain cycles:
```swift
button.addAction(UIAction { [weak self] _ in
    self?.handleTap()
}, for: .touchUpInside)
```

## Testing

Currently no test targets configured. When adding tests:
- Create a `ContatusTests` target for unit tests
- Test ViewModels and Services, not ViewControllers directly
- Use XCTest for basic testing; consider Quick/Nimble for BDD-style

## Debugging Tips

- **View Hierarchy:** In Xcode debugger, use `po UIApplication.shared.windows.first?.recursiveDescription` to print the view tree
- **Constraints:** Enable view borders to debug layout: `view.layer.borderColor = UIColor.red.cgColor; view.layer.borderWidth = 1`
- **Thread Safety:** Use `assert(Thread.isMainThread)` in UI code
- **Memory:** Check for retain cycles using Instruments → Allocations → mark heap
