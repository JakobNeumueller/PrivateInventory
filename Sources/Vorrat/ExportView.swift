import AppKit
import SwiftUI
import VorratCore

/// Export des Bestands als Markdown (für KI/Rezepte) oder JSON (Backup).
struct ExportView: View {
    let allItems: [Item]
    let visibleItems: [Item]
    let viewTitle: String
    let rules: StatusRules

    @Environment(\.dismiss) private var dismiss

    enum Format: String, CaseIterable, Identifiable {
        case markdown = "Markdown (für KI)"
        case json = "JSON (Backup)"
        var id: String { rawValue }
        var fileExtension: String { self == .markdown ? "md" : "json" }
    }

    @State private var format: Format = .markdown
    @State private var includeRecipePrompt = true
    @State private var onlyVisible = false
    @State private var copied = false

    private var output: String {
        let records = (onlyVisible ? visibleItems : allItems).map(\.record)
        let formatter = ExportFormatter(rules: rules)
        switch format {
        case .markdown:
            let md = formatter.markdown(records)
            return includeRecipePrompt ? AIPrompts.recipeSuggestions + md : md
        case .json:
            return formatter.json(records)
        }
    }

    var body: some View {
        let output = self.output

        VStack(alignment: .leading, spacing: 12) {
            Text("Vorrat exportieren").font(.title2.bold())

            HStack(spacing: 16) {
                Picker("Format", selection: $format) {
                    ForEach(Format.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)

                if format == .markdown {
                    Toggle("Rezept-Prompt voranstellen", isOn: $includeRecipePrompt)
                }
                if visibleItems.count != allItems.count {
                    Toggle("Nur „\(viewTitle)\" (\(visibleItems.count))", isOn: $onlyVisible)
                }
            }
            .onChange(of: format) { copied = false }
            .onChange(of: includeRecipePrompt) { copied = false }
            .onChange(of: onlyVisible) { copied = false }

            ScrollView {
                Text(output)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(.separator))

            HStack {
                Spacer()
                Button("Schliessen") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Als Datei sichern …") { save(output) }
                Button {
                    Clipboard.copy(output)
                    copied = true
                } label: {
                    Label(copied ? "Kopiert ✓" : "In Zwischenablage kopieren", systemImage: "doc.on.doc")
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 700, minHeight: 520)
    }

    private func save(_ text: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "vorrat-\(ExportFormatter.isoDate(Date())).\(format.fileExtension)"
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try text.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                NSAlert(error: error).runModal()
            }
        }
    }
}
