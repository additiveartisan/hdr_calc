import SwiftUI
import AVFoundation

enum MeterPhase {
    case shadow, highlight
}

struct MeterView: View {
    @Binding var shadowIndex: Int
    @Binding var highlightIndex: Int
    @Environment(\.dismiss) private var dismiss
    @State private var phase: MeterPhase = .shadow
    @State private var camera = CameraService()
    @State private var reticlePosition: CGPoint?
    @State private var reticleVisible = false

    private var navTitle: String {
        switch phase {
        case .shadow:    return "Step 1 of 2: Meter Shadows"
        case .highlight: return "Step 2 of 2: Meter Highlights"
        }
    }

    private var instruction: String {
        switch phase {
        case .shadow:    return "Tap the darkest area"
        case .highlight: return "Tap the brightest area"
        }
    }

    private var confirmLabel: String {
        switch phase {
        case .shadow:    return "Use for Shadows"
        case .highlight: return "Use for Highlights"
        }
    }

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
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        switch phase {
                        case .shadow:
                            dismiss()
                        case .highlight:
                            camera.meteredSpeed = nil
                            phase = .shadow
                        }
                    } label: {
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
                Text(instruction)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())

                if let speed = camera.meteredSpeed {
                    Text(speed.label)
                        .font(.title2.weight(.semibold).monospacedDigit())
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                }

                Button {
                    confirmAction()
                } label: {
                    HStack {
                        Image(systemName: "camera.metering.spot")
                        Text(confirmLabel)
                    }
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .tint(.accentColor)
                .disabled(camera.meteredSpeed == nil)
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 24)
        }
    }

    private func confirmAction() {
        guard let speed = camera.meteredSpeed else { return }
        switch phase {
        case .shadow:
            shadowIndex = speed.index
            camera.meteredSpeed = nil
            phase = .highlight
        case .highlight:
            highlightIndex = speed.index
            dismiss()
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
