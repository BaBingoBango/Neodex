@preconcurrency import AVFoundation
import CoreImage
import SwiftUI
import UIKit

/// Runs the back camera and hands a throttled stream of frames to whoever is listening.
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

    /// Called on the main actor with at most a few frames per second.
    var onFrame: ((CameraFrame) -> Void)?

    /// Asks for permission if needed and starts the session.
    func start() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else { availability = .denied; return }
        default:
            availability = .denied
            return
        }
        if !configured { configure() }
        guard availability == .ready, !isRunning else { return }
        isRunning = true
        let session = self.session
        queue.async { session.startRunning() }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        setTorch(false)
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
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            availability = .noCamera
            return
        }
        device = camera
        session.beginConfiguration()
        session.sessionPreset = .hd1280x720
        if session.canAddInput(input) { session.addInput(input) }
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        let relay = FrameRelay { [weak self] frame in
            Task { @MainActor in self?.onFrame?(frame) }
        }
        self.relay = relay
        output.setSampleBufferDelegate(relay, queue: queue)
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()
        availability = .ready
    }
}

/// Receives sample buffers on the capture queue and forwards a few per second.
private nonisolated final class FrameRelay: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let handler: @Sendable (CameraFrame) -> Void
    private var lastSent = Date.distantPast
    private let interval: TimeInterval = 0.3

    init(handler: @escaping @Sendable (CameraFrame) -> Void) {
        self.handler = handler
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = Date()
        guard now.timeIntervalSince(lastSent) >= interval, let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastSent = now
        // Frames arrive in the sensor's landscape orientation; the app only scans in portrait.
        handler(CameraFrame(pixelBuffer: buffer, orientation: .right))
    }
}

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
