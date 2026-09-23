import SwiftUI

struct DiscoveryView: View {
    @StateObject private var discoveryManager = ONVIFDiscoveryManager()

    var body: some View {
        NavigationStack {
            Group {
                if discoveryManager.isSearching && discoveryManager.cameras.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                            .controlSize(.large)
                        Text("Procurando câmeras na rede local…")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if discoveryManager.cameras.isEmpty {
                    ContentUnavailableView(
                        "Nenhuma câmera encontrada",
                        systemImage: "video.slash",
                        description: Text("Toque em “Buscar Câmeras na Rede” para iniciar.")
                    )
                } else {
                    List(discoveryManager.cameras) { camera in
                        HStack(spacing: 14) {
                            Image(systemName: "video.fill")
                                .font(.title2)
                                .foregroundStyle(.tint)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(camera.ipAddress)
                                    .font(.headline)
                                Text(camera.model ?? "Câmera ONVIF")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(camera.connectionStatus.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 5)
                    }
                    .overlay {
                        if discoveryManager.isSearching {
                            ProgressView("Aguardando respostas…")
                                .padding()
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
            .navigationTitle("Vigia ONVIF Hub")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if discoveryManager.isSearching {
                            discoveryManager.stopDiscovery()
                        } else {
                            discoveryManager.discoverCameras()
                        }
                    } label: {
                        Label(
                            discoveryManager.isSearching ? "Parar" : "Buscar Câmeras na Rede",
                            systemImage: discoveryManager.isSearching ? "stop.fill" : "magnifyingglass"
                        )
                    }
                }
            }
            .safeAreaInset(edge: .top) {
                Button {
                    discoveryManager.discoverCameras()
                } label: {
                    Label("Buscar Câmeras na Rede", systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .alert(
                "Erro na descoberta",
                isPresented: Binding(
                    get: { discoveryManager.errorMessage != nil },
                    set: { if !$0 { discoveryManager.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(discoveryManager.errorMessage ?? "")
            }
        }
    }
}

#Preview {
    DiscoveryView()
}
