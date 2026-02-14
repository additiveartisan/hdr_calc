import AVFoundation
import Combine

@Observable
final class CameraService: NSObject {
    var meteredSpeed: ShutterSpeed?
    var isAuthorized = false
    var authorizationDenied = false

    private var session: AVCaptureSession?
    private var device: AVCaptureDevice?
    private var observation: NSKeyValueObservation?
    private var lastUpdate = Date.distantPast

    var previewLayer: AVCaptureVideoPreviewLayer? {
        guard let session else { return nil }
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        return layer
    }

    static var hasCamera: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
    }

    func requestAccess() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            startSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    self?.authorizationDenied = !granted
                    if granted { self?.startSession() }
                }
            }
        default:
            authorizationDenied = true
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
            guard let self else { return }
            let now = Date()
            guard now.timeIntervalSince(self.lastUpdate) > 0.15 else { return }
            self.lastUpdate = now
            let seconds = CMTimeGetSeconds(cam.exposureDuration)
            guard seconds > 0, seconds.isFinite else { return }
            let speed = nearestSpeed(seconds: seconds)
            DispatchQueue.main.async {
                self.meteredSpeed = speed
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
    }

    func setExposurePoint(_ point: CGPoint) {
        guard let device, device.isExposurePointOfInterestSupported else { return }
        do {
            try device.lockForConfiguration()
            device.exposurePointOfInterest = point
            device.exposureMode = .autoExpose
            device.unlockForConfiguration()
        } catch {}
    }
}
