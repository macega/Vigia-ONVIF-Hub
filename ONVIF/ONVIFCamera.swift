import Foundation

enum ONVIFConnectionStatus: String, Equatable {
    case discovered = "Encontrada"
    case connecting = "Conectando"
    case connected = "Conectada"
    case unavailable = "Indisponível"
}

struct ONVIFCamera: Identifiable, Equatable {
    let id: UUID
    let ipAddress: String
    let model: String?
    let xAddrs: [URL]
    var connectionStatus: ONVIFConnectionStatus

    init(
        id: UUID = UUID(),
        ipAddress: String,
        model: String? = nil,
        xAddrs: [URL] = [],
        connectionStatus: ONVIFConnectionStatus = .discovered
    ) {
        self.id = id
        self.ipAddress = ipAddress
        self.model = model
        self.xAddrs = xAddrs
        self.connectionStatus = connectionStatus
    }
}
