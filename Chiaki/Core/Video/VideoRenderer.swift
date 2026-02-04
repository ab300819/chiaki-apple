// SPDX-License-Identifier: AGPL-3.0-only
//
// VideoRenderer.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Abstract interface for video rendering backends.
// Allows decoupling the streaming pipeline from specific rendering implementations (e.g. Metal, libplacebo).
//
// [requirement] F-026 - 渲染模块解耦重构
// [satisfies] AC-087 - 渲染抽象接口
//

import Foundation
import CoreVideo
import MetalKit

// MARK: - Video Display Mode

/// Video display modes matching chiaki-ng GUI options
/// [satisfies] AC-087
enum VideoDisplayMode: Int, CaseIterable, Sendable {
    case normal = 0    // Maintain aspect ratio, letterbox/pillarbox
    case stretch = 1   // Stretch to fill screen
    case zoom = 2      // Zoom to fill, crop edges

    var displayName: String {
        switch self {
        case .normal: return "Normal"
        case .stretch: return "Stretch"
        case .zoom: return "Zoom"
        }
    }
}

/// Protocol defining the interface for video rendering backends.
/// All implementations must be thread-safe for frame submission.
/// Note: Does NOT inherit MTKViewDelegate - that responsibility moves to VideoStreamView.Coordinator (T-158)
/// [requirement] F-026
/// [satisfies] AC-086, AC-087
protocol VideoRenderer: AnyObject, Sendable {

    /// Weak reference to the view for power management and updates (implementers should use `weak`)
    var mtkView: MTKView? { get set }
    
    // MARK: - Frame Input
    
    /// Submit a new video frame for rendering
    /// - Parameter pixelBuffer: The raw video frame from decoder
    /// [satisfies] AC-087
    func submitFrame(_ pixelBuffer: CVPixelBuffer)
    
    // MARK: - Display Configuration
    
    /// Current display mode (Fit, Stretch, Zoom)
    var displayMode: VideoDisplayMode { get set }
    
    /// Zoom factor (1.0 - 2.0, only used in zoom mode)
    var zoomFactor: Float { get set }
    
    /// Whether VRR (Variable Refresh Rate) is enabled
    var vrrEnabled: Bool { get set }
    
    // MARK: - HDR & Color Management
    
    /// Current HDR configuration
    var hdrConfiguration: HDRConfiguration { get set }
    
    /// Current display EDR headroom (1.0+)
    var edrHeadroom: Float { get set }
    
    // MARK: - Color Adjustments
    
    /// Set brightness (0.0 - 2.0, default 1.0)
    func setBrightness(_ value: Float)
    
    /// Set contrast (0.0 - 2.0, default 1.0)
    func setContrast(_ value: Float)
    
    /// Set saturation (0.0 - 2.0, default 1.0)
    func setSaturation(_ value: Float)
    
    /// Set color space (0 = BT.709, 1 = BT.601, 2 = BT.2020)
    func setColorSpace(_ value: UInt32)
    
    // MARK: - Lifecycle & View Integration
    
    /// Update rendering policy (e.g. target frame rate)
    /// - Parameter fps: Optional new target FPS
    func updateRenderingPolicy(fps: Int?)
    
    /// Update view size (call when hosting view resizes)
    func updateViewSize(_ size: CGSize)
    
    /// Flush internal texture/resource caches
    func flushTextureCache()
    
    // MARK: - Frame Query

    /// Current frame size (dimensions of the last submitted frame)
    /// Returns .zero if no frame has been submitted
    var frameSize: CGSize { get }

    /// Whether a frame has been submitted and is ready for rendering
    var hasFrame: Bool { get }

    // MARK: - Rendering

    /// Render the current frame to a drawable
    /// - Parameters:
    ///   - view: The MTKView to render to
    ///   - descriptor: Optional render pass descriptor (uses view's current if nil)
    func render(to view: MTKView, descriptor: MTLRenderPassDescriptor?)

    // MARK: - Statistics & Callbacks

    /// Total frames rendered
    var frameCount: UInt64 { get }

    /// Total frames dropped
    var droppedFrameCount: UInt64 { get }

    /// Reset statistics counters
    func resetStatistics()

    /// Callback triggered when a frame is submitted
    var onFrameSubmitted: ((CVPixelBuffer) -> Void)? { get set }

    /// Callback triggered when rendering timing is recorded (ms)
    var onRenderTimeRecorded: ((Double) -> Void)? { get set }
}
