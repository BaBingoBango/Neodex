import NeodexKit
import os
import PhotosUI
import SwiftUI

/// The Pokédex scanner: point the camera at a Pokémon, a card or a screen and the dex entry lights up.
struct ScanView: View {
    @Environment(\.database) private var database
    @Environment(\.scenePhase) private var scenePhase

    @State private var scanner = CameraScanner()
    @State private var model = ScanModel()
    @State private var photoItem: PhotosPickerItem?
    @State private var cryPlayer = CryPlayer()
    @State private var lockPulse = false

    var body: some View {
        ZStack {
            background
            overlay
        }
        .navigationTitle("Scanner")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if scanner.hasTorch {
                    Button(scanner.isTorchOn ? "Torch Off" : "Torch On", systemImage: scanner.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill") {
                        scanner.toggleTorch()
                    }
                }
            }
        }
        .task {
            model.configure(database: database)
            await PokemonRecognizer.shared.prepare()
            scanner.onFrame = { frame in model.consume(frame) }
            await scanner.start()
        }
        .onDisappear { scanner.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await scanner.start() } } else { scanner.stop() }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            photoItem = nil
            Task { await model.scan(item) }
        }
        .onChange(of: model.locked?.pokemonID) { _, pokemonID in
            guard let pokemonID, let pokemon = database.pokemon(id: pokemonID) else { return }
            lockPulse.toggle()
            cryPlayer.play(pokemon)
        }
        .sensoryFeedback(.success, trigger: lockPulse)
    }

    // MARK: Layers

    @ViewBuilder
    private var background: some View {
        if scanner.availability == .ready {
            CameraPreview(session: scanner.session).ignoresSafeArea()
        } else {
            LinearGradient(colors: [.black, Color(.darkGray)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
        }
        if let photo = model.photo {
            Image(decorative: photo, scale: 1)
                .resizable()
                .scaledToFit()
                .padding(.bottom, 240)
                .background(.black.opacity(0.75))
                .ignoresSafeArea()
                .transition(.opacity)
        }
    }

    private var overlay: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            if model.photo == nil, scanner.availability == .ready {
                Reticle(locked: model.locked != nil)
                    .frame(width: 240, height: 240)
                    .padding(.bottom, 24)
            }
            Spacer(minLength: 0)
            panel
        }
    }

    // MARK: Panel

    @ViewBuilder
    private var panel: some View {
        VStack(spacing: 12) {
            if !PokemonRecognizer.isAvailable {
                message("Recogniser Not Included", "This build was made without the Pokémon classifier.", systemImage: "eye.slash")
            } else if let locked = model.locked, let pokemon = database.pokemon(id: locked.pokemonID) {
                lockedCard(pokemon, match: locked)
            } else {
                switch scanner.availability {
                case .denied where model.photo == nil:
                    message("Camera Access Needed", "Allow the camera in Settings, or scan a photo instead.", systemImage: "camera.badge.ellipsis")
                case .noCamera where model.photo == nil:
                    message("No Camera Here", "Scan a photo or screenshot instead.", systemImage: "video.slash")
                default:
                    candidates
                }
            }
            controls
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .animation(.snappy, value: model.locked?.pokemonID)
        .animation(.snappy, value: model.candidates.map(\.id))
    }

    private var candidates: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(model.photo == nil ? "Looking…" : "In this photo")
                    .font(.headline)
                Spacer()
                if model.isBusy { ProgressView().controlSize(.small) }
            }
            if model.candidates.isEmpty {
                Text(model.photo == nil ? "Hold the camera on a Pokémon, a card or a screen." : "No Pokémon recognised. Try a closer, brighter shot.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ForEach(model.candidates.prefix(3)) { candidate in
                if let pokemon = database.pokemon(id: candidate.pokemonID) {
                    CandidateRow(pokemon: pokemon, confidence: candidate.confidence)
                }
            }
        }
    }

    private func lockedCard(_ pokemon: Pokemon, match: PokemonRecognizer.Match) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                PokemonImage(pokemon: pokemon, kind: .thumbnail)
                    .frame(width: 88, height: 88)
                VStack(alignment: .leading, spacing: 4) {
                    Text("It's \(pokemon.displayName)!")
                        .font(.title3.weight(.bold))
                    Text("#\(String(format: "%04d", pokemon.nationalDexNumber)) · \(pokemon.genus ?? "Pokémon")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        ForEach(pokemon.types, id: \.self) { TypeBadge(type: $0, size: .small) }
                    }
                    Text(match.confidence >= 0.9 ? "Name read off the image" : "\(Int(match.confidence * 100))% sure")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 10) {
                NavigationLink(value: AppRoute.pokemon(pokemon.id)) {
                    Label("Open Entry", systemImage: "book.pages")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                Button("Scan Again", systemImage: "arrow.counterclockwise") { model.reset() }
                    .buttonStyle(.glass)
            }
            .controlSize(.large)
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("Scan a Photo", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            if model.photo != nil {
                Button("Back to Camera", systemImage: "camera") { model.reset() }
                    .buttonStyle(.glass)
            }
        }
        .controlSize(.large)
    }

    private func message(_ title: LocalizedStringKey, _ detail: LocalizedStringKey, systemImage: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage).font(.title).foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(detail).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

