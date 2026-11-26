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
    @State private var showFilePicker = false
    @State private var promptCopied = false
    @State private var fileError: String?

    init(initialText: String, existingItems: [Item]) {
        self.existingItems = existingItems
        _text = State(initialValue: initialText)
    }

    private var result: ImportResult { ImportParser().parse(text) }

    var body: some View {
        let result = self.result
        let included = result.records.indices.filter { !excluded.contains($0) }

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
                        .onChange(of: text) { excluded = [] }
                }
                .frame(minWidth: 260)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Vorschau").font(.headline)
                    preview(result)
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
                Button(included.count == 1 ? "1 Artikel übernehmen" : "\(included.count) Artikel übernehmen") {
                    for index in included {
                        context.insert(Item(record: result.records[index]))
                    }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(included.isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 820, minHeight: 560)
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
    private func preview(_ result: ImportResult) -> some View {
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
                        let similar = existingItems.filter { Matching.isSimilar($0.name, record.name) }
                        if !similar.isEmpty {
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
