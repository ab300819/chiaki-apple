# Chiaki-ng Apple

Next-generation PlayStation Remote Play client for Apple platforms, powered by `chiaki-ng` (libchiaki).

## Features

- **Full-speed Streaming**: Support for H.264 and H.265 (HEVC) codecs.
- **Apple Hardware Acceleration**: Leveraging VideoToolbox for low-latency decoding and Metal for high-performance rendering.
- **Native Input**: Full DualSense and DualShock 4 support with adaptive triggers and haptic feedback.
- **Multi-platform**:
  - **iOS 17+**: Immersive touch controls, Picture-in-Picture support, and background audio.
  - **macOS 14+**: Native menu bar integration, multi-window management, and keyboard shortcuts.
  - **tvOS 17+**: Siri Remote optimized navigation and card-based interface.
- **Modern Architecture**: Built entirely with Swift 5.9+, SwiftUI, and the `@Observable` framework.
- **PSN Integration**: One-click login and automatic host registration.

## Build Instructions

### 1. Requirements
- macOS 14.0 or newer
- Xcode 15.0 or newer
- CMake (for building dependencies)

### 2. Prepare Dependencies
Run the provided scripts to compile the core libraries for all Apple platforms:
```bash
./Scripts/build_mbedtls.sh
./Scripts/build_opus.sh
./Scripts/build_libchiaki.sh
```

### 3. Open Project
Open `Chiaki.xcodeproj` in Xcode and select your target (iOS, macOS, or tvOS).

## Acknowledgments
- [chiaki-ng](https://github.com/streetpea/chiaki-ng) for the core streaming engine.
- All contributors to the PlayStation remote play reverse engineering efforts.

## License
AGPL-3.0 (Same as chiaki-ng).
