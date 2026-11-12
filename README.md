# Chiaki-ng Apple

Native SwiftUI PlayStation Remote Play client for Apple platforms, powered by [`chiaki-ng`](https://github.com/chiaki-ng/chiaki-ng) (libchiaki).

> **Status:** macOS is the most complete so far, and the iPadOS/iPhone builds work. Streaming and HDR still need to be re-checked on real devices with the latest build. Distribution is planned via TestFlight (App Store release is unlikely).

## Features

- **Full-speed Streaming**: Support for H.264 and H.265 (HEVC) codecs with bitrates up to 100 Mbps.
- **Dynamic Profiles**: Independent settings for Local and Remote (over the internet) streaming sessions.
- **Hardcore Diagnostics**: Real-time overlay showing RTT latency, bitrate, packet loss, dropped frames, and FEC recovery metrics.
- **Advanced Session Management**: Confirmation dialog on disconnect with "Sleep on Disconnect" (Rest Mode) support.
- **Flexible Scaling**: Support for Normal (Fit), Stretch, and Zoom display modes with adjustable zoom factor.
- **Apple Hardware Acceleration**: VideoToolbox decoding and a native Metal renderer by default.
- **Optional libplacebo renderer** (macOS, Apple silicon): uses a [libplacebo fork with a native Metal backend](https://github.com/ab300819/libplacebo/tree/metal-absorb) (LGPL-2.1, dynamic framework).
- **Native Input**: Full DualSense and DualShock 4 support with adaptive triggers and haptic feedback.
- **Multi-platform**:
  - **iPadOS / iOS 26+**: Immersive touch controls, Picture-in-Picture support, and background audio.
  - **macOS 26+**: Native menu bar integration, multi-window management, and keyboard shortcuts.
  - **visionOS**: planned. **tvOS**: paused for now.
- **Modern Architecture**: Built entirely with Swift 5.9+, SwiftUI, and the `@Observable` framework.
- **PSN Integration**: One-click login and automatic host registration.

## Build Instructions

### 1. Requirements
- macOS 26 or newer, Xcode 27
- Homebrew: `cmake`, `meson`, `ninja`, `shaderc`, `spirv-cross`, `protobuf`
- [`uv`](https://docs.astral.sh/uv/) (provides Python `protobuf` for nanopb during the libchiaki build)

### 2. Prepare Dependencies
```bash
git submodule update --init --recursive
make mbedtls opus
uv run --no-project --with protobuf -- make libchiaki
make libplacebo   # optional libplacebo renderer, macOS arm64
```

### 3. Open Project
Open `Chiaki.xcodeproj` in Xcode and build the `Chiaki` scheme for macOS or iOS/iPadOS.

## Development

Development is AI-assisted; every change is reviewed and decided by the maintainer. The protocol is not re-implemented or translated: the app links chiaki-ng's own library.

## Acknowledgments
- [chiaki-ng](https://github.com/chiaki-ng/chiaki-ng) for the core streaming engine.
- All contributors to the PlayStation remote play reverse engineering efforts.

## License
All code is open source. The license is being finalised in alignment with the chiaki-ng organization. Source files currently carry `SPDX-License-Identifier: AGPL-3.0-only`, and the app links AGPL-licensed chiaki-ng.
