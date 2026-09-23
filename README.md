# Vigia ONVIF Hub

## Fase 1: descoberta de câmeras

Os arquivos Swift desta fase estão em `ONVIF/`:

- `ONVIFCamera.swift`: modelo da câmera e estados de conexão.
- `ONVIFDiscoveryManager.swift`: Probe WS-Discovery via UDP broadcast para `255.255.255.255:3702`.
- `DiscoveryView.swift`: tela SwiftUI para iniciar a busca e listar as câmeras.

### Integração no Xcode

Adicione os três arquivos ao target do aplicativo (`Target Membership` habilitado). No
`Info.plist` do target, inclua:

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>O Vigia ONVIF Hub precisa acessar a rede local para encontrar suas câmeras.</string>
```

No editor de propriedades do Xcode, essa chave aparece como **Privacy - Local Network
Usage Description**. Não é necessário adicionar uma permissão de localização: a descoberta
usa a rede local diretamente. O sistema exibirá o alerta de rede local na primeira tentativa
de comunicação.

Apresente `DiscoveryView()` como a tela inicial, por exemplo:

```swift
@main
struct VigiaONVIFHubApp: App {
    var body: some Scene {
        WindowGroup {
            DiscoveryView()
        }
    }
}
```