#if os(iOS) && canImport(WatchConnectivity)
import Foundation
import NeodexKit
import Observation
import os
import SwiftData
import UIKit
import WatchConnectivity

/// The iPhone's end of the watch bridge: pushes the saved teams to the watch whenever they change, and
/// answers the Dexbot questions the watch sends, waking in the background when it has to.
@Observable
@MainActor
final class WatchLink: NSObject {
    static let shared = WatchLink()

    /// When the teams were last handed to the watch, for Settings.
    private(set) var lastTeamSync: Date?
    private(set) var lastTeamCount = 0
    private(set) var isPaired = false
    private(set) var isWatchAppInstalled = false

    private var container: ModelContainer?
    private var saveObserver: NSObjectProtocol?
    private static let log = Logger(subsystem: "Neodex", category: "WatchLink")

    /// Starts the session. Called at launch, which is also how the system reaches us when it launches
    /// the app in the background to deliver a question from the watch.
    func activate(container: ModelContainer) {
        guard WCSession.isSupported() else { return }
        self.container = container
        let session = WCSession.default
        session.delegate = self
        session.activate()
        saveObserver = NotificationCenter.default.addObserver(forName: ModelContext.didSave, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.pushTeams() }
        }
    }

    /// Encodes the saved teams into the application context. The watch gets the latest set even if it
    /// is asleep now; WatchConnectivity delivers it when it next wakes.
    func pushTeams() {
        let session = WCSession.default
        guard let container, session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
        var descriptor = FetchDescriptor<SavedTeam>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        descriptor.fetchLimit = WatchTeamSnapshot.maximumTeams
        guard let teams = try? container.mainContext.fetch(descriptor) else { return }
        let snapshot = WatchTeamSnapshot(generatedAt: .now, teams: teams.map {
            WatchTeamSnapshot.Team(id: $0.id, name: $0.name, format: $0.format, updatedAt: $0.updatedAt, members: $0.members)
        })
        do {
            try session.updateApplicationContext([WatchTeamSnapshot.contextKey: try snapshot.encoded()])
            lastTeamSync = .now
            lastTeamCount = teams.count
        } catch {
            Self.log.error("Could not send teams to the watch: \(error)")
        }
    }

    private func refreshWatchState(paired: Bool, installed: Bool) {
        isPaired = paired
        isWatchAppInstalled = installed
    }

    /// Answers one question from the watch with Dexbot, holding a background task so the system lets the
    /// answer finish when the app was woken for it.
    private func answer(_ question: String, reply: @escaping @Sendable ([String: Any]) -> Void) async {
        let task = UIApplication.shared.beginBackgroundTask(withName: "Dexbot for Apple Watch")
        defer { if task != .invalid { UIApplication.shared.endBackgroundTask(task) } }
        Self.log.notice("Watch asked Dexbot (\(question.count) characters)")
        do {
            let database = try await DatabaseProvider.shared.database()
            let answer = try await DexbotEngine.answer(question, database: database, spoken: true)
            Self.log.notice("Replied to the watch (\(answer.count) characters)")
            reply([WatchDexbotMessage.answerKey: answer])
        } catch {
            Self.log.notice("Dexbot failed for the watch: \(error)")
            reply([WatchDexbotMessage.errorKey: DexbotEngine.describe(error)])
        }
    }
}

extension WatchLink: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // Only values cross to the main actor; the session itself stays on its queue.
        let paired = session.isPaired
        let installed = session.isWatchAppInstalled
        Task { @MainActor in
            refreshWatchState(paired: paired, installed: installed)
            pushTeams()
        }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        let paired = session.isPaired
        let installed = session.isWatchAppInstalled
        Task { @MainActor in
            refreshWatchState(paired: paired, installed: installed)
            pushTeams()
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    /// The user switched watches; start over with the new one.
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard message[WatchDexbotMessage.kindKey] as? String == WatchDexbotMessage.askKind,
              let question = message[WatchDexbotMessage.questionKey] as? String else {
            replyHandler([WatchDexbotMessage.errorKey: "That request wasn't understood."])
            return
        }
        nonisolated(unsafe) let reply = replyHandler
        Task { @MainActor in
            await answer(question) { reply($0) }
        }
    }

    /// A question the watch queued because the interactive channel didn't get through.
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard userInfo[WatchDexbotMessage.kindKey] as? String == WatchDexbotMessage.askKind,
              let question = userInfo[WatchDexbotMessage.questionKey] as? String,
              let id = userInfo[WatchDexbotMessage.idKey] as? String else { return }
        Task { @MainActor in
            await answer(question) { reply in
                var answer = reply
                answer[WatchDexbotMessage.kindKey] = WatchDexbotMessage.answerKind
                answer[WatchDexbotMessage.idKey] = id
                WCSession.default.transferUserInfo(answer)
            }
        }
    }
}
#endif
