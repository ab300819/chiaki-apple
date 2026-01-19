import Foundation
import SwiftUI

/// Mock data for SwiftUI Previews
struct MockData {
    static let hostPS5 = ConsoleHost(
        nickname: "Living Room PS5",
        address: "192.168.1.100",
        isPS5: true,
        registKey: Data(count: 16),
        rpKey: Data(),
        rpKeyType: 0
    )
    
    static let hostPS4 = ConsoleHost(
        nickname: "Bedroom PS4",
        address: "192.168.1.101",
        isPS5: false,
        registKey: Data(count: 16),
        rpKey: Data(),
        rpKeyType: 0
    )
    
    static let hostUnregistered = ConsoleHost(
        nickname: "New PS5",
        address: "192.168.1.102",
        isPS5: true
    )
    
    static let hosts = [hostPS5, hostPS4, hostUnregistered]
    
    static var streamSettings: StreamSettings {
        var settings = StreamSettings()
        settings.localProfile.resolution = .r1080p
        settings.localProfile.frameRate = .fps60
        settings.localProfile.bitrate = 30000
        settings.codec = .h265
        settings.hdrEnabled = true
        return settings
    }
}

extension ConsoleHost {
    static var mockOnline: ConsoleHost {
        var host = MockData.hostPS5
        host.state = .online
        return host
    }
    
    static var mockStandby: ConsoleHost {
        var host = MockData.hostPS4
        host.state = .standby
        return host
    }
    
    static var mockOffline: ConsoleHost {
        var host = MockData.hostPS5
        host.nickname = "Offline PS5"
        host.state = .offline
        return host
    }
}
