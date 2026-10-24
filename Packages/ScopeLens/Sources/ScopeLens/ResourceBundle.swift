import Foundation

extension Bundle {
    /// Where Scope Lens's resources live: the package's resource bundle inside the app, or the main
    /// bundle when these sources are compiled straight into a diagnostics CLI with swiftc (those
    /// load from the repository checkout instead and never ask for bundled copies).
    nonisolated static var scopeLens: Bundle {
        #if SWIFT_PACKAGE
        .module
        #else
        .main
        #endif
    }
}
