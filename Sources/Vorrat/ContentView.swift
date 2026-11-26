import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import VorratCore

enum SidebarFilter: Hashable {
    case all
    case status(ItemStatus)
    case location(String)
    case category(String)

    var title: String {
        switch self {
        case .all: return "Alle Artikel"
        case .status(let s): return s.title
        case .location(let l): return l
        case .category(let c): return c
        }
    }
}

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @Environment(\.undoManager) private var undoManager

    @Query private var items: [Item]

    @AppStorage(SettingsKey.soonDays) private var soonDays = 3
    @AppStorage(SettingsKey.forgottenDays) private var forgottenDays = 30

    @State private var filter: SidebarFilter? = .all
    @State private var search = ""
    @State private var selection = Set<PersistentIdentifier>()
    @State private var sortOrder = [KeyPathComparator(\Item.expirySortKey)]

    private var rules: StatusRules { StatusRules(soonDays: soonDays, forgottenDays: forgottenDays) }

    private var trimmedSearch: String { search.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Gesucht wird immer im ganzen Vorrat – damit „Habe ich das schon?" zuverlässig funktioniert.
    private var visibleItems: [Item] {
        let base: [Item]
        if !trimmedSearch.isEmpty {
            base = items.filter { item in
                [item.name, item.category, item.location, item.notes]
                    .contains { $0.localizedStandardContains(trimmedSearch) }
            }
        } else {
            base = items.filter { matches($0, filter ?? .all) }
        }
        return base.sorted(using: sortOrder)
    }

    private func matches(_ item: Item, _ filter: SidebarFilter) -> Bool {
        switch filter {
        case .all: return true
        case .status(let s): return item.status(rules) == s
        case .location(let l): return item.location == l
        case .category(let c): return item.category == c
        }
    }

    var body: some View {
        @Bindable var appState = appState

        NavigationSplitView {
            SidebarView(items: items, rules: rules, filter: $filter)
                .navigationSplitViewColumnWidth(min: 190, ideal: 220)
        } detail: {
            detail
        }
        .searchable(text: $search, placement: .toolbar, prompt: "Habe ich das schon?")
        .toolbar { toolbarContent }
        .sheet(item: $appState.sheet) { sheet in
            switch sheet {
            case .newItem:
                ItemEditorView(item: nil, existingItems: items)
            case .edit(let item):
                ItemEditorView(item: item, existingItems: items)
            case .importItems(let prefill):
                ImportView(initialText: prefill, existingItems: items)
            case .export(let format):
                ExportView(initialFormat: format, allItems: items, visibleItems: visibleItems, viewTitle: currentTitle, rules: rules)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first(where: { ["json", "txt"].contains($0.pathExtension.lowercased()) }),
                  let text = try? String(contentsOf: url, encoding: .utf8) else { return false }
            appState.sheet = .importItems(prefill: text)
            return true
        }
        .onAppear { context.undoManager = undoManager }
    }

    private var currentTitle: String {
        trimmedSearch.isEmpty ? (filter ?? .all).title : "Suche: „\(trimmedSearch)\""
    }

    // MARK: - Tabelle

    @ViewBuilder
    private var detail: some View {
        if items.isEmpty {
            ContentUnavailableView {
                Label("Noch nichts im Vorrat", systemImage: "refrigerator")
            } description: {
                Text("Lege Artikel einzeln an oder importiere einen ganzen Einkauf als JSON (z.B. von einer KI aus deinem Kassenzettel erzeugt).")
            } actions: {
                Button("Artikel anlegen") { appState.sheet = .newItem }
                Button("Einkauf importieren") { appState.sheet = .importItems(prefill: "") }
            }
        } else {
            let rows = visibleItems
            Table(rows, selection: $selection, sortOrder: $sortOrder) {
                TableColumn("") { item in
                    let status = item.status(rules)
                    Image(systemName: status.symbol)
                        .foregroundStyle(status.color)
                        .help(status.title)
                }
                .width(22)

                TableColumn("Name", value: \.name) { item in
                    HStack(spacing: 6) {
                        Text(item.name)
                        if item.openedDate != nil {
                            Text("geöffnet")
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .background(.quaternary, in: Capsule())
                        }
                    }
                    .help(item.notes)
                }
                .width(min: 140, ideal: 200)

                TableColumn("Menge", value: \.quantity) { item in
                    Text(item.quantityText).monospacedDigit()
                }
                .width(min: 60, ideal: 80)

                TableColumn("Kategorie", value: \.category)
                    .width(min: 90, ideal: 130)

                TableColumn("Ort", value: \.location)
                    .width(min: 90, ideal: 120)

                TableColumn("Haltbar bis", value: \.expirySortKey) { item in
                    if let expiry = item.expiryDate {
                        let status = item.status(rules)
                        HStack(spacing: 4) {
                            Text(expiry, format: .dateTime.day(.twoDigits).month(.twoDigits).year())
                                .monospacedDigit()
                            Text(DayMath.expiryDescription(expiry))
                                .foregroundStyle(status == .expired || status == .expiringSoon ? status.color : .secondary)
                                .font(.caption)
                        }
                    } else {
                        Text("–").foregroundStyle(.tertiary)
                    }
                }
                .width(min: 120, ideal: 190)

                TableColumn("Gekauft", value: \.purchaseDate) { item in
                    Text(item.purchaseDate, format: .dateTime.day(.twoDigits).month(.twoDigits).year())
                        .monospacedDigit()
                }
                .width(min: 80, ideal: 90)

                TableColumn("Zuletzt benutzt", value: \.lastTouchedDate) { item in
                    let status = item.status(rules)
                    Text(item.lastUsedDate.map { DayMath.agoDescription($0) } ?? "nie")
                        .foregroundStyle(status == .forgotten ? status.color : .secondary)
                }
                .width(min: 90, ideal: 110)
            }
            .contextMenu(forSelectionType: PersistentIdentifier.self) { ids in
                if !ids.isEmpty {
                    let targets = itemsFor(ids)
                    Button("Bearbeiten …") { if let first = targets.first { appState.sheet = .edit(first) } }
                        .disabled(targets.count != 1)
                    Divider()
                    Button("Heute benutzt") { markUsed(targets) }
                    Button("Menge −1") { decrement(targets) }
                    Button("Aufgebraucht (entfernen)") { remove(targets) }
                    Divider()
                    Button("Löschen", role: .destructive) { remove(targets) }
                }
            } primaryAction: { ids in
                if let first = itemsFor(ids).first { appState.sheet = .edit(first) }
            }
            .onDeleteCommand { remove(itemsFor(selection)) }
            .overlay {
                if rows.isEmpty {
                    ContentUnavailableView(trimmedSearch.isEmpty ? "Keine Artikel" : "Nicht im Vorrat",
                                           systemImage: trimmedSearch.isEmpty ? "checkmark.circle" : "magnifyingglass",
                                           description: Text(trimmedSearch.isEmpty ? "In dieser Ansicht ist nichts." : "„\(trimmedSearch)\" hast du (noch) nicht."))
                }
            }
            .navigationTitle(currentTitle)
            .navigationSubtitle("\(rows.count) Artikel")
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button { appState.sheet = .newItem } label: {
                Label("Neuer Artikel", systemImage: "plus")
            }
            .help("Neuen Artikel anlegen (⌘N)")

            Button { markUsed(itemsFor(selection)) } label: {
                Label("Heute benutzt", systemImage: "hand.tap")
            }
            .help("Markiert die Auswahl als heute benutzt")
            .disabled(selection.isEmpty)

            Button { decrement(itemsFor(selection)) } label: {
                Label("Menge −1", systemImage: "minus.circle")
            }
            .help("Menge um 1 verringern (bei 1 wird der Artikel entfernt)")
            .disabled(selection.isEmpty)

            Button { remove(itemsFor(selection)) } label: {
                Label("Aufgebraucht", systemImage: "checkmark.bin")
            }
            .help("Auswahl aufgebraucht – aus dem Vorrat entfernen (⌘Z macht rückgängig)")
            .disabled(selection.isEmpty)
        }
        ToolbarItemGroup(placement: .automatic) {
            Button { appState.sheet = .importItems(prefill: "") } label: {
                Label("Importieren", systemImage: "square.and.arrow.down")
            }
            .help("Einkauf als JSON importieren (⌘I)")

            Button { appState.sheet = .export(.markdown) } label: {
                Label("Exportieren", systemImage: "square.and.arrow.up")
            }
            .help("Vorrat als Liste oder JSON exportieren (⌘E)")

            Button { appState.sheet = .export(.recipePrompt) } label: {
                Label("Rezeptideen", systemImage: "fork.knife")
            }
            .help("Prompt mit allen Zutaten für Rezeptvorschläge einer KI erstellen (⌘R)")
        }
    }

    // MARK: - Aktionen

    private func itemsFor(_ ids: Set<PersistentIdentifier>) -> [Item] {
        items.filter { ids.contains($0.persistentModelID) }
    }

    private func markUsed(_ targets: [Item]) {
        let now = Date()
        for item in targets { item.lastUsedDate = now }
    }

    private func decrement(_ targets: [Item]) {
        let now = Date()
        for item in targets {
            if item.quantity > 1 {
                item.quantity -= 1
                item.lastUsedDate = now
            } else {
                selection.remove(item.persistentModelID)
                context.delete(item)
            }
        }
    }

    private func remove(_ targets: [Item]) {
        for item in targets {
            selection.remove(item.persistentModelID)
            context.delete(item)
        }
    }
}
