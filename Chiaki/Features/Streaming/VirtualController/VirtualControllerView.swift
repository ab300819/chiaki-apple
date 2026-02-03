import SwiftUI

#if os(iOS)
/**
 * Virtual controller overlay for touch-based input
 * @requirement F-023 - iPad 触摸操作友好化
 * @satisfies AC-074 - 长按手势支持
 */
struct VirtualControllerView: View {
    var onInput: (VirtualControllerInput) -> Void
    /// Optional callback for long press on specific buttons (e.g., Square for screenshot)
    var onLongPress: ((VirtualControllerButton) -> Void)?
    var opacity: Double = 0.5

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack {
                    HStack(alignment: .top) {
                        /**
                         * Shoulder buttons (L1/L2) with Apple HIG compliant spacing
                         * @requirement F-023 - iPad 触摸操作友好化
                         * @satisfies AC-070 - 控件间距优化
                         */
                        HStack(spacing: 24) {
                            VirtualButtonView(iconName: "l2.button.roundedtop.horizontal", buttonName: String(localized: "virtualController.l2"), size: 50, color: .white, hapticStyle: .heavy) { pressed in
                                onInput(.button(.l2, pressed: pressed))
                            }
                            VirtualButtonView(iconName: "l1.button.roundedtop.horizontal", buttonName: String(localized: "virtualController.l1"), size: 50, color: .white, hapticStyle: .medium) { pressed in
                                onInput(.button(.l1, pressed: pressed))
                            }
                        }
                        
                        Spacer()
                        
                        /**
                         * Center menu buttons with Apple HIG compliant touch targets
                         * @requirement F-023 - iPad 触摸操作友好化
                         * @satisfies AC-069 - 触摸目标尺寸
                         */
                        HStack(spacing: 30) {
                            VirtualButtonView(iconName: "square.and.arrow.up", buttonName: String(localized: "virtualController.share"), size: ChiakiTheme.Touch.minTargetSize, color: .white, hapticStyle: .medium) { pressed in
                                onInput(.button(.share, pressed: pressed))
                            }

                            VirtualButtonView(iconName: "playstation.logo", buttonName: String(localized: "virtualController.ps"), size: 50, color: .white, hapticStyle: .medium) { pressed in
                                onInput(.button(.ps, pressed: pressed))
                            }

                            VirtualButtonView(iconName: "line.3.horizontal", buttonName: String(localized: "virtualController.options"), size: ChiakiTheme.Touch.minTargetSize, color: .white, hapticStyle: .medium) { pressed in
                                onInput(.button(.options, pressed: pressed))
                            }
                        }
                        .offset(y: 10)
                        
                        Spacer()
                        
                        /**
                         * Shoulder buttons (R1/R2) with Apple HIG compliant spacing
                         * @requirement F-023 - iPad 触摸操作友好化
                         * @satisfies AC-070 - 控件间距优化
                         */
                        HStack(spacing: 24) {
                            VirtualButtonView(iconName: "r1.button.roundedtop.horizontal", buttonName: String(localized: "virtualController.r1"), size: 50, color: .white, hapticStyle: .medium) { pressed in
                                onInput(.button(.r1, pressed: pressed))
                            }
                            VirtualButtonView(iconName: "r2.button.roundedtop.horizontal", buttonName: String(localized: "virtualController.r2"), size: 50, color: .white, hapticStyle: .heavy) { pressed in
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
                        
                        VirtualStickView(accessibilityLabel: String(localized: "virtualController.leftStick")) { point in
                            onInput(.leftStick(x: Float(point.x), y: Float(point.y)))
                        }
                    }
                    .padding(.leading, 60)
                    .padding(.bottom, 40)
                    
                    Spacer()
                    
                    VStack(spacing: 40) {
                        faceButtonsView
                        
                        VirtualStickView(accessibilityLabel: String(localized: "virtualController.rightStick")) { point in
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
    
    /**
     * D-Pad with Apple HIG compliant control spacing
     * @requirement F-023 - iPad 触摸操作友好化
     * @satisfies AC-070 - 控件间距优化
     */
    private var dpadView: some View {
        Grid(horizontalSpacing: ChiakiTheme.Touch.minSpacing, verticalSpacing: ChiakiTheme.Touch.minSpacing) {
            GridRow {
                Color.clear.frame(width: 50, height: 50)
                VirtualButtonView(iconName: "arrowtriangle.up.fill", buttonName: String(localized: "virtualController.up"), size: 50, color: .gray, hapticStyle: .light) { pressed in
                    onInput(.button(.up, pressed: pressed))
                }
                Color.clear.frame(width: 50, height: 50)
            }
            GridRow {
                VirtualButtonView(iconName: "arrowtriangle.left.fill", buttonName: String(localized: "virtualController.left"), size: 50, color: .gray, hapticStyle: .light) { pressed in
                    onInput(.button(.left, pressed: pressed))
                }
                Color.clear.frame(width: 50, height: 50)
                VirtualButtonView(iconName: "arrowtriangle.right.fill", buttonName: String(localized: "virtualController.right"), size: 50, color: .gray, hapticStyle: .light) { pressed in
                    onInput(.button(.right, pressed: pressed))
                }
            }
            GridRow {
                Color.clear.frame(width: 50, height: 50)
                VirtualButtonView(iconName: "arrowtriangle.down.fill", buttonName: String(localized: "virtualController.down"), size: 50, color: .gray, hapticStyle: .light) { pressed in
                    onInput(.button(.down, pressed: pressed))
                }
                Color.clear.frame(width: 50, height: 50)
            }
        }
    }
    
    /**
     * Face buttons with long press support on Square for screenshot
     * @requirement F-023 - iPad 触摸操作友好化
     * @satisfies AC-074 - 长按手势支持
     */
    private var faceButtonsView: some View {
        Grid(horizontalSpacing: 15, verticalSpacing: 15) {
            GridRow {
                Color.clear.frame(width: 55, height: 55)
                VirtualButtonView(iconName: "triangle.fill", buttonName: String(localized: "virtualController.triangle"), size: 55, color: .green, hapticStyle: .medium) { pressed in
                    onInput(.button(.triangle, pressed: pressed))
                }
                Color.clear.frame(width: 55, height: 55)
            }
            GridRow {
                // Square button with long press support (example: screenshot trigger)
                VirtualButtonView(
                    iconName: "square.fill",
                    buttonName: String(localized: "virtualController.square"),
                    size: 55,
                    color: .pink,
                    hapticStyle: .medium,
                    onStateChanged: { pressed in
                        onInput(.button(.square, pressed: pressed))
                    },
                    onLongPress: onLongPress != nil ? { onLongPress?(.square) } : nil
                )
                Color.clear.frame(width: 55, height: 55)
                VirtualButtonView(iconName: "circle.fill", buttonName: String(localized: "virtualController.circle"), size: 55, color: .red, hapticStyle: .medium) { pressed in
                    onInput(.button(.circle, pressed: pressed))
                }
            }
            GridRow {
                Color.clear.frame(width: 55, height: 55)
                VirtualButtonView(iconName: "multiply", buttonName: String(localized: "virtualController.cross"), size: 55, color: .blue, hapticStyle: .medium) { pressed in
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
        VirtualControllerView(
            onInput: { input in
                print("Input: \(input)")
            },
            onLongPress: { button in
                print("Long press on: \(button)")
            }
        )
    }
    .environment(SettingsStore())
    .environment(NavigationManager())
}
#endif
