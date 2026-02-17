import SwiftUI
import AVFoundation

struct MeterView: View {
    @Binding var selectedIndex: Int
    @Environment(\.dismiss) private var dismiss
    @State private var camera = CameraService()
    @State private var reticlePosition: CGPoint?
    @State private var reticleVisible = false

    var body: some View {
        NavigationStack {
            ZStack {
                if camera.authorizationDenied {
                    deniedView
                } else if camera.isAuthorized {
                    cameraPreview
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Meter Exposure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                    }
                }
            }
        }
        .onAppear { camera.requestAccess() }
        .onDisappear { camera.stopSession() }
    }

    private var deniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Camera access is required to meter exposure.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        }
        .padding()
    }

    private var cameraPreview: some View {
        ZStack(alignment: .bottom) {
            CameraPreviewView(camera: camera)
                .ignoresSafeArea()
                .onTapGesture { location in
                    handleTap(location)
                }

            if reticleVisible, let pos = reticlePosition {
                ReticleView()
                    .position(pos)
            }

            VStack(spacing: 12) {
                if let speed = camera.meteredSpeed {
                    Text(speed.label)
                        .font(.title2.weight(.semibold).monospacedDigit())
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                Button {
                    if let speed = camera.meteredSpeed {
                        selectedIndex = speed.index
                    }
                    dismiss()
                } label: {
                    Text("Use This Speed")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .disabled(camera.meteredSpeed == nil)
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 24)
        }
    }

    private func handleTap(_ location: CGPoint) {
        let screenSize = UIScreen.main.bounds.size
        let normalized = CGPoint(
            x: location.x / screenSize.width,
            y: location.y / screenSize.height
        )
        camera.setExposurePoint(normalized)

        reticlePosition = location
        reticleVisible = true
        withAnimation(.easeOut(duration: 0.6)) {
            reticleVisible = false
        }
    }
}

// MARK: - Camera Preview UIViewRepresentable

struct CameraPreviewView: UIViewRepresentable {
    let camera: CameraService

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        if let layer = camera.previewLayer {
            layer.frame = view.bounds
            view.layer.addSublayer(layer)
            context.coordinator.previewLayer = layer
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.previewLayer?.frame = uiView.bounds
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

// MARK: - Reticle

struct ReticleView: View {
    @State private var scale: CGFloat = 1.5
    @State private var opacity: Double = 1.0

    var body: some View {
        Circle()
            .stroke(Color.yellow, lineWidth: 1.5)
            .frame(width: 60, height: 60)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.4)) {
                    scale = 1.0
                }
                withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                    opacity = 0
                }
            }
    }
}
