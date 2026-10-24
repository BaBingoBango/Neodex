//
//  MetaSettingsView.swift
//  Scope Lens
//
//  Phase 3, m11-C: Settings (⌘,) Meta tab — the pilot's window into which
//  usage snapshot drives every prior in the app (scout report, matchup set
//  assumptions, advisor capsules), with the regulation label, a staleness
//  read, and the polite on-demand refresh. Regulations rotate; this is how
//  the app keeps up without a rebuild.
//

import SwiftUI

/// When this app binary was produced (the executable's mtime) — the
/// stale-running-instance detector. Twice now a feature "wasn't there"
/// because a long-lived app process outlived a rebuild (m10-A's overlay,
/// m11's whole feature set); a glanceable stamp ends that mystery.
nonisolated enum AppBuildStamp {
    static let display: String = {
        guard let url = Bundle.main.executableURL,
              let mtime = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
        else { return "build unknown" }
        let f = DateFormatter()
        f.dateFormat = "MMM d, HH:mm"
        return "build \(f.string(from: mtime))"
    }()
}

public struct MetaSettingsView: View {
    @ObservedObject private var store = MetaStore.shared


    public init() {}
    public var body: some View {
        Form {
            Section {
                Text("Usage-meta snapshot")
                    .font(.headline)
                Text("Move/item/ability priors and winrates come from Pikalytics ranked battle data. The engine hot-swaps a refreshed snapshot instantly — scout report, matchup and advisor capsules all follow.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LabeledContent("Regulation") {
                    Text(store.info?.regulation ?? MetaStore.bundledRegulation)
                        .fontWeight(.medium)
                }
                LabeledContent("Source") {
                    Text(store.info == nil
                         ? "bundled snapshot (crawled \(MetaStore.bundledCrawlDate))"
                         : "refreshed in-app")
                }
                LabeledContent("Species covered") {
                    Text(store.info.map { String($0.speciesCount) } ?? "119")
                }
                LabeledContent("Age") {
                    HStack(spacing: 6) {
                        Text("\(store.snapshotAgeDays) day\(store.snapshotAgeDays == 1 ? "" : "s")")
                        staleBadge
                    }
                }

                HStack {
                    Button {
                        store.refresh()
                    } label: {
                        Label(store.isRefreshing ? "Refreshing…" : "Refresh from Pikalytics",
                              systemImage: "arrow.clockwise")
                    }
                    .disabled(store.isRefreshing)
                    .accessibilityLabel("Refresh the usage-meta snapshot")

                    if store.info != nil {
                        Button("Revert to bundled") { store.revertToBundled() }
                            .disabled(store.isRefreshing)
                    }
                    Spacer()
                    if store.isRefreshing { ProgressView().controlSize(.small) }
                }

                if let progress = store.progressLine {
                    Text(progress)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                if let error = store.lastError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Text("Fetches are polite (2 concurrent, 200 ms spacing, capped) and only run when you press Refresh — a few minutes for the full crawl. Diagnostics and parity checks keep pinning the committed repo snapshot, so refreshing here can never break them.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Text("Scope Lens \(AppBuildStamp.display) — if a new feature seems missing, quit and relaunch: a running instance outlives rebuilds.")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
                    .accessibilityLabel("App \(AppBuildStamp.display)")
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    @ViewBuilder
    private var staleBadge: some View {
        let days = store.snapshotAgeDays
        if days > 30 {
            badge("STALE — regulation may have rotated", .red)
        } else if days > 14 {
            badge("aging", .orange)
        } else {
            badge("fresh", .green)
        }
    }

    private func badge(_ label: String, _ tint: Color) -> some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6).padding(.vertical, 1)
            .background(Capsule().fill(tint.opacity(0.15)))
            .foregroundStyle(tint)
            .accessibilityLabel("Snapshot freshness: \(label)")
    }
}

#Preview {
    MetaSettingsView()
}
