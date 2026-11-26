import SwiftData
import SwiftUI
import VorratCore

/// Formular zum Anlegen oder Bearbeiten eines Artikels.
struct ItemEditorView: View {
    let item: Item?
    let existingItems: [Item]

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var draft: ItemRecord
    @State private var hasExpiry: Bool
    @State private var expiry: Date
    @State private var isOpened: Bool
    @State private var opened: Date
    @State private var addedCount = 0
    @FocusState private var nameFocused: Bool

    init(item: Item?, existingItems: [Item]) {
        self.item = item
        self.existingItems = existingItems
        let record = item?.record ?? ItemRecord(name: "", purchaseDate: Calendar.current.startOfDay(for: Date()))
        _draft = State(initialValue: record)
        _hasExpiry = State(initialValue: record.expiryDate != nil)
        _expiry = State(initialValue: record.expiryDate ?? Calendar.current.date(byAdding: .day, value: 7, to: Date())!)
        _isOpened = State(initialValue: record.openedDate != nil)
        _opened = State(initialValue: record.openedDate ?? Date())
    }

    private var isNew: Bool { item == nil }
    private var canSave: Bool { !draft.name.trimmingCharacters(in: .whitespaces).isEmpty && draft.quantity > 0 }

    /// Hinweis, falls es so etwas schon gibt – der Kern der „nicht doppelt kaufen"-Idee.
    private var similarExisting: [Item] {
        guard isNew else { return [] }
        return existingItems.filter { Matching.isSimilar($0.name, draft.name) }
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField("Name", text: $draft.name, prompt: Text("z.B. Kichererbsen"))
                        .focused($nameFocused)
                    if !similarExisting.isEmpty {
                        Label {
                            Text("Schon vorhanden: " + similarExisting.prefix(3).map { "\($0.name) (\($0.quantityText), \($0.location))" }.joined(separator: ", "))
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        }
                        .font(.callout)
                    }
                    HStack {
                        TextField("Menge", value: $draft.quantity, format: .number)
                            .frame(maxWidth: 140)
                        Stepper("", value: $draft.quantity, in: 0...100_000, step: 1)
                            .labelsHidden()
                        SuggestionField(title: "Einheit", text: $draft.unit, suggestions: Defaults.units)
                    }
                    SuggestionField(title: "Kategorie", text: $draft.category,
                                    suggestions: merged(Defaults.categories, existingItems.map(\.category)))
                    SuggestionField(title: "Ort", text: $draft.location,
                                    suggestions: merged(Defaults.locations, existingItems.map(\.location)))
                }

                Section("Daten") {
                    DatePicker("Gekauft am", selection: $draft.purchaseDate, displayedComponents: .date)

                    Toggle("Ablaufdatum (MHD)", isOn: $hasExpiry)
                    if hasExpiry {
                        DatePicker("Haltbar bis", selection: $expiry, displayedComponents: .date)
                        HStack(spacing: 6) {
                            Text("Ab Kaufdatum:").foregroundStyle(.secondary)
                            quickExpiry("+3 T", .day, 3)
                            quickExpiry("+1 W", .day, 7)
                            quickExpiry("+2 W", .day, 14)
                            quickExpiry("+1 M", .month, 1)
                            quickExpiry("+6 M", .month, 6)
                            quickExpiry("+1 J", .year, 1)
                            quickExpiry("+2 J", .year, 2)
                        }
                        .controlSize(.small)
                    }

                    Toggle("Geöffnet", isOn: $isOpened)
                    if isOpened {
                        DatePicker("Geöffnet am", selection: $opened, displayedComponents: .date)
                    }

                    if let lastUsed = draft.lastUsedDate {
                        LabeledContent("Zuletzt benutzt") {
                            HStack {
                                Text(lastUsed, format: .dateTime.day().month().year())
                                Button("Zurücksetzen") { draft.lastUsedDate = nil }
                                    .controlSize(.small)
                            }
                        }
                    }
                }

                Section("Notizen") {
                    TextField("Notizen", text: $draft.notes, prompt: Text("optional"), axis: .vertical)
                        .lineLimit(2...5)
                        .labelsHidden()
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                if addedCount > 0 {
                    Text("\(addedCount) hinzugefügt").foregroundStyle(.secondary)
                }
                Spacer()
                Button("Abbrechen") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                if isNew {
                    Button("Speichern & nächster") { saveAndNext() }
                        .keyboardShortcut(.return, modifiers: [.command, .shift])
                        .disabled(!canSave)
                }
                Button(isNew ? "Hinzufügen" : "Speichern") { save(); dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
            .padding()
        }
        .frame(width: 520)
        .frame(minHeight: 520)
        .navigationTitle(isNew ? "Neuer Artikel" : "Artikel bearbeiten")
        .onAppear { nameFocused = true }
    }

    private func quickExpiry(_ title: String, _ component: Calendar.Component, _ value: Int) -> some View {
        Button(title) {
            if let date = Calendar.current.date(byAdding: component, value: value, to: draft.purchaseDate) {
                expiry = date
            }
        }
    }

    private func merged(_ defaults: [String], _ existing: [String]) -> [String] {
        var result = defaults
        for value in existing.sorted() where !value.isEmpty && !result.contains(value) {
            result.append(value)
        }
        return result
    }

    private func finalizedRecord() -> ItemRecord {
        var record = draft
        record.name = record.name.trimmingCharacters(in: .whitespacesAndNewlines)
        record.category = record.category.trimmingCharacters(in: .whitespaces).isEmpty ? Defaults.category : record.category.trimmingCharacters(in: .whitespaces)
        record.location = Defaults.normalizedLocation(record.location)
        record.unit = record.unit.trimmingCharacters(in: .whitespaces).isEmpty ? Defaults.unit : record.unit.trimmingCharacters(in: .whitespaces)
        record.expiryDate = hasExpiry ? Calendar.current.startOfDay(for: expiry) : nil
        record.openedDate = isOpened ? opened : nil
        return record
    }

    private func save() {
        guard canSave else { return }
        let record = finalizedRecord()
        if let item {
            item.apply(record)
        } else {
            context.insert(Item(record: record))
        }
    }

    /// Speichert und leert nur Name/Menge – Ort, Kategorie und Daten bleiben für den nächsten Artikel.
    private func saveAndNext() {
        save()
        addedCount += 1
        draft.name = ""
        draft.quantity = 1
        draft.notes = ""
        nameFocused = true
    }
}

/// Textfeld mit Auswahlmenü für gängige Werte.
struct SuggestionField: View {
    let title: String
    @Binding var text: String
    let suggestions: [String]

    var body: some View {
        HStack(spacing: 4) {
            TextField(title, text: $text)
            Menu {
                ForEach(suggestions, id: \.self) { value in
                    Button(value) { text = value }
                }
            } label: {
                Image(systemName: "chevron.down")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }
}
