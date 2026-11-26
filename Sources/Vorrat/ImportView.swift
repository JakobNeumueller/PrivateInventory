import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import VorratCore

/// Massenimport eines Einkaufs als JSON – mit Vorschau vor dem Übernehmen.
struct ImportView: View {
    let existingItems: [Item]

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var text: String
    @State private var excluded = Set<Int>()
    /// Vom Nutzer geänderte Entscheidung „addieren statt neu anlegen“ je Zeile.
    @State private var mergeOverrides: [Int: Bool] = [:]
    @State private var showFilePicker = false
    @State private var promptCopied = false
    @State private var fileError: String?

    init(initialText: String, existingItems: [Item]) {
        self.existingItems = existingItems
        _text = State(initialValue: initialText)
    }

    private var result: ImportResult { ImportParser().parse(text) }

    /// Plan für eine Zeile: neu anlegen oder zu einem vorhandenen Artikel addieren.
    private struct RowPlan {
        var candidate: Item?
        var merge: Bool
    }

    private func plans(for records: [ItemRecord]) -> [RowPlan] {
        let existingRecords = existingItems.map(\.record)
        return records.enumerated().map { index, record in
            guard let c = Matching.mergeCandidate(for: record, in: existingRecords) else {
                return RowPlan(candidate: nil, merge: false)
            }
            let item = existingItems[c]
            // Vorbelegung: nur bei exakt gleichem Namen automatisch addieren.
            let merge = mergeOverrides[index] ?? Matching.isSameName(item.name, record.name)
            return RowPlan(candidate: item, merge: merge)
        }
    }

    private func acceptTitle(new: Int, merged: Int) -> String {
        switch (new, merged) {
        case (_, 0): return new == 1 ? "1 Artikel übernehmen" : "\(new) Artikel übernehmen"
        case (0, _): return merged == 1 ? "1 Artikel ergänzen" : "\(merged) Artikel ergänzen"
        default: return "\(new) neu, \(merged) ergänzt – übernehmen"
        }
    }

    var body: some View {
        let result = self.result
        let included = result.records.indices.filter { !excluded.contains($0) }
        let plans = self.plans(for: result.records)
        let mergeCount = included.filter { plans[$0].merge }.count
        let newCount = included.count - mergeCount

        VStack(alignment: .leading, spacing: 12) {
            Text("Einkauf importieren").font(.title2.bold())

            GroupBox {
                VStack(alignment: .leading, spacing: 6) {
                    Text("So geht's schnell:").bold()
                    Text("1. „KI-Prompt kopieren“ klicken  2. Prompt + Foto vom Kassenzettel an eine KI schicken  3. Antwort hier einfügen – fertig.")
                        .foregroundStyle(.secondary)
                    HStack {
                        Button {
                            Clipboard.copy(AIPrompts.receiptToJSON())
                            promptCopied = true
                        } label: {
                            Label(promptCopied ? "Prompt kopiert ✓" : "KI-Prompt kopieren", systemImage: "doc.on.clipboard")
                        }
                        Button {
                            if let clip = Clipboard.read() { text = clip; excluded = [] }
                        } label: {
                            Label("Aus Zwischenablage einfügen", systemImage: "clipboard")
                        }
                        Button {
                            showFilePicker = true
                        } label: {
                            Label("Datei öffnen …", systemImage: "folder")
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }

            HSplitView {
                VStack(alignment: .leading, spacing: 4) {
                    Text("JSON").font(.headline)
                    TextEditor(text: $text)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .background(Color(nsColor: .textBackgroundColor))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(.separator))
                        .overlay(alignment: .topLeading) {
                            if text.isEmpty {
                                Text(#"{"items": [{"name": "Vollmilch", "quantity": 2, "unit": "l", "location": "Kühlschrank", "expiryDate": "2026-12-05"}]}"#)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                                    .padding(6)
                                    .allowsHitTesting(false)
                            }
                        }
                        .onChange(of: text) { excluded = []; mergeOverrides = [:] }
                }
                .frame(minWidth: 260)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Vorschau").font(.headline)
                    preview(result, plans: plans)
                }
                .frame(minWidth: 380)
            }
            .frame(minHeight: 320)

            HStack {
                if let fileError {
                    Text(fileError).foregroundStyle(.red)
                }
                Spacer()
                Button("Abbrechen") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(acceptTitle(new: newCount, merged: mergeCount)) {
                    for index in included {
                        let record = result.records[index]
                        if plans[index].merge, let target = plans[index].candidate {
                            target.apply(target.record.merged(with: record))
                        } else {
                            context.insert(Item(record: record))
                        }
                    }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(included.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 900, height: 620)
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.json, .plainText]) { outcome in
            switch outcome {
            case .success(let url):
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                do {
                    text = try String(contentsOf: url, encoding: .utf8)
                    fileError = nil
                } catch {
                    fileError = "Datei konnte nicht gelesen werden: \(error.localizedDescription)"
                }
            case .failure(let error):
                fileError = error.localizedDescription
            }
        }
    }

    @ViewBuilder
    private func preview(_ result: ImportResult, plans: [RowPlan]) -> some View {
        List {
            if result.records.isEmpty && result.issues.isEmpty {
                Text("Noch nichts eingefügt.").foregroundStyle(.secondary)
            }
            ForEach(Array(result.issues.enumerated()), id: \.offset) { _, issue in
                Label(issue.message, systemImage: issue.index == nil ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(issue.index == nil ? Color.red : Color.orange)
            }
            ForEach(Array(result.records.enumerated()), id: \.offset) { index, record in
                let isIncluded = !excluded.contains(index)
                HStack(alignment: .top) {
                    Toggle("", isOn: Binding(
                        get: { isIncluded },
                        set: { on in if on { excluded.remove(index) } else { excluded.insert(index) } }
                    ))
                    .labelsHidden()
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(record.name).bold()
                            Text(ExportFormatter.quantityText(record)).foregroundStyle(.secondary)
                        }
                        Text(details(record)).font(.caption).foregroundStyle(.secondary)
                        if let candidate = plans[index].candidate {
                            Picker("", selection: Binding(
                                get: { plans[index].merge },
                                set: { mergeOverrides[index] = $0 }
                            )) {
                                Text("Neu anlegen").tag(false)
                                Text("Zu „\(candidate.name)“ (\(candidate.quantityText)) addieren → \(ExportFormatter.quantityNumber(candidate.quantity + record.quantity)) \(candidate.unit)").tag(true)
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .fixedSize()
                            .controlSize(.small)
                        }
                        let similar = existingItems.filter { Matching.isSimilar($0.name, record.name) }
                        if plans[index].candidate == nil && !similar.isEmpty {
                            Text("Schon im Vorrat: " + similar.prefix(3).map { "\($0.name) (\($0.quantityText))" }.joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    .opacity(isIncluded ? 1 : 0.4)
                }
            }
        }
        .listStyle(.bordered)
    }

    private func details(_ record: ItemRecord) -> String {
        var parts = [record.location, record.category, "gekauft " + ExportFormatter.displayDate(record.purchaseDate)]
        if let expiry = record.expiryDate { parts.append("MHD " + ExportFormatter.displayDate(expiry)) }
        if !record.notes.isEmpty { parts.append(record.notes) }
        return parts.joined(separator: " · ")
    }
}
