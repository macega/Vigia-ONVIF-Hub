import Foundation
import Network
import Combine

@MainActor
final class ONVIFDiscoveryManager: NSObject, ObservableObject {
    @Published private(set) var cameras: [ONVIFCamera] = []
    @Published private(set) var isSearching = false
    @Published var errorMessage: String?

    private let discoveryPort: NWEndpoint.Port = 3702
    private var connection: NWConnection?
    private var searchTask: Task<Void, Never>?

    deinit {
        searchTask?.cancel()
        connection?.cancel()
    }

    func discoverCameras(timeout: TimeInterval = 5) {
        searchTask?.cancel()
        connection?.cancel()
        connection = nil
        cameras = []
        errorMessage = nil
        isSearching = true

        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true
        parameters.serviceClass = .background

        let connection = NWConnection(
            host: NWEndpoint.Host("255.255.255.255"),
            port: discoveryPort,
            using: parameters
        )
        self.connection = connection

        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let self, let connection else { return }

            switch state {
            case .ready:
                connection.send(
                    content: Self.probeMessage.data(using: .utf8),
                    completion: .contentProcessed { [weak self] error in
                        Task { @MainActor [weak self] in
                            guard let self else { return }
                            if let error {
                                self.finish(with: "Não foi possível enviar o Probe: \(error.localizedDescription)")
                                return
                            }
                            self.receiveNextMessage(on: connection)
                        }
                    }
                )
            case .failed(let error):
                Task { @MainActor [weak self] in
                    self?.finish(with: "Falha na descoberta: \(error.localizedDescription)")
                }
            case .cancelled:
                break
            default:
                break
            }
        }

        connection.start(queue: .global(qos: .userInitiated))

        searchTask = Task { [weak self] in
            let nanoseconds = UInt64(max(timeout, 0) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.finish()
            }
        }
    }

    func stopDiscovery() {
        searchTask?.cancel()
        finish()
    }

    private func receiveNextMessage(on connection: NWConnection) {
        connection.receiveMessage { [weak self, weak connection] data, _, _, error in
            Task { @MainActor [weak self] in
                guard let self, let connection else { return }

                if let data, !data.isEmpty {
                    self.addCameras(from: data)
                }

                if error == nil, self.isSearching {
                    self.receiveNextMessage(on: connection)
                }
            }
        }
    }

    private func addCameras(from data: Data) {
        let result = ONVIFProbeResponseParser.parse(data: data)
        let urls = result.xAddrs.compactMap(URL.init(string:))
        let addresses = urls.compactMap(\.host)

        for address in Set(addresses) {
            let matchingURLs = urls.filter { $0.host == address }
            let normalizedModel = result.model?.trimmingCharacters(in: .whitespacesAndNewlines)
            let camera = ONVIFCamera(
                ipAddress: address,
                model: normalizedModel?.isEmpty == false ? normalizedModel : nil,
                xAddrs: matchingURLs
            )

            if let index = cameras.firstIndex(where: { $0.ipAddress == address }) {
                let existing = cameras[index]
                cameras[index] = ONVIFCamera(
                    id: existing.id,
                    ipAddress: address,
                    model: camera.model ?? existing.model,
                    xAddrs: Array(Set(existing.xAddrs + matchingURLs)),
                    connectionStatus: existing.connectionStatus
                )
            } else {
                cameras.append(camera)
            }
        }
    }

    private func finish(with errorMessage: String? = nil) {
        guard isSearching || errorMessage != nil else { return }
        isSearching = false
        self.errorMessage = errorMessage
        connection?.cancel()
        connection = nil
        searchTask?.cancel()
        searchTask = nil
    }

    private static let probeMessage = """
    <?xml version="1.0" encoding="UTF-8"?>
    <e:Envelope xmlns:e="http://www.w3.org/2003/05/soap-envelope"
        xmlns:w="http://schemas.xmlsoap.org/ws/2004/08/addressing"
        xmlns:d="http://schemas.xmlsoap.org/ws/2005/04/discovery"
        xmlns:dn="http://www.onvif.org/ver10/network/wsdl">
      <e:Header>
        <w:MessageID>urn:uuid:\(UUID().uuidString)</w:MessageID>
        <w:To>urn:schemas-xmlsoap-org:ws:2005:04:discovery</w:To>
        <w:Action>http://schemas.xmlsoap.org/ws/2005/04/discovery/Probe</w:Action>
      </e:Header>
      <e:Body>
        <d:Probe>
          <d:Types>dn:NetworkVideoTransmitter</d:Types>
        </d:Probe>
      </e:Body>
    </e:Envelope>
    """
}

private struct ONVIFProbeResponse {
    let xAddrs: [String]
    let model: String?
}

private final class ONVIFProbeResponseParser: NSObject, XMLParserDelegate {
    private var currentElement = ""
    private var text = ""
    private var xAddrs: [String] = []
    private var scopes: [String] = []

    static func parse(data: Data) -> ONVIFProbeResponse {
        let parserDelegate = ONVIFProbeResponseParser()
        let parser = XMLParser(data: data)
        parser.delegate = parserDelegate
        parser.parse()
        return ONVIFProbeResponse(
            xAddrs: parserDelegate.xAddrs,
            model: parserDelegate.model
        )
    }

    private var model: String? {
        let modelScope = scopes.first {
            let value = $0.lowercased()
            return value.contains("/name/") || value.contains("/hardware/")
        }
        guard let modelScope else { return nil }
        let value = modelScope.components(separatedBy: CharacterSet(charactersIn: "/")).last
        return value?.removingPercentEncoding
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName
            .split(separator: ":")
            .last
            .map(String.init) ?? elementName
        text = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch currentElement.lowercased() {
        case "xaddrs":
            xAddrs.append(contentsOf: value.split(whereSeparator: \.isWhitespace).map(String.init))
        case "scopes":
            scopes.append(contentsOf: value.split(whereSeparator: \.isWhitespace).map(String.init))
        default:
            break
        }
        currentElement = ""
        text = ""
    }
}
