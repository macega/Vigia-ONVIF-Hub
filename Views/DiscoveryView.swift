import SwiftUI

struct DiscoveryView: View {
    @StateObject private var discoveryManager = ONVIFDiscoveryManager()
    
    var body: some View {
        NavigationView {
            VStack {
                // Cabeçalho com botão de busca
                Button(action: {
                    discoveryManager.startDiscovery()
                }) {
                    HStack {
                        if discoveryManager.isSearching {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .padding(.trailing, 5)
                        } else {
                            Image(systemName: "magnifyingglass")
                        }
                        Text(discoveryManager.isSearching ? "Buscando..." : "Buscar Câmeras na Rede")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(discoveryManager.isSearching ? Color.gray : Color.blue)
                    .cornerRadius(12)
                }
                .disabled(discoveryManager.isSearching)
                .padding()
                
                // Lista de resultados
                List(discoveryManager.discoveredCameras) { camera in
                    HStack(alignment: .center, spacing: 15) {
                        Image(systemName: "video.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                            .frame(width: 40)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(camera.model)
                                .font(.headline)
                            Text("IP: \(camera.ipAddress)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(camera.status.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(InsetGroupedListStyle())
                
                if discoveryManager.discoveredCameras.isEmpty && !discoveryManager.isSearching {
                    VStack(spacing: 20) {
                        Image(systemName: "camera.badge.ellipsis")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("Nenhuma câmera encontrada ainda.")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .navigationTitle("Vigia ONVIF")
        }
    }
}

struct DiscoveryView_Previews: PreviewProvider {
    static var previews: some View {
        DiscoveryView()
    }
}
