import Foundation

struct ONVIFCamera: Identifiable, Hashable {
    let id: UUID
    let ipAddress: String
    let model: String
    let xAddrs: [URL]
    var status: ConnectionStatus
    
    enum ConnectionStatus: String, Codable {
        case discovered = "Descoberta"
        case connecting = "Conectando"
        case connected = "Conectado"
        case offline = "Offline"
    }
    
    init(id: UUID = UUID(), ipAddress: String, model: String = "Câmera Genérica", xAddrs: [URL] = [], status: ConnectionStatus = .discovered) {
        self.id = id
        self.ipAddress = ipAddress
        self.model = model
        self.xAddrs = xAddrs
        self.status = status
    }
}
