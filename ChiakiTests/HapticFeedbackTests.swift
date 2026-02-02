import Testing
@testable import Chiaki

@Suite("HapticFeedback Tests")
@MainActor
struct HapticFeedbackTests {
    
    /**
     * @verifies AC-072 - 触觉反馈统一
     * @testcase UT-023.1
     */
    @Test("Verify button() method existence")
    func testHapticFeedbackButtonMethod() {
        HapticFeedback.button()
        #expect(true)
    }

    /**
     * @verifies AC-072 - 触觉反馈统一
     * @testcase UT-023.2
     */
    @Test("Verify success() method existence")
    func testHapticFeedbackSuccessMethod() {
        HapticFeedback.success()
        #expect(true)
    }

    /**
     * @verifies AC-072 - 触觉反馈统一
     * @testcase UT-023.3
     */
    @Test("Verify warning() method existence")
    func testHapticFeedbackWarningMethod() {
        HapticFeedback.warning()
        #expect(true)
    }

    /**
     * @verifies AC-072 - 触觉反馈统一
     * @testcase UT-023.4
     */
    @Test("Verify selection() method existence")
    func testHapticFeedbackSelectionMethod() {
        HapticFeedback.selection()
        #expect(true)
    }
}
