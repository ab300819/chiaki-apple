import SwiftUI

#if os(iOS)
struct VirtualControllerView: View {
    var onInput: (VirtualControllerInput) -> Void
    var opacity: Double = 0.5
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack {
                    HStack(alignment: .top) {
                        HStack(spacing: 20) {
                            VirtualButtonView(iconName: "l2.button.roundedtop.horizontal", size: 50, color: .white, hapticStyle: .heavy) { pressed in
                                onInput(.button(.l2, pressed: pressed))
                            }
                            VirtualButtonView(iconName: "l1.button.roundedtop.horizontal", size: 50, color: .white, hapticStyle: .medium) { pressed in
                                onInput(.button(.l1, pressed: pressed))
                            }
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 30) {
                            VirtualButtonView(iconName: "square.and.arrow.up", size: 40, color: .white, hapticStyle: .medium) { pressed in
                                onInput(.button(.share, pressed: pressed))
                            }
                            
                            VirtualButtonView(iconName: "playstation.logo", size: 50, color: .white, hapticStyle: .medium) { pressed in
                                onInput(.button(.ps, pressed: pressed))
                            }
                            
                            VirtualButtonView(iconName: "line.3.horizontal", size: 40, color: .white, hapticStyle: .medium) { pressed in
                                onInput(.button(.options, pressed: pressed))
                            }
                        }
                        .offset(y: 10)
                        
                        Spacer()
                        
                        HStack(spacing: 20) {
                            VirtualButtonView(iconName: "r1.button.roundedtop.horizontal", size: 50, color: .white, hapticStyle: .medium) { pressed in
                                onInput(.button(.r1, pressed: pressed))
                            }
                            VirtualButtonView(iconName: "r2.button.roundedtop.horizontal", size: 50, color: .white, hapticStyle: .heavy) { pressed in
                                onInput(.button(.r2, pressed: pressed))
                            }
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 20)
                    
                    Spacer()
                }
                
                HStack(alignment: .bottom) {
                    VStack(spacing: 40) {
                        dpadView
                        
                        VirtualStickView { point in
                            onInput(.leftStick(x: Float(point.x), y: Float(point.y)))
                        }
                    }
                    .padding(.leading, 60)
                    .padding(.bottom, 40)
                    
                    Spacer()
                    
                    VStack(spacing: 40) {
                        faceButtonsView
                        
                        VirtualStickView { point in
                            onInput(.rightStick(x: Float(point.x), y: Float(point.y)))
                        }
                    }
                    .padding(.trailing, 60)
                    .padding(.bottom, 40)
                }
            }
            .opacity(opacity)
        }
    }
    
    private var dpadView: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow {
                Color.clear.frame(width: 50, height: 50)
                VirtualButtonView(iconName: "arrowtriangle.up.fill", size: 50, color: .gray, hapticStyle: .light) { pressed in
                    onInput(.button(.up, pressed: pressed))
                }
                Color.clear.frame(width: 50, height: 50)
            }
            GridRow {
                VirtualButtonView(iconName: "arrowtriangle.left.fill", size: 50, color: .gray, hapticStyle: .light) { pressed in
                    onInput(.button(.left, pressed: pressed))
                }
                Color.clear.frame(width: 50, height: 50)
                VirtualButtonView(iconName: "arrowtriangle.right.fill", size: 50, color: .gray, hapticStyle: .light) { pressed in
                    onInput(.button(.right, pressed: pressed))
                }
            }
            GridRow {
                Color.clear.frame(width: 50, height: 50)
                VirtualButtonView(iconName: "arrowtriangle.down.fill", size: 50, color: .gray, hapticStyle: .light) { pressed in
                    onInput(.button(.down, pressed: pressed))
                }
                Color.clear.frame(width: 50, height: 50)
            }
        }
    }
    
    private var faceButtonsView: some View {
        Grid(horizontalSpacing: 15, verticalSpacing: 15) {
            GridRow {
                Color.clear.frame(width: 55, height: 55)
                VirtualButtonView(iconName: "triangle.fill", size: 55, color: .green, hapticStyle: .medium) { pressed in
                    onInput(.button(.triangle, pressed: pressed))
                }
                Color.clear.frame(width: 55, height: 55)
            }
            GridRow {
                VirtualButtonView(iconName: "square.fill", size: 55, color: .pink, hapticStyle: .medium) { pressed in
                    onInput(.button(.square, pressed: pressed))
                }
                Color.clear.frame(width: 55, height: 55)
                VirtualButtonView(iconName: "circle.fill", size: 55, color: .red, hapticStyle: .medium) { pressed in
                    onInput(.button(.circle, pressed: pressed))
                }
            }
            GridRow {
                Color.clear.frame(width: 55, height: 55)
                VirtualButtonView(iconName: "multiply", size: 55, color: .blue, hapticStyle: .medium) { pressed in
                    onInput(.button(.cross, pressed: pressed))
                }
                Color.clear.frame(width: 55, height: 55)
            }
        }
    }
}

#Preview(traits: .landscapeLeft) {
    ZStack {
        Color.blue.edgesIgnoringSafeArea(.all)
        VirtualControllerView { input in
            print("Input: \(input)")
        }
    }
    .environment(SettingsStore())
    .environment(NavigationManager())
}
#endif
