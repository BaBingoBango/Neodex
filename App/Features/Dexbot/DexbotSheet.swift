import SwiftUI

/// Dexbot over Home: a new chat that opens full height with the keyboard up, or half height and
/// already listening, with every earlier chat one tap away.
struct DexbotSheet: View {
    @Environment(\.dismiss) private var dismiss
    var start: DexbotView.Start
    @State private var detent: PresentationDetent

    init(start: DexbotView.Start) {
        self.start = start
        // A half-height sheet leaves no room above the keyboard, so typing starts full height.
        _detent = State(initialValue: start == .typing ? .large : .medium)
    }

    var body: some View {
        NavigationStack {
            DexbotView(start: start)
                .appDestinations()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", systemImage: "xmark") { dismiss() }
                    }
                    ToolbarItem(placement: .trailingBar) {
                        NavigationLink {
                            DexbotConversationsView()
                        } label: {
                            Label("All Chats", systemImage: "clock.arrow.circlepath")
                        }
                    }
                }
        }
        .routePresenter()
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 620)
        #endif
    }
}
