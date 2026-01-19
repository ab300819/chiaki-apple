import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct VirtualButtonView: View {
    let iconName: String
    var size: CGFloat = 60
    var color: Color = .white
    var onStateChanged: (Bool) -> Void
    
    @State private var isPressed: Bool = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: size, height: size)
            
            Circle()
                .fill(isPressed ? color.opacity(0.6) : Color.clear)
                .frame(width: size, height: size)
                
            Circle()
                .stroke(color.opacity(isPressed ? 0.8 : 0.3), lineWidth: 1.5)
                .frame(width: size, height: size)
            
            Image(systemName: iconName)
                .font(.system(size: size * 0.45, weight: .bold))
                .foregroundColor(isPressed ? .white : color)
        }
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
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
    
    private func triggerHaptic() {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
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
