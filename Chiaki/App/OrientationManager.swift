//
//  OrientationManager.swift
//  Chiaki
//
//  iPhone orientation locking for streaming views.
//
//  @requirement F-039 - iPhone 串流横屏锁定
//  @satisfies AC-148 - 进入 StreamingView 时锁定横屏

#if os(iOS)
import UIKit

/// Manages interface orientation locking on iPhone.
///
/// Set `lockOrientation` to constrain the allowed orientations,
/// or `nil` to restore default behavior.
@MainActor
final class OrientationManager {
    static let shared = OrientationManager()

    /// When non-nil, the app delegate returns this mask instead of the default.
    var lockOrientation: UIInterfaceOrientationMask? {
        didSet {
            // Trigger UIKit to re-query supported orientations
            if #available(iOS 16.0, *) {
                guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
                scene.requestGeometryUpdate(.iOS(interfaceOrientations: lockOrientation ?? .allButUpsideDown))
            }
        }
    }
}
#endif
