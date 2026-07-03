# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

```bash
# Build
make build

# Clean build artifacts
make clean

# Format code (swift-format)
make format

# Lint code (swift-format lint)
make lint

# Build, install, launch on connected iPhone
make run-device

# Open in Xcode
open MyAnimeList.xcodeproj
```

## Project Overview

**RecipeSlate** — a native iOS recipe app inspired by Crouton (2024 Apple Design Award winner). 3-tab app: 菜谱浏览 → 分步烹饪(免触) → 购物清单.

## Architecture

### Tab Structure

| # | Tab | File | Description |
|---|-----|------|-------------|
| 1 | 菜谱 | `Views/Recipe/RecipeShelfView.swift` | Crouton-style list: thumbnail + name + status + search/filter. Opens `RecipeDetailView.swift` for editing. |
| 2 | 烹饪 | `Views/Recipe/CookModeView.swift` | Crouton-style step-by-step: full-screen step cards, swipe/click navigation, voice commands, inline timers |
| 3 | 食材 | `Views/Recipe/ShoppingListView.swift` | Grocery list: aggregated ingredients by category, checkable |

### Crouton-Inspired Features

- **Single-step focus**: One card at a time during cook mode, no distraction
- **Hands-free navigation**: `SFSpeechRecognizer` for voice commands ("下一步"/"next"/"上一步"/"back")
- **Swipe gestures**: `DragGesture` for step navigation (left=next, right=previous)
- **Tap navigation**: Tap left/right half of screen for prev/next
- **Inline timers**: Per-step countdown timers (`Timer.scheduledTimer`), haptic feedback on completion
- **Ingredient highlighting**: Step text highlights ingredient names in orange
- **Ingredient popup**: Show all ingredient quantities from current step
- **Smart step input**: Detects cooking verbs (煮/炖/烤) → auto-shows time picker

### Data Model

`Models/RecipeStore.swift` — `@Observable` store with JSON persistence:
- `Recipe` — name, thumbnail, servings, status, ingredients[], steps[], notes
- `Ingredient` — name, amount, unit, category, isPrepared
- `CookingStep` — order, description, duration (optional, for timer)
- `scaledIngredients(for:)` — auto-scale amounts by serving count

## Data Persistence

JSON files at `~/Library/Application Support/VlogSlate/`:
- `recipes.json` — all recipes
- Thumbnails as `recipe_<id>_thumb.jpg`

## Voice & Permissions

- **Speech**: `SFSpeechRecognizer` (zh-Hans) listens for commands during cooking
- Info.plist includes: `NSSpeechRecognitionUsageDescription`, `NSMicrophoneUsageDescription`, `NSCameraUsageDescription`

## Dependencies

None. System frameworks only: SwiftUI, UIKit, AVFoundation, Speech, PhotosUI, Observation, UniformTypeIdentifiers.

## Code Style

- Follow `swift-format`
- Use `@Observable` + `@Environment` for state management
- For bindings: `Bindable(store).$property`
- Git: conventional commits, imperative capitalized subject
