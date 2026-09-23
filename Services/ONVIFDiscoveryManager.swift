import Foundation
import Network
import Combine

class ONVIFDiscoveryManager: ObservableObject {
    @Published var discoveredCameras: [ONVIFCamera] = []
    @Published var isSearching: Bool = false
    
    private var connection: NWConnection?
    private let multicastAddress = "239.255.255.250"
    private let port: NWEndpoint.Port = 3702
    private var searchTimer: Timer?
    
    func startDiscovery() {
        guard !isSearching else { return }
        
        isSearching = true
        discoveredCameras.removeAll()
        
        let host = NWEndpoint.Host(multicastAddress)
        let parameters = NWParameters.udp
        
        // Permite broadcast se necessário, embora WS-Discovery use Multicast
        if let ipOptions = parameters.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            ipOptions.version = .ipv4
        }
        
        connection = NWConnection(host: host, port: port, using: parameters)
        
        connection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.sendProbe()
                self?.receiveResponses()
            case .failed(let error):
                print("Conexão falhou: \(error)")
                self?.stopDiscovery()
            default:
                break
            }
        }
        
        connection?.start(queue: .main)
        
        // Timeout de busca após 5 segundos
        searchTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            self?.stopDiscovery()
        }
    }
    
    func stopDiscovery() {
        isSearching = false
        connection?.cancel()
        connection = nil
        searchTimer?.invalidate()
        searchTimer = nil
    }
    
    private func sendProbe() {
        let messageId = UUID().uuidString.lowercased()
        let soapPayload = """
        <?xml version="1.0" encoding="UTF-8"?>
        <e:Envelope xmlns:e="http://www.w3.org/2003/05/soap-envelope"
                    xmlns:w="http://schemas.xmlsoap.org/ws/2004/08/addressing"
                    xmlns:d="http://schemas.xmlsoap.org/ws/2004/08/discovery"
                    xmlns:dn="http://www.onvif.org/ver10/network/wsdl">
            <e:Header>
                <w:MessageID>uuid:\(messageId)</w:MessageID>
                <w:To>urn:schemas-xmlsoap-org:ws:2004:08:discovery</w:To>
                <w:Action>http://schemas.xmlsoap.org/ws/2004/08/discovery/Probe</w:Action>
            </e:Header>
            <e:Body>
                <d:Probe>
                    <d:Types>dn:NetworkVideoTransmitter</d:Types>
                </d:Probe>
            </e:Body>
        </e:Envelope>
        """
        
        let data = soapPayload.data(using: .utf8)
        connection?.send(content: data, completion: .contentProcessed({ error in
            if let error = error {
                print("Erro ao enviar Probe: \(error)")
            }
        }))
    }
    
    private func receiveResponses() {
        connection?.receiveMessage { [weak self] (data, context, isComplete, error) in
            if let data = data, !data.isEmpty {
                self?.parseResponse(data: data)
            }
            
            if self?.isSearching == true && error == nil {
                self?.receiveResponses() // Continua ouvindo enquanto estiver buscando
            }
        }
    }
    
    private func parseResponse(data: Data) {
        guard let xmlString = String(data: data, encoding: .utf8) else { return }
        
        // Extração simples via Regex para o protótipo
        let xAddrs = extractValues(from: xmlString, tag: "d:XAddrs")
        let scopes = extractValues(from: xmlString, tag: "d:Scopes")
        
        // Tenta encontrar o IP na URL do XAddrs
        for xAddr in xAddrs {
            if let url = URL(string: xAddr), let host = url.host {
                // Evita duplicados
                DispatchQueue.main.async {
                    if !self.discoveredCameras.contains(where: { $0.ipAddress == host }) {
                        let model = self.parseModel(from: scopes)
                        let newCamera = ONVIFCamera(ipAddress: host, model: model, xAddrs: [url])
                        self.discoveredCameras.append(newCamera)
                    }
                }
            }
        }
    }
    
    private func extractValues(from xml: String, tag: String) -> [String] {
        let pattern = "<\(tag)>(.*?)</\(tag)>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        
        let nsString = xml as NSString
        let matches = regex.matches(in: xml, options: [], range: NSRange(location: 0, length: nsString.length))
        
        return matches.compactMap { match in
            if match.numberOfRanges > 1 {
                let value = nsString.substring(with: match.range(at: 1))
                return value.components(separatedBy: " ") // XAddrs e Scopes podem ser listas separadas por espaço
            }
            return nil
        }.flatMap { $0 }
    }
    
    private func parseModel(from scopes: [String]) -> String {
        // Scopes do ONVIF costumam ter o formato onvif://www.onvif.org/name/Modelo_Da_Camera
        for scope in scopes {
            if scope.contains("/name/") {
                return scope.components(separatedBy: "/name/").last?.replacingOccurrences(of: "_", with: " ") ?? "Câmera ONVIF"
            }
        }
        return "Câmera ONVIF"
    }
}
