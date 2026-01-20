import Foundation

enum HostState: String, Codable, CaseIterable {
    case online
    case standby
    case offline
    case unknown
}

enum ConsoleType: String, Codable, CaseIterable {
    case ps4
    case ps5
}

/// Host model
struct ConsoleHost: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var nickname: String
    var address: String
    var macAddress: String
    var systemVersion: String?
    var isPS5: Bool
    var registKey: Data
    var rpKey: Data
    var rpKeyType: UInt32
    
    // Last successful connection time
    var lastConnectedAt: Date?
    
    // Transient state (not persisted)
    var state: HostState = .offline
    
    var isRegistered: Bool {
        !registKey.isEmpty
    }
    
    var consoleType: ConsoleType {
        isPS5 ? .ps5 : .ps4
    }

    enum CodingKeys: String, CodingKey {
        case id
        case nickname
        case address
        case macAddress
        case systemVersion
        case isPS5
        case registKey
        case rpKey
        case rpKeyType
        case lastConnectedAt
    }

    init(
        id: UUID = UUID(),
        nickname: String,
        address: String,
        macAddress: String = "",
        systemVersion: String? = nil,
        isPS5: Bool = true,
        registKey: Data = Data(),
        rpKey: Data = Data(),
        rpKeyType: UInt32 = 0,
        lastConnectedAt: Date? = nil
    ) {
        self.id = id
        self.nickname = nickname
        self.address = address
        self.macAddress = macAddress
        self.systemVersion = systemVersion
        self.isPS5 = isPS5
        self.registKey = registKey
        self.rpKey = rpKey
        self.rpKeyType = rpKeyType
        self.lastConnectedAt = lastConnectedAt
    }
}
