import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct VirtualButtonView: View {
    let iconName: String
    var size: CGFloat = 60
    var color: Color = .white
    #if canImport(UIKit)
    var hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle = .light
    #endif
    var onStateChanged: (Bool) -> Void
    
    @State private var isPressed: Bool = false
    
    // Cache the generator to reduce latency
    #if canImport(UIKit)
    @State private var hapticGenerator: UIImpactFeedbackGenerator?
    #endif
    
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
                .foregroundColor(isPressed ? .white : color)
                .shadow(color: isPressed ? color.opacity(0.5) : .clear, radius: 5)
        }
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onAppear {
            prepareHaptics()
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        onStateChanged(true)
                        triggerHaptic()
                    }
                }
                .onEnded { _ in
                    isPressed = false
                    onStateChanged(false)
                }
        )
    }
    
    private func prepareHaptics() {
        #if canImport(UIKit)
        hapticGenerator = UIImpactFeedbackGenerator(style: hapticStyle)
        hapticGenerator?.prepare()
        #endif
    }
    
    private func triggerHaptic() {
        #if canImport(UIKit)
        hapticGenerator?.impactOccurred()
        // Re-prepare for next tap
        hapticGenerator?.prepare()
        #endif
    }
}

#Preview {
    ZStack {
        Color.black
        HStack(spacing: 20) {
            VirtualButtonView(iconName: "xmark", color: .blue) { pressed in
                print("Cross: \(pressed)")
            }
            VirtualButtonView(iconName: "circle", color: .red) { pressed in
                print("Circle: \(pressed)")
            }
        }
    }
    .environment(SettingsStore())
    .environment(NavigationManager())
}
