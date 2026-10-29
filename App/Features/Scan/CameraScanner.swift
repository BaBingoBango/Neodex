@preconcurrency import AVFoundation
import CoreImage
import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// Runs the camera and hands a throttled stream of frames to whoever is listening: the back camera on
/// iPhone and iPad, the built-in, Continuity or USB camera the system prefers on the Mac.
@Observable
@MainActor
final class CameraScanner {
    enum Availability: Equatable {
        case unknown
        case ready
        case denied
        case noCamera
    }

    private(set) var availability: Availability = .unknown
    private(set) var isRunning = false
    private(set) var isTorchOn = false
    var hasTorch: Bool { device?.hasTorch ?? false }

    let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "Neodex.camera", qos: .userInitiated)
    private var device: AVCaptureDevice?
    private var relay: FrameRelay?
    private var configured = false
    /// Set by `start()` and cleared by `stop()`, so a start still waiting on the permission prompt
    /// doesn't turn the camera on after the scanner has been left.
    private var wanted = false

    /// Called on the main actor with at most a few frames per second.
    var onFrame: ((CameraFrame) -> Void)?

    /// Asks for permission if needed and starts the session.
    func start() async {
        wanted = true
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else { availability = .denied; return }
        default:
            availability = .denied
            return
        }
        guard wanted else { return }
        if !configured { configure() }
        guard availability == .ready, !isRunning else { return }
        isRunning = true
        let session = self.session
        queue.async { session.startRunning() }
    }

    func stop() {
        wanted = false
        guard isRunning else { return }
        isRunning = false
        setTorch(false)
        let session = self.session
        queue.async { session.stopRunning() }
    }

    /// A scanner torn down while running (a hidden tab, say) still turns the camera off.
    isolated deinit {
        guard isRunning else { return }
        let session = self.session
        queue.async { session.stopRunning() }
    }

    func toggleTorch() { setTorch(!isTorchOn) }

    private func setTorch(_ on: Bool) {
        guard let device, device.hasTorch, (try? device.lockForConfiguration()) != nil else { return }
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
        isTorchOn = on
    }

    private func configure() {
        configured = true
        guard let camera = Self.preferredCamera, let input = try? AVCaptureDeviceInput(device: camera) else {
            availability = .noCamera
            return
        }
        device = camera
        session.beginConfiguration()
        if session.canSetSessionPreset(.hd1280x720) { session.sessionPreset = .hd1280x720 }
        if session.canAddInput(input) { session.addInput(input) }
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        let relay = FrameRelay(orientation: Self.frameOrientation) { [weak self] frame in
            Task { @MainActor in self?.onFrame?(frame) }
        }
        self.relay = relay
        output.setSampleBufferDelegate(relay, queue: queue)
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()
        availability = .ready
    }

    /// The back camera on iOS; on the Mac, whichever camera the system prefers.
    private static var preferredCamera: AVCaptureDevice? {
        #if os(iOS)
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        #else
        AVCaptureDevice.systemPreferredCamera ?? AVCaptureDevice.default(for: .video)
        #endif
    }

    /// iPhone frames arrive in the sensor's landscape orientation and the app only scans in portrait;
    /// Mac cameras deliver upright frames.
    private static var frameOrientation: CGImagePropertyOrientation {
        #if os(iOS)
        .right
        #else
        .up
        #endif
    }
}

/// Receives sample buffers on the capture queue and forwards a few per second.
private nonisolated final class FrameRelay: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let handler: @Sendable (CameraFrame) -> Void
    private let orientation: CGImagePropertyOrientation
    private var lastSent = Date.distantPast
    private let interval: TimeInterval = 0.3

    init(orientation: CGImagePropertyOrientation, handler: @escaping @Sendable (CameraFrame) -> Void) {
        self.orientation = orientation
        self.handler = handler
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = Date()
        guard now.timeIntervalSince(lastSent) >= interval, let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastSent = now
        handler(CameraFrame(pixelBuffer: buffer, orientation: orientation))
    }
}

#if os(iOS)
/// The live camera image behind the scanner.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

        override func layoutSubviews() {
            super.layoutSubviews()
            if let connection = previewLayer.connection, connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
        }
    }
}
#else
/// The live camera image behind the scanner, mirrored like a webcam so framing feels natural.
struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateNSView(_ nsView: PreviewView, context: Context) {}

    final class PreviewView: NSView {
        let previewLayer = AVCaptureVideoPreviewLayer()

        override init(frame: NSRect) {
            super.init(frame: frame)
            layer = previewLayer
            wantsLayer = true
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

        override func layout() {
            super.layout()
            previewLayer.frame = bounds
            if let connection = previewLayer.connection, connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = true
            }
        }
    }
}
#endif
