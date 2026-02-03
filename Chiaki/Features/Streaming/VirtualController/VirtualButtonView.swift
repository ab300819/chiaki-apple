import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Configuration

/**
 * Configuration constants for virtual button gestures
 * @requirement F-023 - iPad 触摸操作友好化
 * @satisfies AC-074 - 长按手势支持
 */
enum VirtualButtonConfig {
    /// Long press duration threshold in seconds
    static let longPressDuration: TimeInterval = 0.5
    /// Scale effect when long pressing
    static let longPressScale: CGFloat = 0.85
}

#if os(iOS)
/**
 * Virtual button with tap and long press support
 * @requirement F-023 - iPad 触摸操作友好化
 * @satisfies AC-074 - 长按手势支持
 */
struct VirtualButtonView: View {
    let iconName: String
    let buttonName: String
    var size: CGFloat = 60
    var color: Color = .white
    var hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle = .light
    var onStateChanged: (Bool) -> Void
    /// Optional long press callback (triggered after 0.5s hold)
    var onLongPress: (() -> Void)?

    @State private var isPressed: Bool = false
    @State private var isLongPressing: Bool = false

    // Cache the generator to reduce latency
    @State private var hapticGenerator: UIImpactFeedbackGenerator?

    var body: some View {
        ZStack {
            // Glassmorphism Background
            Circle()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark) // Force dark blur for better contrast
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            
            // Pressed State Highlight
            Circle()
                .fill(isPressed ? color.opacity(0.5) : Color.white.opacity(0.05))
                .frame(width: size, height: size)
                
            // Border
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            color.opacity(isPressed ? 0.9 : 0.4),
                            color.opacity(isPressed ? 0.5 : 0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
                .frame(width: size, height: size)
            
            // Icon
            Image(systemName: iconName)
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundStyle(isPressed ? .white : color)
                .shadow(color: isPressed ? color.opacity(0.5) : .clear, radius: 5)
        }
        .scaleEffect(isLongPressing ? VirtualButtonConfig.longPressScale : (isPressed ? 0.92 : 1.0))
        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .animation(.easeInOut(duration: 0.15), value: isLongPressing)
        .accessibilityLabel(buttonName)
        .accessibilityValue(isPressed ? String(localized: "virtualController.pressed") : String(localized: "virtualController.released"))
        .accessibilityHint(onLongPress != nil ? String(localized: "virtualController.longPressHint") : "")
        .onAppear {
            prepareHaptics()
        }
        .gesture(combinedGesture)
    }

    // MARK: - Gestures

    /// Combined gesture using SimultaneousGesture for drag and long press
    private var combinedGesture: some Gesture {
        if onLongPress != nil {
            // Use simultaneous gesture when long press is enabled
            return AnyGesture(
                SimultaneousGesture(
                    dragGesture,
                    longPressGesture
                ).map { _ in () }
            )
        } else {
            // Use only drag gesture when no long press handler
            return AnyGesture(dragGesture.map { _ in () })
        }
    }

    /// Drag gesture for tap detection (fires immediately on touch)
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                if !isPressed {
                    isPressed = true
                    onStateChanged(true)
                    triggerHaptic()
                }
            }
            .onEnded { _ in
                // Only release if not currently long pressing
                if !isLongPressing {
                    isPressed = false
                    onStateChanged(false)
                }
                // Reset long press state
                isLongPressing = false
            }
    }

    /// Long press gesture for extended hold detection
    private var longPressGesture: some Gesture {
        LongPressGesture(minimumDuration: VirtualButtonConfig.longPressDuration)
            .onEnded { _ in
                isLongPressing = true
                triggerLongPressHaptic()
                onLongPress?()
            }
    }
    
    private func prepareHaptics() {
        hapticGenerator = UIImpactFeedbackGenerator(style: hapticStyle)
        hapticGenerator?.prepare()
    }
    
    private func triggerHaptic() {
        hapticGenerator?.impactOccurred()
        // Re-prepare for next tap
        hapticGenerator?.prepare()
    }

    /// Trigger stronger haptic feedback for long press
    private func triggerLongPressHaptic() {
        // Use heavy impact for long press confirmation
        let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
        heavyGenerator.impactOccurred()
    }
}

#Preview {
    ZStack {
        Color.black
        HStack(spacing: 20) {
            VirtualButtonView(iconName: "xmark", buttonName: "Cross", color: .blue) { pressed in
                print("Cross: \(pressed)")
            }
            VirtualButtonView(iconName: "circle", buttonName: "Circle", color: .red) { pressed in
                print("Circle: \(pressed)")
            }
        }
    }
    .environment(SettingsStore())
    .environment(NavigationManager())
}
#endif
