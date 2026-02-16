import SwiftUI

struct CameraConnectView: View {
    @Environment(CameraConnectionService.self) private var service
    @Environment(\.dismiss) private var dismiss
    @State private var wasConnectedOnAppear = false

    var body: some View {
        @Bindable var service = service

        NavigationStack {
            Group {
                switch service.connectionState {
                case .disconnected:
                    startView
                case .discovering:
                    discoveryView
                case .connecting(let camera):
                    connectingView(camera: camera)
                case .modeCheck(let camera):
                    modeCheckView(camera: camera)
                case .connected(let camera):
                    connectedView(camera: camera)
                case .wrongMode(let camera, _):
                    wrongModeView(camera: camera)
                case .error(let message):
                    errorView(message: message)
                }
            }
            .navigationTitle("Connect Camera")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                }
            }
        }
        .tint(.accentColor)
        .onAppear {
            if case .connected = service.connectionState {
                wasConnectedOnAppear = true
            }
        }
        .onChange(of: service.connectionState) { _, newValue in
            if case .connected = newValue, !wasConnectedOnAppear {
                Task {
                    try? await Task.sleep(for: .seconds(0.75))
                    dismiss()
                }
            }
        }
    }

    // MARK: - States

    private var startView: some View {
        VStack(spacing: Theme.sectionGap) {
            Spacer()
            Image(systemName: "wifi")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Connect to a Sony camera over WiFi to control bracketed shooting remotely.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, Theme.pagePadding)
            Button("Start Discovery") {
                service.startDiscovery()
            }
            .buttonStyle(.bordered)
            Spacer()
        }
    }

    private var discoveryView: some View {
        VStack(spacing: Theme.cardGap) {
            if service.discoveredCameras.isEmpty {
                Spacer()
                ProgressView()
                Text("Searching for cameras...")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                List(service.discoveredCameras) { camera in
                    Button {
                        service.connect(to: camera)
                    } label: {
                        HStack {
                            Image(systemName: "camera")
                                .foregroundStyle(.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(camera.name)
                                    .font(.body.weight(.medium))
                                Text(camera.address)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func connectingView(camera: DiscoveredCamera) -> some View {
        VStack(spacing: Theme.cardGap) {
            Spacer()
            ProgressView()
            Text("Connecting to \(camera.name)...")
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func modeCheckView(camera: DiscoveredCamera) -> some View {
        VStack(spacing: Theme.cardGap) {
            Spacer()
            ProgressView()
            Text("Checking camera mode...")
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func connectedView(camera: DiscoveredCamera) -> some View {
        VStack(spacing: Theme.sectionGap) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("Connected")
                .font(.title3.weight(.semibold))
            Text(camera.name)
                .foregroundStyle(.secondary)
            Button("Disconnect") {
                service.disconnect()
                dismiss()
            }
            .foregroundStyle(.red)
            Spacer()
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: Theme.sectionGap) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("Connection Failed")
                .font(.title3.weight(.semibold))
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, Theme.pagePadding)
            Button("Try Again") {
                service.retry()
            }
            .buttonStyle(.bordered)
            Spacer()
        }
    }
}

#Preview {
    CameraConnectView()
        .environment(CameraConnectionService())
}
