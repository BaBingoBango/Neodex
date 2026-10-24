#if canImport(CarPlay)
import CarPlay
import NeodexKit
import SwiftData
import UIKit

/// Dexbot in the car: one list with "Ask Dexbot" and recent chats. Everything is spoken; the list
/// only shows short status text, so there is nothing to read while driving.
@MainActor
final class CarPlayDexbot {
    private var interfaceController: CPInterfaceController?
    private let voice = DexbotVoice()
    private var askItem: CPListItem?
    private var listTemplate: CPListTemplate?
    private var isAnswering = false

    func connect(_ controller: CPInterfaceController) {
        interfaceController = controller
        voice.speaksReplies = true
        voice.onFinishedTranscript = { [weak self] transcript in
            Task { await self?.answer(transcript) }
        }
        let template = makeTemplate()
        listTemplate = template
        controller.setRootTemplate(template, animated: true, completion: nil)
    }

    func disconnect() {
        voice.stopAll()
        interfaceController = nil
        listTemplate = nil
        askItem = nil
    }

    // MARK: Template

    private func makeTemplate() -> CPListTemplate {
        let ask = CPListItem(text: "Ask Dexbot", detailText: DexbotEngine.unavailableReason ?? "Tap, then ask a Pokémon question.",
                             image: UIImage(systemName: "mic.fill"))
        ask.handler = { [weak self] _, completion in
            self?.beginListening()
            completion()
        }
        askItem = ask
        var sections = [CPListSection(items: [ask], header: "Dexbot", sectionIndexTitle: nil)]

        let recent = TeamReader.recentConversations(limit: 6)
        if !recent.isEmpty {
            let items = recent.map { conversation -> CPListItem in
                let lastAnswer = conversation.messages.last { $0.role == .dexbot }?.text
                let item = CPListItem(text: conversation.title, detailText: lastAnswer.map { String($0.prefix(80)) } ?? "No reply yet",
                                      image: UIImage(systemName: "bubble.left.and.text.bubble.right"))
                item.handler = { [weak self] _, completion in
                    self?.replay(conversation)
                    completion()
                }
                return item
            }
            sections.append(CPListSection(items: items, header: "Recent Chats", sectionIndexTitle: nil))
        }
        let template = CPListTemplate(title: "Dexbot", sections: sections)
        template.tabTitle = "Dexbot"
        template.tabImage = UIImage(systemName: "bubble.left.and.text.bubble.right.fill")
        return template
    }

    private func setStatus(_ text: String) {
        askItem?.setDetailText(text)
    }

    // MARK: Conversation

    private func beginListening() {
        guard DexbotEngine.unavailableReason == nil else {
            voice.speak(DexbotEngine.unavailableReason ?? "")
            return
        }
        guard !isAnswering else { return }
        if voice.isListening {
            voice.stopListening()
            setStatus("Thinking…")
        } else {
            setStatus("Listening… tap again when you're done.")
            voice.startListening()
        }
    }

    private func answer(_ question: String) async {
        guard !isAnswering else { return }
        isAnswering = true
        defer { isAnswering = false }
        setStatus("Thinking about “\(question)”…")
        do {
            let database = try await DatabaseProvider.shared.database()
            let reply = try await DexbotEngine.answer(question, database: database, spoken: true)
            TeamReader.saveConversation(question: question, answer: reply)
            setStatus(String(reply.prefix(100)))
            voice.speak(reply)
        } catch {
            let message = DexbotEngine.describe(error)
            setStatus(message)
            voice.speak(message)
        }
    }

    private func replay(_ conversation: ConversationSummary) {
        guard let lastAnswer = conversation.messages.last(where: { $0.role == .dexbot })?.text else { return }
        voice.speak(lastAnswer)
    }
}
#endif
