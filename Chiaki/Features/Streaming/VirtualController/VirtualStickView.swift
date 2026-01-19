import SwiftUI

struct VirtualStickView: View {
    var onValueChanged: (CGPoint) -> Void
    var size: CGFloat = 160
    var thumbSize: CGFloat = 70
    
    @State private var position: CGPoint = .zero
    @State private var isDragging: Bool = false
    
    private var maxRadius: CGFloat {
        (size - thumbSize) / 2
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
            
            Circle()
                .fill(isDragging ? .white.opacity(0.8) : .white.opacity(0.5))
                .frame(width: thumbSize, height: thumbSize)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                .offset(x: position.x, y: position.y)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            
                            let vector = CGPoint(x: value.translation.width, y: value.translation.height)
                            let distance = sqrt(pow(vector.x, 2) + pow(vector.y, 2))
                            
                            if distance > maxRadius {
                                let angle = atan2(vector.y, vector.x)
                                position = CGPoint(
                                    x: cos(angle) * maxRadius,
                                    y: sin(angle) * maxRadius
                                )
                            } else {
                                position = vector
                            }
                            
                            let normalizedX = position.x / maxRadius
                            let normalizedY = position.y / maxRadius
                            
                            onValueChanged(CGPoint(x: normalizedX, y: normalizedY))
                        }
                        .onEnded { _ in
                            isDragging = false
                            
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                position = .zero
                            }
                            onValueChanged(.zero)
                        }
                )
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    ZStack {
        Color.black
        VirtualStickView { point in
            print("Stick: \(point)")
        }
    }
    .environment(SettingsStore())
    .environment(NavigationManager())
}
