//
//  ContentView.swift
//  Scope Lens
//
//  A one-window OCR spike: drop or open a screenshot, run Vision text
//  recognition, and show the recognized strings, their confidences, and their
//  bounding boxes overlaid on the image.
//

import SwiftUI
import UniformTypeIdentifiers
import Combine

// MARK: - View model

@MainActor
final class OCRViewModel: ObservableObject {
    @Published private(set) var image: RecognizedImage?
    @Published private(set) var isProcessing = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var fileName: String?

    private let service = OCRService()

    /// Starts a new recognition pass for the image at `url`.
    func load(url: URL) {
        fileName = url.lastPathComponent
        errorMessage = nil
        isProcessing = true

        Task {
            // Opened / dropped files are sandbox-scoped; hold access while reading.
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }

            do {
                image = try await service.recognizeText(at: url)
            } catch {
                image = nil
                errorMessage = error.localizedDescription
            }
            isProcessing = false
        }
    }
}

// MARK: - Root view

struct ContentView: View {
    @StateObject private var model = OCRViewModel()
    @State private var isDropTargeted = false
    @State private var isImporting = false
    @State private var selection: RecognizedText.ID?

    var body: some View {
        HSplitView {
            imagePane
                .frame(minWidth: 380, minHeight: 380)
            resultsPane
                .frame(minWidth: 280, maxWidth: 480)
        }
        .frame(minWidth: 820, minHeight: 520)
        .toolbar { toolbarContent }
        .fileImporter(isPresented: $isImporting,
                      allowedContentTypes: [.image],
                      allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                selection = nil
                model.load(url: url)
            }
        }
        // The whole window accepts a dropped image file.
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            selection = nil
            model.load(url: url)
            return true
        } isTargeted: { isDropTargeted = $0 }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                isImporting = true
            } label: {
                Label("Open Image…", systemImage: "photo.badge.plus")
            }
        }
        ToolbarItem(placement: .status) {
            statusLabel
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        if model.isProcessing {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Recognizing…")
            }
            .foregroundStyle(.secondary)
        } else if let fileName = model.fileName, let image = model.image {
            Text("\(fileName) · \(image.results.count) string\(image.results.count == 1 ? "" : "s")")
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    // MARK: Image pane

    @ViewBuilder
    private var imagePane: some View {
        ZStack {
            Rectangle().fill(.background)
            if let image = model.image {
                ImageBoxesView(image: image, highlighted: selection)
            } else {
                DropPlaceholder(isTargeted: isDropTargeted) { isImporting = true }
            }
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.accentColor,
                                  style: StrokeStyle(lineWidth: 3, dash: [9]))
                    .padding(6)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Results pane

    @ViewBuilder
    private var resultsPane: some View {
        Group {
            if let error = model.errorMessage {
                ContentUnavailableView {
                    Label("Couldn't Read Image", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                }
            } else if let image = model.image {
                if image.results.isEmpty {
                    ContentUnavailableView("No Text Found",
                                           systemImage: "text.magnifyingglass",
                                           description: Text("Vision didn't recognize any text in this image."))
                } else {
                    List(selection: $selection) {
                        ForEach(orderedResults(image.results)) { item in
                            ResultRow(item: item).tag(item.id)
                        }
                    }
                    .listStyle(.inset)
                }
            } else {
                ContentUnavailableView("No Image",
                                       systemImage: "photo",
                                       description: Text("Drop a screenshot here, or use Open Image…"))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Presents results in natural reading order (top to bottom). Vision's y
    /// axis points up, so a larger `maxY` sits higher on screen.
    private func orderedResults(_ results: [RecognizedText]) -> [RecognizedText] {
        results.sorted { $0.boundingBox.maxY > $1.boundingBox.maxY }
    }
}

// MARK: - Image + bounding boxes

/// Draws the image with each recognized bounding box overlaid in the correct
/// position, accounting for aspect-fit scaling and Vision's bottom-left origin.
private struct ImageBoxesView: View {
    let image: RecognizedImage
    var highlighted: RecognizedText.ID?

    var body: some View {
        GeometryReader { geo in
            let content = Self.fittedRect(for: image.pixelSize, in: geo.size)
            ZStack(alignment: .topLeading) {
                Image(decorative: image.cgImage, scale: 1, orientation: .up)
                    .resizable()
                    .frame(width: content.width, height: content.height)
                    .position(x: content.midX, y: content.midY)

                ForEach(image.results) { item in
                    boxView(for: item, in: content)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .padding(10)
        .animation(.easeInOut(duration: 0.15), value: highlighted)
    }

    @ViewBuilder
    private func boxView(for item: RecognizedText, in content: CGRect) -> some View {
        let rect = Self.viewRect(for: item.boundingBox, in: content)
        let isHighlighted = item.id == highlighted
        ZStack {
            if isHighlighted {
                Rectangle().fill(Color.orange.opacity(0.18))
            }
            Rectangle()
                .stroke(isHighlighted ? Color.orange : Color.green,
                        lineWidth: isHighlighted ? 2.5 : 1.5)
        }
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
    }

    /// Aspect-fit rect for an image of `pixelSize`, centered within `available`.
    static func fittedRect(for pixelSize: CGSize, in available: CGSize) -> CGRect {
        guard pixelSize.width > 0, pixelSize.height > 0,
              available.width > 0, available.height > 0 else {
            return CGRect(origin: .zero, size: available)
        }
        let scale = min(available.width / pixelSize.width,
                        available.height / pixelSize.height)
        let size = CGSize(width: pixelSize.width * scale, height: pixelSize.height * scale)
        let origin = CGPoint(x: (available.width - size.width) / 2,
                             y: (available.height - size.height) / 2)
        return CGRect(origin: origin, size: size)
    }

    /// Maps a Vision normalized rect (origin bottom-left) into `content`'s
    /// top-left coordinate space.
    static func viewRect(for normalized: CGRect, in content: CGRect) -> CGRect {
        let x = content.minX + normalized.minX * content.width
        // Flip y: Vision's top edge sits (1 - maxY) down from the image top.
        let y = content.minY + (1 - normalized.maxY) * content.height
        return CGRect(x: x, y: y,
                      width: normalized.width * content.width,
                      height: normalized.height * content.height)
    }
}

// MARK: - Rows & placeholder

private struct ResultRow: View {
    let item: RecognizedText

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(item.string)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            ConfidenceBadge(confidence: item.confidence)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(item.string), confidence \(Int((item.confidence * 100).rounded())) percent"))
    }
}

private struct ConfidenceBadge: View {
    let confidence: Float

    var body: some View {
        Text(Double(confidence), format: .percent.precision(.fractionLength(0)))
            .font(.caption.monospacedDigit())
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
            .help("Recognition confidence")
    }

    private var color: Color {
        switch confidence {
        case 0.9...: .green
        case 0.5..<0.9: .orange
        default: .red
        }
    }
}

private struct DropPlaceholder: View {
    let isTargeted: Bool
    var onBrowse: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)
            Text("Drop a screenshot here")
                .font(.title3.weight(.medium))
            Text("or")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            Button("Open Image…", action: onBrowse)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .opacity(isTargeted ? 0.4 : 1)
    }
}

#Preview {
    ContentView()
}
