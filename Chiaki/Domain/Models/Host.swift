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
struct ConsoleHost: Identifiable, Codable, Equatable {
    let id: UUID
    var nickname: String
    var address: String
    var macAddress: String
    var isPS5: Bool
    var registKey: UInt64
    var rpKey: Data
    var rpKeyType: UInt32
    
    // Transient state (not persisted)
    var state: HostState = .offline
    
    var isRegistered: Bool {
        registKey != 0
    }
    
    var consoleType: ConsoleType {
        isPS5 ? .ps5 : .ps4
    }

    enum CodingKeys: String, CodingKey {
        case id
        case nickname
        case address
        case macAddress
        case isPS5
        case registKey
        case rpKey
        case rpKeyType
    }

    init(
        id: UUID = UUID(),
        nickname: String,
        address: String,
        macAddress: String = "",
        isPS5: Bool = true,
        registKey: UInt64 = 0,
        rpKey: Data = Data(),
        rpKeyType: UInt32 = 0
    ) {
        self.id = id
        self.nickname = nickname
        self.address = address
        self.macAddress = macAddress
        self.isPS5 = isPS5
        self.registKey = registKey
        self.rpKey = rpKey
        self.rpKeyType = rpKeyType
    }
}
