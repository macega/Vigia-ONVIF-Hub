# Instruções de Integração - Vigia ONVIF Hub

Os arquivos foram organizados em pastas para facilitar a importação no seu projeto Xcode.

## 1. Estrutura de Arquivos
- `Models/ONVIFCamera.swift`: Estrutura de dados da câmera.
- `Services/ONVIFDiscoveryManager.swift`: Lógica de rede (UDP Broadcast/Multicast).
- `Views/DiscoveryView.swift`: Interface SwiftUI.

## 2. Permissões Necessárias (Info.plist)
Para que o aplicativo possa escanear a rede local, você **precisa** adicionar as seguintes chaves ao seu arquivo `Info.plist`:

1. **NSLocalNetworkUsageDescription**:
   - Chave: `Privacy - Local Network Usage Description`
   - Valor: "Este aplicativo precisa acessar sua rede local para descobrir câmeras IP ONVIF."

2. **Bonjour Services** (Opcional mas recomendado para ONVIF):
   - Chave: `Bonjour services`
   - Adicione os itens: `_onvif._tcp` e `_http._tcp`.

## 3. Entitlements (Capacidades)
Se você estiver testando em um dispositivo físico, o uso de Multicast (UDP 239.255.255.250) pode exigir a permissão especial da Apple:
- Vá em **Signing & Capabilities**.
- Adicione **App Sandbox** (se for macOS) ou verifique se o **Multicast Networking** está habilitado (exige direito solicitado à Apple para apps em produção).
- Para desenvolvimento local, geralmente a permissão de rede local (item 2 acima) é suficiente para o primeiro prompt ao usuário.

## 4. Como Usar
No seu `App.swift` ou na sua View principal, basta instanciar a `DiscoveryView()`:

```swift
@main
struct VigiaApp: App {
    var body: some Scene {
        WindowGroup {
            DiscoveryView()
        }
    }
}
```

## Notas Técnicas
- O `ONVIFDiscoveryManager` utiliza o framework `Network` da Apple, que é moderno e eficiente.
- A descoberta dura 5 segundos e desliga automaticamente o socket para economizar bateria.
- A extração de dados XML usa Regex para manter o código enxuto e sem dependências externas.
