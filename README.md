# VlogSlate 🎬

A native iOS app for film and video production slate management — log takes, scan QR codes from set, and keep your footage organized.

## Features

- **📋 Slate Controller** — Set scene, clip, and take numbers with an intuitive interface; generates scannable QR codes
- **📚 Footage Library** — Browse all recorded takes with inline thumbnails; filter/search by scene, clip, status
- **🔍 Advanced Search** — Token-based search syntax: `S1C2`, `完美`, `C>3`, `S1-3`, combinations like `S2 C>3`
- **📷 Scene Thumbnails** — Capture or import reference photos per scene from camera or photo library
- **🏷️ Take Status** — Mark takes as Good/备用/废镜; filter and sort by status
- **📤 Export/Import** — Share and restore full project files (`.vlogslate` format)
- **📱 QR Scanner** — Scan slate QR codes from recorded footage to look up the take

## Requirements

- iOS 26.0+
- Xcode 26.0+
- Swift 6.1+

## Getting Started

```bash
git clone <repo-url>
cd VlogSlate
open MyAnimeList.xcodeproj
```

Select a target device or simulator and press `⌘R`.

## Build Commands

```bash
make clean          # Clean build artifacts
make build          # Build
make format         # Format code (swift-format)
make lint           # Lint code (swift-format)
make run-device     # Build + install on connected iPhone
```

## Tech Stack

- **SwiftUI** with `@Observable` and modern patterns
- **iOS 26+** APIs (glass effects, tab bar minimize, numeric text transitions)
- **AVFoundation** for QR scanning and camera capture
- **CoreImage** for QR code generation

## Project Structure

```
MyAnimeList/          # Main app (name kept for Xcode compatibility)
  Sources/
    App/
      MyAnimeListApp.swift      # App entry + root tab view
    Models/
      VlogSlateStore.swift      # Store, models, persistence
    Views/
      VlogSlate/
        SlateControllerView.swift   # Main slate interface
        FootageShelfView.swift      # Footage library
        FootageDetailView.swift     # Take detail/editing
        ScannerView.swift           # QR code scanner
        VlogSlateVisuals.swift      # Shared UI components
        UIImagePicker.swift         # Camera capture wrapper
```

## License

Apache License 2.0
