// SPDX-License-Identifier: AGPL-3.0-only
//
// EdgeVolumeGesture.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Edge swipe gesture for volume adjustment on iPad
// @requirement F-023 - iPad 触摸操作友好化
// @satisfies AC-075 - 滑动快捷调节

import SwiftUI

// MARK: - Configuration

/**
 * Configuration constants for edge volume gesture
 * @requirement F-023 - iPad 触摸操作友好化
 * @satisfies AC-075 - 滑动快捷调节
 */
enum EdgeVolumeConfig {
    /// Edge detection zone width in points (Apple HIG: 44pt minimum touch target)
    static let edgeWidth: CGFloat = 44

    /// Minimum vertical distance to trigger volume change
    static let minimumDragDistance: CGFloat = 20

    /// Volume change per drag distance unit
    static let volumePerPoint: Double = 0.002
}

// MARK: - Edge Volume Gesture View

#if os(iOS)
/**
 * Invisible edge overlay that handles vertical swipe for volume control
 * @requirement F-023 - iPad 触摸操作友好化
 * @satisfies AC-075 - 滑动快捷调节
 */
struct EdgeVolumeGestureView: View {
    /// Current volume binding (0.0-1.0)
    @Binding var volume: Double

    /// Callback when volume changes (to show OSD)
    var onVolumeChange: () -> Void

    /// Track the starting Y position of the drag
    @State private var dragStartY: CGFloat = 0

    /// Track the volume at drag start
    @State private var dragStartVolume: Double = 0

    /// Whether a drag is in progress
    @State private var isDragging: Bool = false

    var body: some View {
        GeometryReader { geometry in
            // Right edge zone
            Rectangle()
                .fill(Color.clear)
                .frame(width: EdgeVolumeConfig.edgeWidth)
                .position(x: geometry.size.width - EdgeVolumeConfig.edgeWidth / 2, y: geometry.size.height / 2)
                .frame(height: geometry.size.height)
                .contentShape(Rectangle())
                .gesture(volumeDragGesture)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Gesture

    private var volumeDragGesture: some Gesture {
        DragGesture(minimumDistance: EdgeVolumeConfig.minimumDragDistance)
            .onChanged { value in
                if !isDragging {
                    // First change - record starting position
                    isDragging = true
                    dragStartY = value.startLocation.y
                    dragStartVolume = volume
                    HapticFeedback.selection()
                }

                // Calculate volume change based on vertical movement
                // Dragging up (negative Y) increases volume
                let dragDelta = dragStartY - value.location.y
                let volumeDelta = dragDelta * EdgeVolumeConfig.volumePerPoint

                // Calculate new volume with clamping
                let newVolume = max(0.0, min(1.0, dragStartVolume + volumeDelta))

                // Only update if changed significantly (avoid tiny updates)
                if abs(newVolume - volume) >= 0.01 {
                    volume = newVolume
                    onVolumeChange()
                }
            }
            .onEnded { _ in
                isDragging = false
                HapticFeedback.selection()
            }
    }
}

// MARK: - View Extension

extension View {
    /**
     * Add edge volume gesture to a streaming view
     * @requirement F-023 - iPad 触摸操作友好化
     * @satisfies AC-075 - 滑动快捷调节
     */
    func edgeVolumeGesture(volume: Binding<Double>, onVolumeChange: @escaping () -> Void) -> some View {
        self.overlay {
            EdgeVolumeGestureView(volume: volume, onVolumeChange: onVolumeChange)
        }
    }
}

// MARK: - Preview

#Preview("Edge Volume Gesture") {
    struct PreviewWrapper: View {
        @State private var volume: Double = 0.5
        @State private var showOSD: Bool = false

        var body: some View {
            ZStack {
                Color.blue.opacity(0.3)
                    .ignoresSafeArea()

                VStack {
                    Text("Volume: \(Int(volume * 100))%")
                        .font(.largeTitle)

                    Text("Swipe on right edge to adjust")
                        .foregroundStyle(.secondary)
                }
            }
            .edgeVolumeGesture(volume: $volume) {
                withAnimation(.snappy) {
                    showOSD = true
                }
                // Auto-hide after 2 seconds
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    withAnimation(.snappy) {
                        showOSD = false
                    }
                }
            }
            .overlay {
                if showOSD {
                    VStack {
                        Spacer()
                        VolumeOSD(volume: volume, isVisible: .constant(true))
                            .padding(.bottom, 60)
                    }
                }
            }
        }
    }

    return PreviewWrapper()
}
#endif
