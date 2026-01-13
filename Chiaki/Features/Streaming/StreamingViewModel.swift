import Foundation
import Observation
import SwiftUI

@Observable
class StreamingViewModel {

    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
        case error(String)
    }

    var state: ConnectionState = .disconnected
    var isOverlayVisible: Bool = true

    var currentResolution: String = "1080p"
    var currentFrameRate: Int = 60
    var latency: Double = 15.0
    var bitrate: Double = 25.0
    
    private var timer: Timer?
    
    init() {
        connect()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    func connect() {
        state = .connecting
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.state = .connected
            self?.startMockStatsUpdate()
        }
    }
    
    func disconnect() {
        timer?.invalidate()
        state = .disconnected
    }
    
    func toggleOverlay() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isOverlayVisible.toggle()
        }
    }
    
    private func startMockStatsUpdate() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            let randomLatencyChange = Double.random(in: -2...2)
            self.latency = max(5.0, min(50.0, self.latency + randomLatencyChange))
            
            let randomBitrateChange = Double.random(in: -1...1)
            self.bitrate = max(10.0, min(50.0, self.bitrate + randomBitrateChange))
        }
    }
}
