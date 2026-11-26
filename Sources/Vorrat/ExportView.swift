import AppKit
import SwiftUI
import VorratCore

/// Export des Bestands: als fertiger Rezept-Prompt, als Markdown-Liste oder als JSON (Backup).
struct ExportView: View {
    let allItems: [Item]
    let visibleItems: [Item]
    let viewTitle: String
    let rules: StatusRules

    @Environment(\.dismiss) private var dismiss

    enum Format: String, CaseIterable, Identifiable {
        case recipePrompt = "Rezept-Prompt"
        case markdown = "Bestandsliste"
        case json = "JSON (Backup)"
        var id: String { rawValue }

        var fileExtension: String {
            switch self {
            case .recipePrompt: return "txt"
            case .markdown: return "md"
            case .json: return "json"
            }
        }

        var fileName: String {
            switch self {
            case .recipePrompt: return "rezept-prompt"
            case .markdown, .json: return "vorrat"
            }
        }

        var hint: String {
            switch self {
            case .recipePrompt: return "Fertiger Prompt inkl. aller Zutaten – einfach bei einer KI einfügen. Die KI darf auch Rezepte vorschlagen, für die noch etwas eingekauft werden muss, und erstellt dafür eine Einkaufsliste."
            case .markdown: return "Übersicht des Vorrats, gruppiert nach Ort – mit dem, was bald verbraucht werden sollte, ganz oben."
            case .json: return "Vollständige Sicherung – lässt sich über „Importieren“ wieder einlesen."
            }
        }
    }

    /// Zuletzt gewähltes Format wird gemerkt.
    @AppStorage("exportFormat") private var format: Format = .recipePrompt
    private let initialFormat: Format?
    @State private var onlyVisible = false
    @State private var copied = false
    @AppStorage("recipeServings") private var servings = 2
    @AppStorage("recipeWishes") private var wishes = ""

    init(initialFormat: Format? = nil, allItems: [Item], visibleItems: [Item], viewTitle: String, rules: StatusRules) {
        self.initialFormat = initialFormat
        self.allItems = allItems
        self.visibleItems = visibleItems
        self.viewTitle = viewTitle
        self.rules = rules
    }

    private var output: String {
        let records = (onlyVisible ? visibleItems : allItems).map(\.record)
        let formatter = ExportFormatter(rules: rules)
        switch format {
        case .recipePrompt:
            return AIPrompts.recipeRequest(inventoryMarkdown: formatter.markdown(records), servings: servings, wishes: wishes)
        case .markdown:
            return formatter.markdown(records)
        case .json:
            return formatter.json(records)
        }
    }

    var body: some View {
        let output = self.output

        VStack(alignment: .leading, spacing: 12) {
            Text("Exportieren & Rezeptideen").font(.title2.bold())

            HStack(spacing: 16) {
                Picker("Format", selection: $format) {
                    ForEach(Format.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()

                if visibleItems.count != allItems.count {
                    Toggle("Nur „\(viewTitle)“ (\(visibleItems.count))", isOn: $onlyVisible)
                }
            }

            Text(format.hint)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if format == .recipePrompt {
                HStack(spacing: 16) {
                    Stepper(value: $servings, in: 1...12) {
                        Text(servings == 1 ? "für 1 Person" : "für \(servings) Personen")
                    }
                    .fixedSize()
                    TextField("Wünsche", text: $wishes, prompt: Text("Wünsche, z.B. vegetarisch, schnell"))
                        .textFieldStyle(.roundedBorder)
                }
            }

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
        .onChange(of: output) { copied = false }
        .onAppear { if let initialFormat { format = initialFormat } }
        .padding(20)
        // Feste Grösse: Sonst nimmt das Sheet die Breite der längsten Textzeile an.
        .frame(width: 720, height: 600)
    }

    private func save(_ text: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(format.fileName)-\(ExportFormatter.isoDate(Date())).\(format.fileExtension)"
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
