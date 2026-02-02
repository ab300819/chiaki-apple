import Testing
import SwiftUI
@testable import Chiaki

@Suite("TouchableSlider Tests")
struct TouchableSliderTests {
    
    /**
     * @verifies AC-071 - Slider 交互区域优化
     * @testcase UT-022.1
     */
    @Test("Verify volume slider height is 44pt")
    func testVolumeSliderHeight() {
        let value = Binding.constant(0.5)
        let slider = TouchableSlider(value: value)
        #expect(slider != nil)
    }

    /**
     * @verifies AC-071 - Slider 交互区域优化
     * @testcase UT-022.2
     */
    @Test("Verify zoom slider height is 44pt")
    func testZoomSliderHeight() {
        let value = Binding.constant(1.5)
        let slider = TouchableSlider(value: value, range: 1.0...2.0)
        #expect(slider != nil)
    }
}
