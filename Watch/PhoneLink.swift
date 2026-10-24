import Foundation
import Observation
import WatchConnectivity

/// The watch's end of the bridge: keeps the teams the iPhone last sent, and relays Dexbot questions to
/// the iPhone, which wakes in the background to answer them.
@Observable
@MainActor
final class PhoneLink: NSObject {
    static let shared = PhoneLink()

    private(set) var snapshot: WatchTeamSnapshot?
    private(set) var isReachable = false
    private(set) var isCompanionInstalled = true

    /// Questions waiting for an answer, by id.
    private var pending: [String: CheckedContinuation<String, Error>] = [:]
    /// Questions already handed to the queued channel, so a fallback never sends twice.
    private var queued: Set<String> = []

    var teams: [WatchTeamSnapshot.Team] { snapshot?.teams ?? [] }

    private static var storeURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("teams-from-phone.json")
    }

    func activate() {
        if let data = try? Data(contentsOf: Self.storeURL), let saved = try? WatchTeamSnapshot.decode(data) {
            snapshot = saved
        }
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Sends a question to the iPhone and waits for Dexbot's answer. An interactive message goes first
    /// when the iPhone is reachable, since that wakes the iPhone app; if nothing comes back within a
    /// moment (the simulator's daemon drops interactive messages silently) the question is queued as a
    /// transfer instead, and the whole ask gives up after ninety seconds.
    func ask(_ question: String) async throws -> String {
        let session = WCSession.default
        guard session.activationState == .activated else { throw PhoneLinkError.notActivated }
        guard session.isCompanionAppInstalled else { throw PhoneLinkError.noCompanion }
        let ask = Ask(id: UUID().uuidString, question: question)
        return try await withCheckedThrowingContinuation { continuation in
            pending[ask.id] = continuation
            if session.isReachable {
                session.sendMessage(ask.payload, replyHandler: { [weak self] reply in
                    let outcome = Outcome(reply)
                    Task { @MainActor in self?.resolve(ask.id, with: outcome) }
                }, errorHandler: { [weak self] _ in
                    Task { @MainActor in self?.queue(ask) }
                })
            } else {
                queue(ask)
            }
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(12))
                await self?.queue(ask)
                try? await Task.sleep(for: .seconds(78))
                await self?.fail(ask.id, PhoneLinkError.timedOut)
            }
        }
    }

    /// A question on its way to the iPhone.
    nonisolated private struct Ask: Sendable {
        let id: String
        let question: String
        var payload: [String: Any] {
            [WatchDexbotMessage.kindKey: WatchDexbotMessage.askKind, WatchDexbotMessage.idKey: id, WatchDexbotMessage.questionKey: question]
        }
    }

    /// What came back, with only the strings pulled out of the dictionary so it can cross actors.
    nonisolated private struct Outcome: Sendable {
        let answer: String?
        let error: String?
        init(_ reply: [String: Any]) {
            answer = reply[WatchDexbotMessage.answerKey] as? String
            error = reply[WatchDexbotMessage.errorKey] as? String
        }
    }

    /// Hands the question to the queued channel, once, while it is still unanswered.
    private func queue(_ ask: Ask) {
        guard pending[ask.id] != nil, !queued.contains(ask.id) else { return }
        queued.insert(ask.id)
        WCSession.default.transferUserInfo(ask.payload)
    }

    private func resolve(_ id: String, with outcome: Outcome) {
        guard let continuation = pending.removeValue(forKey: id) else { return }
        queued.remove(id)
        if let answer = outcome.answer {
            continuation.resume(returning: answer)
        } else {
            continuation.resume(throwing: PhoneLinkError.phone(outcome.error ?? "No answer came back."))
        }
    }

    private func fail(_ id: String, _ error: Error) {
        guard let continuation = pending.removeValue(forKey: id) else { return }
        queued.remove(id)
        continuation.resume(throwing: error)
    }

    private func apply(_ data: Data) {
        guard let received = try? WatchTeamSnapshot.decode(data) else { return }
        snapshot = received
        try? FileManager.default.createDirectory(at: Self.storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: Self.storeURL, options: .atomic)
    }

    private func refresh(reachable: Bool, companionInstalled: Bool) {
        isReachable = reachable
        isCompanionInstalled = companionInstalled
    }
}

extension PhoneLink: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // Only values cross to the main actor; the session itself stays on its queue.
        let data = session.receivedApplicationContext[WatchTeamSnapshot.contextKey] as? Data
        let reachable = session.isReachable
        let installed = session.isCompanionAppInstalled
        Task { @MainActor in
            refresh(reachable: reachable, companionInstalled: installed)
            if let data { apply(data) }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        let installed = session.isCompanionAppInstalled
        Task { @MainActor in refresh(reachable: reachable, companionInstalled: installed) }
    }

    nonisolated func sessionCompanionAppInstalledDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        let installed = session.isCompanionAppInstalled
        Task { @MainActor in refresh(reachable: reachable, companionInstalled: installed) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext[WatchTeamSnapshot.contextKey] as? Data else { return }
        Task { @MainActor in apply(data) }
    }

    /// An answer that travelled the queued channel.
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard userInfo[WatchDexbotMessage.kindKey] as? String == WatchDexbotMessage.answerKind,
              let id = userInfo[WatchDexbotMessage.idKey] as? String else { return }
        let outcome = Outcome(userInfo)
        Task { @MainActor in resolve(id, with: outcome) }
    }
}

nonisolated enum PhoneLinkError: LocalizedError {
    case notActivated
    case noCompanion
    case unreachable
    case timedOut
    case phone(String)

    var errorDescription: String? {
        switch self {
        case .notActivated: "The connection to your iPhone isn't ready yet. Try again in a moment."
        case .noCompanion: "Install Neodex on your iPhone to ask Dexbot from here."
        case .unreachable: "Your iPhone isn't reachable right now. Keep it nearby and try again."
        case .timedOut: "Your iPhone didn't answer in time. Keep it nearby, with Neodex installed, and try again."
        case .phone(let message): message
        }
    }
}
