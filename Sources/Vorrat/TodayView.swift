import SwiftUI
import VorratCore

/// Startseite: Was braucht heute Aufmerksamkeit?
struct TodayView: View {
    let items: [Item]
    let history: [HistoryRecord]
    let rules: StatusRules
    let actions: InventoryActions
    let showStatistics: () -> Void

    @Environment(AppState.self) private var appState

    private let maxRows = 8

    var body: some View {
        let now = Date()
        let urgent = items
            .filter { [ItemStatus.expired, .expiringSoon].contains($0.status(rules, now: now)) }
            .sorted { $0.expirySortKey < $1.expirySortKey }
        let forgotten = items
            .filter { $0.status(rules, now: now) == .forgotten }
            .sorted { $0.lastTouchedDate < $1.lastTouchedDate }
        let stats = WasteStats(history: history, now: now)

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header(now: now, attention: urgent.count + forgotten.count)

                if items.isEmpty {
                    welcomeCard
                } else if urgent.isEmpty && forgotten.isEmpty {
                    allGoodCard
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 340), spacing: 16, alignment: .top)],
                          alignment: .leading, spacing: 16) {
                    if !urgent.isEmpty {
                        TodayCard(title: "Zuerst verbrauchen", systemImage: "clock.badge.exclamationmark", tint: .orange) {
                            itemList(urgent) { item in
                                item.expiryDate.map { DayMath.expiryDescription($0, now: now) } ?? ""
                            }
                        }
                    }
                    if !forgotten.isEmpty {
                        TodayCard(title: "Vergessen", systemImage: "moon.zzz", tint: .purple) {
                            itemList(forgotten) { item in
                                let days = DayMath.days(from: item.lastTouchedDate, to: now)
                                return item.lastUsedDate == nil ? "seit \(days) Tagen nie benutzt" : "seit \(days) Tagen unbenutzt"
                            }
                        }
                    }
                    if !items.isEmpty {
                        recipeCard(preferCount: urgent.count + forgotten.count)
                    }
                    monthCard(stats)
                }
            }
            .padding(24)
            .frame(maxWidth: 1100, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Heute")
        .navigationSubtitle(items.count == 1 ? "1 Artikel" : "\(items.count) Artikel")
    }

    // MARK: - Kopf

    private func header(now: Date, attention: Int) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(now, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.largeTitle.bold())
                Group {
                    if items.isEmpty {
                        Text("Dein Vorrat ist noch leer.")
                    } else if attention == 0 {
                        Text("\(items.count) Artikel · alles im grünen Bereich")
                    } else {
                        Text("\(items.count) Artikel · \(attention) \(attention == 1 ? "braucht" : "brauchen") Aufmerksamkeit")
                    }
                }
                .font(.title3)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Button { appState.sheet = .importItems(prefill: "") } label: {
                Label("Einkauf importieren", systemImage: "square.and.arrow.down")
            }
            Button { appState.sheet = .newItem } label: {
                Label("Neuer Artikel", systemImage: "plus")
            }
        }
        .controlSize(.large)
    }

    // MARK: - Karten

    private var welcomeCard: some View {
        TodayCard(title: "Willkommen!", systemImage: "hand.wave", tint: .green) {
            Text("Fotografiere deinen nächsten Kassenzettel, lass ihn von einer KI in JSON umwandeln und importiere ihn hier – oder lege Artikel einzeln an. Danach siehst du auf dieser Seite jeden Tag, was zuerst weg sollte.")
                .fixedSize(horizontal: false, vertical: true)
            Button("Einkauf importieren") { appState.sheet = .importItems(prefill: "") }
                .buttonStyle(.borderedProminent)
        }
    }

    private var allGoodCard: some View {
        TodayCard(title: "Alles im grünen Bereich 🎉", systemImage: "checkmark.seal", tint: .green) {
            Text("Nichts läuft in den nächsten \(rules.soonDays) Tagen ab und nichts liegt länger als \(rules.forgottenDays) Tage unbenutzt herum.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func recipeCard(preferCount: Int) -> some View {
        TodayCard(title: "Rezeptideen", systemImage: "fork.knife", tint: .teal) {
            Text(preferCount == 0
                 ? "Lass dir Rezepte aus deinem Vorrat vorschlagen – fehlende Zutaten kommen auf eine Einkaufsliste."
                 : "\(preferCount) \(preferCount == 1 ? "Artikel sollte" : "Artikel sollten") bald verbraucht werden. Lass dir passende Rezepte vorschlagen – fehlende Zutaten kommen auf eine Einkaufsliste.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button { appState.sheet = .export(.recipePrompt) } label: {
                Label("Rezept-Prompt erstellen", systemImage: "sparkles")
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)
        }
    }

    private func monthCard(_ stats: WasteStats) -> some View {
        TodayCard(title: "Diesen Monat", systemImage: "chart.bar", tint: .blue) {
            HStack(spacing: 28) {
                bigNumber(stats.thisMonth.consumed, label: "verbraucht", color: .green)
                bigNumber(stats.thisMonth.discarded, label: "weggeworfen", color: .red)
                Spacer()
            }
            Text(comparisonText(stats))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Zur Statistik", action: showStatistics)
                .buttonStyle(.link)
        }
    }

    private func comparisonText(_ stats: WasteStats) -> String {
        let now = stats.thisMonth.discarded, before = stats.lastMonth.discarded
        if stats.thisMonth.consumed + now == 0 && stats.lastMonth.consumed + before == 0 {
            return "Mit „Aufgebraucht“ und „Weggeworfen“ füllt sich hier deine Bilanz."
        }
        if now < before { return "Weniger weggeworfen als im Vormonat (\(before)) – stark! 💪" }
        if now > before { return "Vormonat: \(before) weggeworfen." }
        return "Gleich viel weggeworfen wie im Vormonat."
    }

    private func bigNumber(_ value: Int, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(value)")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(label).foregroundStyle(.secondary)
        }
    }

    // MARK: - Artikelzeilen

    @ViewBuilder
    private func itemList(_ list: [Item], detail: @escaping (Item) -> String) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(list.prefix(maxRows))) { item in
                TodayItemRow(item: item, detail: detail(item), status: item.status(rules), actions: actions) {
                    appState.sheet = .edit(item)
                }
                if item.persistentModelID != list.prefix(maxRows).last?.persistentModelID {
                    Divider()
                }
            }
        }
        if list.count > maxRows {
            Text("… und \(list.count - maxRows) weitere – siehe Seitenleiste")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

/// Eine Zeile mit Schnellaktionen.
private struct TodayItemRow: View {
    let item: Item
    let detail: String
    let status: ItemStatus
    let actions: InventoryActions
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: status.symbol)
                .foregroundStyle(status.color)
                .font(.title3)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(item.name).fontWeight(.medium)
                    Text(item.quantityText).foregroundStyle(.secondary)
                }
                Text("\(detail) · \(item.location)")
                    .font(.caption)
                    .foregroundStyle(status == .ok ? Color.secondary : status.color)
            }
            Spacer(minLength: 8)
            HStack(spacing: 2) {
                rowButton("hand.tap", help: "Heute benutzt") { actions.markUsed([item]) }
                rowButton("checkmark.circle", help: "Aufgebraucht") { actions.remove([item], outcome: .consumed) }
                rowButton("trash", help: "Weggeworfen") { actions.remove([item], outcome: .discarded) }
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
        .help("Klicken zum Bearbeiten")
    }

    private func rowButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation { action() }
        } label: {
            Image(systemName: symbol)
                .frame(width: 26, height: 22)
        }
        .buttonStyle(.borderless)
        .help(help)
    }
}

/// Karte mit Titel, Symbol und Akzentfarbe.
struct TodayCard<Content: View>: View {
    let title: String
    let systemImage: String
    let tint: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(tint)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.08)))
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(topLeadingRadius: 12, bottomLeadingRadius: 12)
                .fill(tint)
                .frame(width: 4)
        }
    }
}
