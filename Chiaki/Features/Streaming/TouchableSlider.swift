import SwiftUI

/**
 * Touchable friendly Slider component, expanding the interaction area to 44pt
 * @requirement F-023 - iPad 触摸操作友好化
 * @satisfies AC-071 - Slider 交互区域优化
 */
struct TouchableSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1
    var tint: Color? = nil
    var onEditingChanged: (Bool) -> Void = { _ in }

    var body: some View {
        Slider(value: $value, in: range, onEditingChanged: onEditingChanged)
            .tint(tint)
            .frame(height: ChiakiTheme.Touch.sliderHeight)
            .contentShape(Rectangle())
    }
}
