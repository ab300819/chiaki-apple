import Foundation

enum VirtualControllerInput {
    case leftStick(x: Float, y: Float)
    case rightStick(x: Float, y: Float)
    case button(VirtualControllerButton, pressed: Bool)
}

enum VirtualControllerButton {
    case cross, circle, triangle, square
    case up, down, left, right
    case l1, l2, r1, r2
    case share, options, ps
}
