//
//  OCRService.swift
//  Scope Lens
//
//  Runs Apple Vision text recognition on an image and returns the recognized
//  strings, their confidences, and their bounding boxes.
//

import Foundation
import Vision
import CoreImage
import ImageIO
import CoreGraphics

/// A single piece of text recognized by Vision.
///
/// `boundingBox` is in Vision's normalized coordinate space: values run 0...1
/// with the origin at the **bottom-left** of the image (y increases upward).
/// Views that draw in a top-left space (like SwiftUI) must flip the y axis.
struct RecognizedText: Identifiable, Hashable {
    let id = UUID()
    let string: String
    let confidence: Float       // 0...1 (1 = most confident)
    let boundingBox: CGRect     // normalized 0...1, origin bottom-left
}

/// A decoded (upright) image together with everything Vision found in it.
struct RecognizedImage {
    let cgImage: CGImage
    let results: [RecognizedText]

    /// Pixel dimensions, used to preserve aspect ratio when drawing.
    var pixelSize: CGSize { CGSize(width: cgImage.width, height: cgImage.height) }
}

/// Errors thrown while preparing an image for recognition.
enum OCRError: LocalizedError {
    case unreadableImage(URL)

    var errorDescription: String? {
        switch self {
        case .unreadableImage(let url):
            return "Couldn't read an image from '\(url.lastPathComponent)'."
        }
    }
}

/// A small wrapper around `VNRecognizeTextRequest`.
///
/// All work (decoding and recognition) runs on a background queue so the UI
/// stays responsive; the result is delivered via async/await.
struct OCRService {

    /// Loads an image file, corrects its orientation, and recognizes text in it.
    func recognizeText(at url: URL) async throws -> RecognizedImage {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let cgImage = try Self.loadUprightImage(at: url)
                    let results = try Self.performRecognition(on: cgImage)
                    continuation.resume(returning: RecognizedImage(cgImage: cgImage, results: results))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Synchronous Vision text recognition. Must be called off the main thread.
    static func performRecognition(on cgImage: CGImage) throws -> [RecognizedText] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        // Game text is proper nouns / invented terms, so dictionary-based
        // language correction would introduce errors rather than fix them.
        request.usesLanguageCorrection = false

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        return (request.results ?? []).compactMap { observation -> RecognizedText? in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            return RecognizedText(string: candidate.string,
                                  confidence: candidate.confidence,
                                  boundingBox: observation.boundingBox)
        }
    }

    // MARK: - Image loading

    /// Decodes an image and bakes in its EXIF orientation so the pixels are
    /// upright. Vision's boxes and the on-screen image then share one coordinate
    /// space, which keeps the overlay aligned even for rotated sources.
    private static func loadUprightImage(at url: URL) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw OCRError.unreadableImage(url)
        }

        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let rawOrientation = (properties?[kCGImagePropertyOrientation] as? UInt32) ?? 1
        guard let orientation = CGImagePropertyOrientation(rawValue: rawOrientation),
              orientation != .up else {
            return cgImage
        }

        let oriented = CIImage(cgImage: cgImage).oriented(orientation)
        let context = CIContext()
        return context.createCGImage(oriented, from: oriented.extent) ?? cgImage
    }
}
