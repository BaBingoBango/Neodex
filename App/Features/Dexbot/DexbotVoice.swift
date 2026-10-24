import AVFoundation
import Observation
import Speech

/// Hands-free Dexbot: on-device speech recognition in, spoken replies out.
@Observable
@MainActor
final class DexbotVoice {
    private(set) var isListening = false
    /// What has been recognised so far while listening.
    private(set) var liveTranscript = ""
    /// The final transcript, set once when listening ends; the chat sends it and then calls `consumeTranscript`.
    private(set) var finishedTranscript: String?
    private(set) var isSpeaking = false
    private(set) var errorText: String?
    /// Called with the final transcript when listening ends; used by CarPlay, which has no SwiftUI observation.
    var onFinishedTranscript: ((String) -> Void)?
    /// Called when a reply has finished being spoken.
    var onFinishedSpeaking: (() -> Void)?

    var speaksReplies: Bool {
        didSet { UserDefaults.standard.set(speaksReplies, forKey: "dexbotSpeaksReplies") }
    }

    private let synthesizer = AVSpeechSynthesizer()
    private let engine = AVAudioEngine()
    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?
    private var converter: AVAudioConverter?

    init() {
        speaksReplies = UserDefaults.standard.object(forKey: "dexbotSpeaksReplies") as? Bool ?? true
    }

    func consumeTranscript() { finishedTranscript = nil }

    // MARK: Listening

    func startListening() {
        guard !isListening else { return }
        stopSpeaking()
        errorText = nil
        liveTranscript = ""
        isListening = true
        Task { await listen() }
    }

    func stopListening() {
        guard isListening else { return }
        isListening = false
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        inputContinuation?.finish()
        inputContinuation = nil
        Task {
            try? await analyzer?.finalizeAndFinishThroughEndOfInput()
        }
    }

    func stopAll() {
        if isListening { stopListening() }
        stopSpeaking()
    }

    private func listen() async {
        guard await AVAudioApplication.requestRecordPermission() else {
            fail("Allow microphone access in Settings to talk to Dexbot.")
            return
        }
        let transcriber = SpeechTranscriber(locale: Locale.current, preset: .progressiveTranscription)
        do {
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                try await request.downloadAndInstall()
            }
        } catch {
            fail("Speech recognition isn't available for your language yet.")
            return
        }
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        self.transcriber = transcriber
        self.analyzer = analyzer

        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        inputContinuation = continuation

        resultsTask = Task { [weak self] in
            do {
                for try await result in transcriber.results {
                    let text = String(result.text.characters)
                    await MainActor.run {
                        guard let self else { return }
                        if result.isFinal {
                            self.liveTranscript = text
                        } else {
                            self.liveTranscript = text
                        }
                    }
                }
            } catch {
                await MainActor.run { self?.fail("I couldn't hear that clearly. Try again.") }
            }
            await MainActor.run { [weak self] in
                guard let self, !self.isListening else { return }
                let transcript = self.liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
                if !transcript.isEmpty {
                    self.finishedTranscript = transcript
                    self.onFinishedTranscript?(transcript)
                }
                self.liveTranscript = ""
            }
        }

        do {
            #if os(iOS)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true)
            #endif
            let input = engine.inputNode
            let inputFormat = input.outputFormat(forBus: 0)
            guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
                fail("Speech recognition isn't available right now.")
                return
            }
            converter = AVAudioConverter(from: inputFormat, to: analyzerFormat)
            input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
                guard let self, let converter = self.converter else { return }
                let ratio = analyzerFormat.sampleRate / inputFormat.sampleRate
                let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 16
                guard let converted = AVAudioPCMBuffer(pcmFormat: analyzerFormat, frameCapacity: capacity) else { return }
                var consumed = false
                var conversionError: NSError?
                converter.convert(to: converted, error: &conversionError) { _, status in
                    if consumed {
                        status.pointee = .noDataNow
                        return nil
                    }
                    consumed = true
                    status.pointee = .haveData
                    return buffer
                }
                guard conversionError == nil, converted.frameLength > 0 else { return }
                self.inputContinuation?.yield(AnalyzerInput(buffer: converted))
            }
            engine.prepare()
            try engine.start()
            try await analyzer.start(inputSequence: stream)
        } catch {
            fail("The microphone couldn't be started.")
        }
    }

    private func fail(_ message: String) {
        errorText = message
        isListening = false
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        inputContinuation?.finish()
        inputContinuation = nil
    }

    // MARK: Speaking

    func speak(_ text: String) {
        guard speaksReplies, !text.isEmpty else { return }
        stopSpeaking()
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.identifier) ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
        isSpeaking = true
        Task { [weak self] in
            while let self, self.synthesizer.isSpeaking { try? await Task.sleep(for: .milliseconds(200)) }
            self?.isSpeaking = false
            self?.onFinishedSpeaking?()
        }
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }
}
