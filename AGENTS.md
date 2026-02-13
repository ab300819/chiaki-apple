# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Chiaki Apple is a native PlayStation Remote Play client for iOS 17+, macOS 14+, and tvOS 17+. It streams PS5/PS4 gameplay over the network using the chiaki-ng (libchiaki) C library, with a pure SwiftUI frontend and Metal-based rendering. License: AGPL-3.0.

The nested `chiaki-ng/` directory is an upstream submodule — treat as third-party unless a task explicitly targets it.

## Build Commands

### Dependencies (must be built before the app)
```bash
make setup           # Initialize git submodules
make                 # Build all xcframeworks: mbedtls → opus → libchiaki
make libplacebo      # Build libplacebo + MoltenVK xcframeworks (optional)
```

### App Build
```bash
xcodebuild build -project Chiaki.xcodeproj -scheme Chiaki -destination 'platform=macOS'
xcodebuild build -project Chiaki.xcodeproj -scheme Chiaki -destination 'platform=iOS Simulator,name=iPhone 16'
```

Single Xcode scheme: `Chiaki`. Three targets: `Chiaki`, `ChiakiTests`, `ChiakiUITests`.

### Testing
```bash
# Full test suite
xcodebuild test -project Chiaki.xcodeproj -scheme Chiaki -destination 'platform=macOS'

# Single test class
xcodebuild test -project Chiaki.xcodeproj -scheme Chiaki -destination 'platform=macOS' \
  -only-testing:ChiakiTests/PlaceboVideoRendererTests

# Single test method
xcodebuild test -project Chiaki.xcodeproj -scheme Chiaki -destination 'platform=macOS' \
  -only-testing:ChiakiTests/PlaceboVideoRendererTests/testConformsToVideoRenderer

# Build tests only (when test runner crashes due to signing issues)
xcodebuild build-for-testing -project Chiaki.xcodeproj -scheme Chiaki -destination 'platform=macOS'
```

Tests use **Swift Testing** framework (`import Testing`, `@Test`, `#expect`), not XCTest (except some legacy log tests that still use XCTest).

**Known issue**: Test execution may crash with `signal abrt` due to libplacebo.framework codesign failure. Use `build-for-testing` to verify compilation.

No SwiftLint/SwiftFormat is configured.

## Architecture

### Directory Layout
```
Chiaki/
├── App/                  # Entry points (ChiakiApp, ChiakiTVApp), NavigationManager
├── Core/
│   ├── Bridge/           # C↔Swift bridge: ChiakiBridge.h, ChiakiSession, ChiakiDiscovery, ChiakiRegist
│   ├── Video/            # VideoRenderer protocol, MetalVideoRenderer, PlaceboVideoRenderer
│   │   └── Placebo/      # libplacebo C bridge: PlaceboBridge.h → PlaceboContext.m → PlaceboTypes.swift
│   ├── Audio/            # Audio playback pipeline
│   ├── Controllers/      # DualSense/DualShock4 HID, GameController framework, ControllerOrchestrator
│   ├── Storage/          # SettingsStore, HostStore (UserDefaults), KeychainManager, ConsolePinManager
│   ├── Streaming/        # StreamStatsManager
│   └── Network/          # Network utilities
├── Domain/
│   ├── Models/           # ConsoleHost, StreamSettings
│   └── Services/         # HostManager, PSNService
├── Features/             # Feature modules, each with Views + ViewModels
│   ├── HostList/         # Host discovery, add/edit/register hosts
│   ├── Streaming/        # StreamingView, StreamingViewModel, controls overlay, virtual controller
│   ├── Settings/         # Settings screens with per-section ViewModels
│   ├── PSNLogin/         # PSN OAuth login
│   ├── AutoConnect/      # Auto-connect flow
│   └── Common/           # Shared UI components
├── Shared/Protocols/     # PSNServicing, PinManaging
├── Platforms/tvOS/       # tvOS app entry point
└── Utilities/            # Logger, CrashReporter, ThemeManager
```

### Key Design Decisions

**State management**: Swift Observation framework (`@Observable @MainActor`). Singletons for shared state: `SettingsStore.shared`, `HostStore.shared`, `ControllerOrchestrator.shared`. No Combine, no third-party state libraries.

**Platform branching**: `#if os(iOS)` / `#if os(macOS)` / `#if os(tvOS)` throughout. iOS uses TabView, macOS uses NavigationSplitView, tvOS uses focus-based grid with TVHostCardView.

**Video rendering pipeline**: `VideoRenderer` protocol (`Core/Video/VideoRenderer.swift`) abstracts the rendering backend. Two implementations:
- `MetalVideoRenderer` — production Metal renderer with HDR/EDR, video filter pipeline (upscale, CAS, deband)
- `PlaceboVideoRenderer` — libplacebo/Vulkan via MoltenVK (failable `init?`, returns nil when pipeline is stub)

**Factory fallback**: `StreamingViewModel.createRenderer()` tries the selected backend first. If `PlaceboVideoRenderer()` returns nil, it falls back to Metal Native automatically.

**C bridge layer**: Two separate bridge paths:
1. **libchiaki**: `ChiakiBridge.h` (bridging header) → Swift wrappers (`ChiakiSession`, `ChiakiDiscovery`, `ChiakiRegist`, `ChiakiTypes`)
2. **libplacebo**: `PlaceboBridge.h` → `PlaceboContext.m` (Objective-C) → `PlaceboTypes.swift` → `PlaceboVideoRenderer.swift`

**Concurrency**: All UI state is `@MainActor`. Renderers are `@unchecked Sendable` with internal `NSLock`. C bridge callbacks dispatch to main via `Task { @MainActor in }`. Background queues for video decoding (`.userInteractive`), audio, file logging (`.background`).

**Logging**: Use `logInfo()`, `logWarning()`, `logError()` global functions — not `print`. These route through a unified `Logger` with OSLog + file output.

## Conventions

- License header: `// SPDX-License-Identifier: AGPL-3.0-only` on all source files
- Requirement traceability in doc comments: `@requirement F-XXX`, `@satisfies AC-XXX`
- Test traceability: `@verifies AC-XXX`, `@testcase UT-XXX` / `IT-XXX`
- Commits: `feat(scope):`, `fix(scope):`, `chore(scope):` with task/bug references (T-XXX, BUG-XXX)
- Branch workflow: `dev` for development, `main` for PRs
- C bridge memory: explicit symmetric lifecycle (create/destroy pairs, `Unmanaged` patterns)

## Development Documentation

Structured docs in `docs/devdocs/`:
- `01-requirements.md` — Feature requirements and acceptance criteria (F-XXX, AC-XXX)
- `02-system-design.md` — System architecture
- `03-test-cases.md` — Test case registry (UT-XXX, IT-XXX)
- `04-dev-tasks.md` — Development tasks (T-XXX)
- `05-bugfix-log.md` — Bug fix records (BUG-XXX)
- `00-progress-report.md` — Milestone tracking
