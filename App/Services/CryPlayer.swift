import AVFoundation
import NeodexKit
import Observation

/// Plays a Pokémon's cry from Showdown's audio library, caching the download.
@Observable
@MainActor
final class CryPlayer {
    private(set) var isPlaying = false
    private(set) var isLoading = false
    /// The Pokémon whose cry Showdown doesn't have, so the button can say so.
    private(set) var unavailableID: String?

    private var player: AVAudioPlayer?
    private var finishTask: Task<Void, Never>?

    /// Plays the cry, or stops it if it is already playing.
    func play(_ pokemon: Pokemon) {
        if isPlaying {
            stop()
            return
        }
        guard !isLoading else { return }
        isLoading = true
        unavailableID = nil
        let stem = pokemon.showdownSpriteID
        Task {
            defer { isLoading = false }
            guard let data = try? await MediaCache.shared.data(for: ShowdownMedia.cry(stem)) else {
                unavailableID = pokemon.id
                return
            }
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.ambient, options: [.mixWithOthers])
            try? session.setActive(true)
            guard let player = try? AVAudioPlayer(data: data) else {
                unavailableID = pokemon.id
                return
            }
            self.player = player
            player.prepareToPlay()
            player.play()
            isPlaying = true
            finishTask?.cancel()
            finishTask = Task {
                try? await Task.sleep(for: .seconds(player.duration + 0.1))
                if !Task.isCancelled { isPlaying = false }
            }
        }
    }

    func stop() {
        player?.stop()
        finishTask?.cancel()
        isPlaying = false
    }
}
