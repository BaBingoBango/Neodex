import Foundation
import Testing
@testable import Neodex
#if os(iOS)
import UIKit
#endif

/// The links behind the Home Screen's quick actions.
@Suite("Quick actions")
@MainActor
struct QuickActionsTests {
    @Test("Search and Dexbot have links of their own")
    func opensSearchAndDexbot() throws {
        let router = DeepLinkRouter()
        router.open(url: try #require(URL(string: "neodex://search")))
        #expect(router.pendingTab == .search && router.wantsSearchFocus)

        router.open(url: try #require(URL(string: "neodex://dexbot")))
        #if os(macOS)
        #expect(router.pendingTab == .dexbot)
        #else
        #expect(router.pendingDexbotStart == .typing)
        #endif
    }

    #if os(iOS)
    @Test("Each Home Screen quick action has a title, a symbol and a link the app opens")
    func quickActions() throws {
        let items = try #require(Bundle.main.object(forInfoDictionaryKey: "UIApplicationShortcutItems") as? [[String: Any]])
        #expect(items.compactMap { $0["UIApplicationShortcutItemTitle"] as? String } == ["Search", "Ask Dexbot", "Scan a Pokémon", "Damage Calc"])
        for item in items {
            let type = try #require(item["UIApplicationShortcutItemType"] as? String)
            let router = DeepLinkRouter()
            router.open(url: try #require(URL(string: type)))
            #expect(router.pendingRoute != nil || router.pendingTab != nil || router.pendingDexbotStart != nil, "\(type) opens nothing")
            let symbol = try #require(item["UIApplicationShortcutItemIconSymbolName"] as? String)
            #expect(UIImage(systemName: symbol) != nil, "\(symbol) isn't an SF Symbol")
        }
    }
    #endif
}
