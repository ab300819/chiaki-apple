// SPDX-License-Identifier: AGPL-3.0-only
import Foundation

protocol RenderDiagnosticsReporting: AnyObject {
    var droppedFrameCount: UInt64 { get }
    var frameRepeatCount: UInt64 { get }
    var presentInterval: Double { get }
    var filterName: String { get }
    var backendName: String { get }
}

extension MetalVideoRenderer: RenderDiagnosticsReporting {
    var backendName: String { "Metal Native" }
}

extension PlaceboVideoRenderer: RenderDiagnosticsReporting {
    var backendName: String { "libplacebo" }
}
