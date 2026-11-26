import Charts
import SwiftData
import SwiftUI
import VorratCore

/// Bilanz: verbraucht vs. weggeworfen.
struct StatisticsView: View {
    let history: [HistoryEntry]

    @Environment(\.modelContext) private var context
    @State private var confirmReset = false

    private struct ChartPoint: Identifiable {
        var month: Date
        var kind: String
        var count: Int
        var id: String { "\(month.timeIntervalSince1970)-\(kind)" }
    }

    var body: some View {
        if history.isEmpty {
            ContentUnavailableView {
                Label("Noch keine Statistik", systemImage: "chart.bar")
            } description: {
                Text("Markiere Artikel als „Aufgebraucht“ oder „Weggeworfen“ – hier siehst du dann, wie viel du verbrauchst und was am häufigsten im Müll landet.")
            }
            .navigationTitle("Statistik")
        } else {
            content(WasteStats(history: history.map(\.record)))
        }
    }

    private func content(_ stats: WasteStats) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 16) {
                    tile(title: "Verbraucht diesen Monat", value: "\(stats.thisMonth.consumed)",
                         subtitle: "Vormonat: \(stats.lastMonth.consumed)", color: .green)
                    tile(title: "Weggeworfen diesen Monat", value: "\(stats.thisMonth.discarded)",
                         subtitle: discardedTrend(stats), color: .red)
                    tile(title: "Wegwerf-Quote", value: percent(stats.thisMonthWasteRate),
                         subtitle: "Vormonat: \(percent(stats.lastMonthWasteRate))", color: .orange)
                }

                TodayCard(title: "Letzte 6 Monate", systemImage: "chart.bar.xaxis", tint: .blue) {
                    Chart(points(stats)) { point in
                        BarMark(
                            x: .value("Monat", point.month, unit: .month),
                            y: .value("Anzahl", point.count)
                        )
                        .foregroundStyle(by: .value("Art", point.kind))
                    }
                    .chartForegroundStyleScale([
                        RemovalOutcome.consumed.title: Color.green,
                        RemovalOutcome.discarded.title: Color.red,
                    ])
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .month)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                        }
                    }
                    .frame(height: 220)
                }

                HStack(alignment: .top, spacing: 16) {
                    TodayCard(title: "Wird am häufigsten weggeworfen", systemImage: "trash", tint: .red) {
                        rankedList(stats.topDiscardedItems, empty: "Noch nichts weggeworfen 👍")
                    }
                    TodayCard(title: "Nach Kategorie", systemImage: "tag", tint: .red) {
                        rankedList(stats.topDiscardedCategories, empty: "–")
                    }
                }

                TodayCard(title: "Verlauf", systemImage: "clock.arrow.circlepath", tint: .secondary) {
                    VStack(spacing: 0) {
                        ForEach(Array(history.prefix(100))) { entry in
                            historyRow(entry)
                            Divider()
                        }
                    }
                    if history.count > 100 {
                        Text("Ältere Einträge werden in der Statistik mitgezählt, aber hier nicht angezeigt.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 1100, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Statistik")
        .navigationSubtitle("\(stats.totalConsumed) verbraucht · \(stats.totalDiscarded) weggeworfen insgesamt")
        .toolbar {
            ToolbarItem {
                Button(role: .destructive) { confirmReset = true } label: {
                    Label("Statistik zurücksetzen", systemImage: "arrow.counterclockwise")
                }
                .help("Löscht den gesamten Verlauf (der Vorrat selbst bleibt unverändert)")
            }
        }
        .confirmationDialog("Statistik zurücksetzen?", isPresented: $confirmReset) {
            Button("Verlauf löschen (\(history.count) Einträge)", role: .destructive) { resetHistory() }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Alle Einträge zu „Verbraucht“ und „Weggeworfen“ werden gelöscht. Deine Artikel im Vorrat bleiben erhalten. Direkt danach lässt sich das mit ⌘Z rückgängig machen.")
        }
    }

    private func resetHistory() {
        // Einzeln löschen, damit ⌘Z (Undo) funktioniert.
        for entry in history { context.delete(entry) }
    }

    // MARK: - Bausteine

    private func points(_ stats: WasteStats) -> [ChartPoint] {
        stats.months.flatMap { month in
            [
                ChartPoint(month: month.start, kind: RemovalOutcome.consumed.title, count: month.consumed),
                ChartPoint(month: month.start, kind: RemovalOutcome.discarded.title, count: month.discarded),
            ]
        }
    }

    private func tile(title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.callout).foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.08)))
    }

    private func discardedTrend(_ stats: WasteStats) -> String {
        let now = stats.thisMonth.discarded, before = stats.lastMonth.discarded
        if now < before { return "Vormonat: \(before) – weniger als zuvor 💪" }
        return "Vormonat: \(before)"
    }

    private func percent(_ rate: Double?) -> String {
        guard let rate else { return "–" }
        return rate.formatted(.percent.precision(.fractionLength(0)))
    }

    @ViewBuilder
    private func rankedList(_ ranked: [WasteStats.Ranked], empty: String) -> some View {
        if ranked.isEmpty {
            Text(empty).foregroundStyle(.secondary)
        } else {
            let maxCount = ranked.map(\.count).max() ?? 1
            VStack(alignment: .leading, spacing: 8) {
                ForEach(ranked) { entry in
                    HStack {
                        Text(entry.name)
                        Spacer()
                        Text("\(entry.count)×").monospacedDigit().foregroundStyle(.secondary)
                    }
                    GeometryReader { geo in
                        Capsule()
                            .fill(Color.red.opacity(0.6))
                            .frame(width: max(6, geo.size.width * CGFloat(entry.count) / CGFloat(maxCount)))
                    }
                    .frame(height: 5)
                }
            }
        }
    }

    private func historyRow(_ entry: HistoryEntry) -> some View {
        HStack(spacing: 10) {
            Image(systemName: entry.outcome == .consumed ? "checkmark.circle.fill" : "trash.fill")
                .foregroundStyle(entry.outcome == .consumed ? Color.green : Color.red)
            Text(entry.name)
            Text("\(ExportFormatter.quantityNumber(entry.quantity)) \(entry.unit)").foregroundStyle(.secondary)
            if entry.wasExpired {
                Text("war abgelaufen")
                    .font(.caption2)
                    .padding(.horizontal, 5)
                    .background(Color.red.opacity(0.15), in: Capsule())
            }
            Spacer()
            Text(entry.date, format: .dateTime.day().month().year())
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Aus Verlauf löschen", role: .destructive) { context.delete(entry) }
        }
    }
}
