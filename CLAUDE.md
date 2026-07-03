# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

```bash
# Build
make build

# Clean build artifacts
make clean

# Format source code (swift-format)
make format

# Lint source code (swift-format lint)
make lint

# Build, install, and launch on a connected iPhone
make run-device

# Open in Xcode
open MyAnimeList.xcodeproj
```

## Project Overview

**VlogSlate** — a native iOS app for film/video production slate management (场记板). All source under `MyAnimeList/`.

### Architecture

- **`MyAnimeListApp.swift`** — App entry with `@Observable` store; tabbed root view (片库/场记/扫码).
- **`Models/VlogSlateStore.swift`** — `VlogSlateStore` (JSON-backed, `@Observable`), `FootageItem` model, `VlogSlatePayload`, export/import types, `UTType`, JSON encoder/decoder extensions.
- **`Views/VlogSlate/`** — All UI:
  - `SlateControllerView.swift` — Slate controller: scene/clip steppers, QR code generation, countdown fullscreen capture.
  - `FootageShelfView.swift` — Footage library with token-based search (`S1C2`, `完美`, `C>3`, `S1-3`), filtering, export/import.
  - `FootageDetailView.swift` — Edit a take: status (完美/备用/废镜), notes, scene thumbnail (camera/photo library).
  - `ScannerView.swift` — AVFoundation QR code scanner to look up takes.
  - `VlogSlateVisuals.swift` — Shared components: `VlogSlatePosterBlock`, `StatusBadge`, `NavigationTitleCapsule`, `CircleActionButton`, `StatCard`, `glassEffect` extension.
  - `UIImagePicker.swift` — `UIImagePickerController` wrapper for camera capture.

### Data Persistence

- JSON files at `~/Library/Application Support/VlogSlate/footage.json`.
- Thumbnails stored as JPEG files alongside the JSON.
- Import/export uses `.vlogslate` file format (`UTType(exportedAs: "com.openai.vlogslate")`).

### iOS 26+ APIs Used

- `@Observable` macro for state management
- `tabBarMinimizeBehavior(.onScrollDown)` — tab bar collapse
- `glassEffect` modifier for frosted glass visuals
- `contentTransition(.numericText)` — animated number transitions
- `.symbolEffect(.replace)` — SF Symbol animations
- `sensoryFeedback()` — haptic feedback

### Dependencies

- **None.** No SPM packages. Only system frameworks: SwiftUI, UIKit, AVFoundation, CoreImage, PhotosUI, UniformTypeIdentifiers, Observation.

### Code Style

- Follow `swift-format` rules (config: `.swift-format`).
- Use `LocalizedStringResource` for user-facing strings.
- Prefer `.environment(store)` + `@Environment(StoreType.self)` over `@EnvironmentObject`.
- Git: conventional commits (`type: subject` imperative, capitalized, no period).

### Git Branches

- `main` — stable releases.
- `slate` (current) — active development.
