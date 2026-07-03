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

# Build, install, and launch on connected iPhone
make run-device

# Open in Xcode
open MyAnimeList.xcodeproj
```

## Project Overview

**VlogSlate** — dual-mode iOS app: **镜头模式** (film slate) + **菜谱模式** (recipe management). Long-press the navigation title to toggle between modes. Target: iOS 26+.

## Dual-Mode Architecture

### Mode Switching
- `MyAnimeListApp.swift` — Root `@main` manages `isRecipeMode` state, renders `VlogSlateTabView` or `RecipeTabView` with crossfade transition
- Long-press on `VlogSlateNavigationTitleCapsule` ("X镜头") or `RecipeNavigationTitleCapsule` ("X菜谱") triggers toggle

### 镜头模式 (VlogSlate)
| Tab | File | Function |
|-----|------|----------|
| 片库 | `VlogSlate/FootageShelfView.swift` | Footage library + token search |
| 场记 | `VlogSlate/SlateControllerView.swift` | Slate controller + QR codes |
| 扫码 | `VlogSlate/ScannerView.swift` | QR scanner |
| (搜索) | `VlogSlate/FootageShelfView.swift:FootageSearchView` | Search tab |

### 菜谱模式 (Recipe)
| Tab | File | Function |
|-----|------|----------|
| 菜谱 | `Recipe/RecipeShelfView.swift` | Recipe library + status filter + smart search |
| 食材 | `Recipe/ShoppingListView.swift` | Ingredient shopping list, grouped & checkable |
| 制作 | `Recipe/CookingView.swift` | Step-by-step cooking with per-step countdown timers |
| 计价 | `Recipe/PriceCalculatorView.swift` | Takeout price sum / homemade ingredient cost + time |

## Data Models

### Store (`Models/VlogSloteStore.swift`)
- `VlogSlateStore` — `@Observable`, JSON persistence for footage items
- `FootageItem` — scene/clip/take tracking

### Store (`Models/RecipeStore.swift`)
- `RecipeStore` — `@Observable`, JSON persistence for recipes
- `Recipe` — name, servings, times, status, `[Ingredient]`, `[CookingStep]`
- `Ingredient` — name, amount, unit, category, isPrepared
- `CookingStep` — order, description, optional duration (for timer)
- `scaledIngredients(for:)` — auto-scale amounts by serving count

## Key Design Patterns

- **`@Observable`** + `@Environment` for state management
- **Bindable**: `Bindable(store).$property` for two-way bindings with `@Observable`
- **JSON persistence**: Manual load/save in `applicationSupportDirectory/VlogSlate/`
- **Thumbnails**: JPEG files in same directory, `RecipeStore.saveThumbnail(data:for:)`
- **Smart step input**: `RecipeDetailView` detects cooking verbs (煮/炖/烤/煎) → auto-shows time picker
- **Step timers**: `CookingView.StepCookingCard` uses `Timer.publish` for countdown per step

## Data Persistence

All JSON files in `~/Library/Application Support/VlogSlate/`:
- `footage.json` — VlogSlateStore items
- `recipes.json` — RecipeStore recipes
- Thumbnails as `recipe_<id>_thumb.jpg` / `scene_<id>_thumb.jpg`

## iOS 26+ APIs Used
- `@Observable` macro, `tabBarMinimizeBehavior(.onScrollDown)`, `glassEffect`, `contentTransition(.numericText)`, `.symbolEffect(.replace)`, `sensoryFeedback()`

## Dependencies
- **None.** System frameworks only: SwiftUI, UIKit, AVFoundation, CoreImage, PhotosUI, Observation

## Code Style
- Follow `swift-format` (config: `.swift-format`)
- Git: conventional commits, imperative capitalized subject, no period
- Prefer `.environment(store)` + `@Environment(StoreType.self)` over `@EnvironmentObject`