/// One guess: thumbnail, name and how sure the recogniser is.
private struct CandidateRow: View {
    var pokemon: Pokemon
    var confidence: Double

    var body: some View {
        NavigationLink(value: AppRoute.pokemon(pokemon.id)) {
            HStack(spacing: 12) {
                PokemonImage(pokemon: pokemon, kind: .thumbnail)
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text(pokemon.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    ProgressView(value: min(1, confidence))
                        .tint(pokemon.types.first?.color ?? .accentColor)
                }
                Text(confidence >= 0.9 ? "Name" : "\(Int(confidence * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }
}

/// The viewfinder's corner brackets; they close in and turn green on a lock.
private struct Reticle: View {
    var locked: Bool
    @State private var breathing = false

    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { corner in
                CornerBracket()
                    .stroke(locked ? Color.green : Color.white.opacity(0.9), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(Double(corner) * 90))
                    .offset(x: corner == 1 || corner == 2 ? 100 : -100, y: corner >= 2 ? 100 : -100)
            }
        }
        .scaleEffect(locked ? 0.92 : (breathing ? 1.03 : 0.97))
        .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: breathing)
        .animation(.snappy, value: locked)
        .onAppear { breathing = true }
        .shadow(color: .black.opacity(0.4), radius: 4)
        .accessibilityHidden(true)
    }

    private nonisolated struct CornerBracket: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + 8))
            path.addQuadCurve(to: CGPoint(x: rect.minX + 8, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            return path
        }
    }
}

/// Keeps the running guesses steady: live frames are smoothed over time and a confident, repeated
/// winner becomes the lock; photos are scanned once, with printed names as a second opinion.
@Observable
@MainActor
final class ScanModel {
    private(set) var candidates: [PokemonRecognizer.Match] = []
    private(set) var locked: PokemonRecognizer.Match?
    private(set) var photo: CGImage?
    private(set) var isBusy = false

    private var database: PokedexDatabase?
    private var smoothed: [String: Double] = [:]
    private var streak = (id: "", count: 0)
    private var inFlight = false

    static let lockConfidence = 0.55
    static let lockStreak = 3
    private static let log = Logger(subsystem: "Neodex", category: "Scanner")

    func configure(database: PokedexDatabase) { self.database = database }

    /// A live camera frame; dropped if the previous one is still being classified or a lock is showing.
    func consume(_ frame: CameraFrame) {
        guard !inFlight, locked == nil, photo == nil else { return }
        inFlight = true
        Task {
            defer { inFlight = false }
            do {
                smooth(try await PokemonRecognizer.shared.matches(in: frame, limit: 5))
            } catch {
                Self.log.error("Frame classification failed: \(error)")
            }
        }
    }

    /// A picked photo: the whole image is classified and any printed names are read.
    func scan(_ item: PhotosPickerItem) async {
        guard let database, let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data), let cgImage = image.cgImage else { return }
        isBusy = true
        photo = cgImage
        locked = nil
        smoothed = [:]
        defer { isBusy = false }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        var matches: [PokemonRecognizer.Match] = []
        do {
            matches = try await PokemonRecognizer.shared.combinedMatches(in: cgImage, orientation: orientation, database: database, limit: 5)
        } catch {
            Self.log.error("Photo classification failed: \(error)")
        }
        candidates = matches
        if let best = matches.first, best.confidence >= Self.lockConfidence { locked = best }
    }

    func reset() {
        locked = nil
        photo = nil
        candidates = []
        smoothed = [:]
        streak = ("", 0)
    }

    private func smooth(_ matches: [PokemonRecognizer.Match]) {
        for key in smoothed.keys { smoothed[key]! *= 0.55 }
        for match in matches { smoothed[match.pokemonID, default: 0] += 0.45 * match.confidence }
        smoothed = smoothed.filter { $0.value >= 0.02 }
        candidates = smoothed
            .map { PokemonRecognizer.Match(pokemonID: $0.key, confidence: $0.value) }
            .sorted { $0.confidence > $1.confidence }
            .prefix(5)
            .map { $0 }
        guard let best = candidates.first, best.confidence >= Self.lockConfidence else {
            streak = ("", 0)
            return
        }
        streak = best.pokemonID == streak.id ? (best.pokemonID, streak.count + 1) : (best.pokemonID, 1)
        if streak.count >= Self.lockStreak { locked = best }
    }
}
