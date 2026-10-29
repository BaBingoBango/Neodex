import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

// Small shims so the same SwiftUI reads naturally on iOS and macOS. Anything that differs between
// the platforms lives here rather than as `#if os(...)` scattered through the views.

/// The kind of device the app runs on, for layout choices that must not flip when the device rotates.
enum DeviceIdiom {
    /// True on iPhone. A size class can't tell an iPhone from an iPad: Plus and Pro Max iPhones report
    /// a regular width in landscape.
    static var isPhone: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }
}

extension SearchFieldPlacement {
    /// Under the navigation title and never scrolled away, for screens where searching is the point.
    /// The Mac's toolbar search field always shows.
    static var pinned: SearchFieldPlacement {
        #if os(iOS)
        .navigationBarDrawer(displayMode: .always)
        #else
        .automatic
        #endif
    }
}

extension ToolbarItemPlacement {
    /// The trailing end of the navigation bar on iOS; the window toolbar's primary area on macOS.
    static var trailingBar: ToolbarItemPlacement {
        #if os(macOS)
        .primaryAction
        #else
        .topBarTrailing
        #endif
    }
}

extension View {
    /// Keeps the title in the bar on iOS. The Mac shows titles in the window toolbar regardless.
    @ViewBuilder
    func inlineNavigationTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    /// Lower-case text entry on iOS, where the keyboard capitalises by default.
    @ViewBuilder
    func neverAutocapitalized() -> some View {
        #if os(iOS)
        textInputAutocapitalization(.never)
        #else
        self
        #endif
    }

    /// Room for a sheet's list or form on the Mac, where a sheet shrinks to its content's ideal size and a
    /// list's ideal height is next to nothing. iOS sheets fill the screen anyway.
    @ViewBuilder
    func macSheetFrame(minWidth: CGFloat = 480, minHeight: CGFloat = 560) -> some View {
        #if os(macOS)
        frame(minWidth: minWidth, idealWidth: minWidth, minHeight: minHeight, idealHeight: minHeight)
        #else
        self
        #endif
    }

    /// Menus and buttons that draw their own label, like Global Stats' chips: the Mac otherwise wraps the
    /// label in a bordered pull-down button.
    @ViewBuilder
    func chipControls() -> some View {
        #if os(macOS)
        menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
        #else
        self
        #endif
    }

    /// Pull to refresh on iOS. The Mac refreshes from a toolbar button and ⌘R instead.
    @ViewBuilder
    func pullToRefresh(_ action: @escaping @Sendable () async -> Void) -> some View {
        #if os(iOS)
        refreshable(action: action)
        #else
        self
        #endif
    }

    /// The inset grouped list on iOS; the inset list on macOS.
    @ViewBuilder
    func groupedListStyle() -> some View {
        #if os(iOS)
        listStyle(.insetGrouped)
        #else
        listStyle(.inset)
        #endif
    }

    /// A transparent bar with light controls, for screens that run the camera edge to edge.
    @ViewBuilder
    func transparentNavigationBar() -> some View {
        #if os(iOS)
        toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        #else
        toolbarBackground(.hidden, for: .windowToolbar)
        #endif
    }
}

extension Color {
    /// The grouped-table background on iOS; the window background on macOS.
    static var groupedBackground: Color {
        #if os(iOS)
        Color(.systemGroupedBackground)
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }

    /// The card colour that sits on `groupedBackground`.
    static var secondaryGroupedBackground: Color {
        #if os(iOS)
        Color(.secondarySystemGroupedBackground)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }
}

/// The system pasteboard.
enum Clipboard {
    static var string: String? {
        get {
            #if canImport(UIKit)
            UIPasteboard.general.string
            #else
            NSPasteboard.general.string(forType: .string)
            #endif
        }
        set {
            #if canImport(UIKit)
            UIPasteboard.general.string = newValue
            #else
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            if let newValue { pasteboard.setString(newValue, forType: .string) }
            #endif
        }
    }
}
