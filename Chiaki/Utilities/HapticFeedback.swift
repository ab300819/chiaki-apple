import SwiftUI

/**
 * Static utility for UI haptic feedback to ensure consistent interaction response
 * @requirement F-023 - iPad 触摸操作友好化
 * @satisfies AC-072 - 触觉反馈统一
 */
@MainActor
enum HapticFeedback {
    /**
     * Play feedback for standard button press
     * @testcase UT-023.1
     */
    static func button() {
        HapticsManager.shared.playImpact(.medium)
    }

    /**
     * Play feedback for successful operations
     * @testcase UT-023.2
     */
    static func success() {
        HapticsManager.shared.playSuccess()
    }

    /**
     * Play feedback for warnings or soft errors
     * @testcase UT-023.3
     */
    static func warning() {
        HapticsManager.shared.playWarning()
    }

    /**
     * Play feedback for selection changes (e.g. Picker, Slider)
     * @testcase UT-023.4
     */
    static func selection() {
        HapticsManager.shared.playSelection()
    }
}
