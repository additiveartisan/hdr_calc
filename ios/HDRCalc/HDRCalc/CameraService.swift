import AVFoundation

enum CameraAuthState {
    case unknown
    case authorized
    case denied
}

@Observable
final class CameraService: NSObject {
    private(set) var meteredSpeed: ShutterSpeed?
    private(set) var authState: CameraAuthState = .unknown

    @ObservationIgnored private var session: AVCaptureSession?
    @ObservationIgnored private var device: AVCaptureDevice?
    @ObservationIgnored private var observation: NSKeyValueObservation?
    @ObservationIgnored private var lastUpdate = Date.distantPast
    @ObservationIgnored private var cachedPreviewLayer: AVCaptureVideoPreviewLayer?

    var previewLayer: AVCaptureVideoPreviewLayer? {
        if let cachedPreviewLayer { return cachedPreviewLayer }
        guard let session else { return nil }
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        cachedPreviewLayer = layer
        return layer
    }

    static var hasCamera: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
    }

    func requestAccess() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            authState = .authorized
            startSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.authState = granted ? .authorized : .denied
                    if granted { self?.startSession() }
                }
            }
        default:
            authState = .denied
        }
    }

    func startSession() {
        guard session == nil else { return }
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }

        let captureSession = AVCaptureSession()
        captureSession.sessionPreset = .photo

        guard let input = try? AVCaptureDeviceInput(device: camera) else { return }
        guard captureSession.canAddInput(input) else { return }
        captureSession.addInput(input)

        device = camera
        session = captureSession

        observation = camera.observe(\.exposureDuration, options: [.new]) { [weak self] cam, _ in
            let seconds = CMTimeGetSeconds(cam.exposureDuration)
            guard seconds > 0, seconds.isFinite else { return }
            DispatchQueue.main.async {
                guard let self else { return }
                let now = Date()
                guard now.timeIntervalSince(self.lastUpdate) > 0.15 else { return }
                self.lastUpdate = now
                let speed = nearestSpeed(seconds: seconds)
                if speed.index != self.meteredSpeed?.index {
                    self.meteredSpeed = speed
                }
            }
        }

        DispatchQueue.global(qos: .userInitiated).async {
            captureSession.startRunning()
        }
    }

    func stopSession() {
        observation?.invalidate()
        observation = nil
        session?.stopRunning()
        session = nil
        device = nil
        cachedPreviewLayer = nil
    }

    func clearReading() {
        meteredSpeed = nil
    }

    func setExposurePoint(layerPoint: CGPoint) {
        guard let device, device.isExposurePointOfInterestSupported,
              let layer = previewLayer else { return }
        let devicePoint = layer.captureDevicePointConverted(fromLayerPoint: layerPoint)
        do {
            try device.lockForConfiguration()
            device.exposurePointOfInterest = devicePoint
            device.exposureMode = .autoExpose
            device.unlockForConfiguration()
        } catch {
            assertionFailure("lockForConfiguration failed: \(error)")
        }
    }
}
