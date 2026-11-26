import AppKit
import Observation
import SwiftData
import SwiftUI
import VorratCore

/// Gemeinsamer Zustand für Menübefehle und Fenster (welches Sheet ist offen usw.).
@Observable
final class AppState {
    enum Sheet: Identifiable {
        case newItem
        case edit(Item)
        case importItems(prefill: String)
        case export(ExportView.Format)

        var id: String {
            switch self {
            case .newItem: return "new"
            case .edit(let item): return "edit-\(item.persistentModelID.hashValue)"
            case .importItems: return "import"
            case .export: return "export"
            }
        }
    }

    var sheet: Sheet?
}

@main
struct VorratApp: App {
    @State private var appState = AppState()
    let container: ModelContainer

    init() {
        // Als normale App mit Dock-Symbol auftreten, auch wenn per `swift run` gestartet.
        NSApplication.shared.setActivationPolicy(.regular)
        DispatchQueue.main.async { NSApp.activate(ignoringOtherApps: true) }
        container = Self.makeContainer()
    }

    var body: some Scene {
        Window("Vorrat", id: "main") {
            ContentView()
                .environment(appState)
                .frame(minWidth: 860, minHeight: 480)
        }
        .modelContainer(container)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Neuer Artikel …") { appState.sheet = .newItem }
                    .keyboardShortcut("n")
                Divider()
                Button("Einkauf importieren …") { appState.sheet = .importItems(prefill: "") }
                    .keyboardShortcut("i")
                Button("Vorrat exportieren …") { appState.sheet = .export(.markdown) }
                    .keyboardShortcut("e")
                Button("Rezeptideen (Prompt) …") { appState.sheet = .export(.recipePrompt) }
                    .keyboardShortcut("r")
            }
        }

        Settings {
            SettingsView()
        }
    }

    /// Daten liegen unter ~/Library/Application Support/Vorrat/Vorrat.store
    static func makeContainer() -> ModelContainer {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Vorrat", isDirectory: true)
        try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        let config = ModelConfiguration(url: base.appendingPathComponent("Vorrat.store"))
        do {
            let container = try ModelContainer(for: Item.self, configurations: config)
            return container
        } catch {
            fatalError("Datenbank konnte nicht geöffnet werden: \(error)")
        }
    }
}

/// Einstellungen, die an mehreren Stellen gelesen werden.
enum SettingsKey {
    static let soonDays = "soonDays"
    static let forgottenDays = "forgottenDays"
}

extension ItemStatus {
    var color: Color {
        switch self {
        case .expired: return .red
        case .expiringSoon: return .orange
        case .forgotten: return .purple
        case .ok: return .green
        }
    }

    var symbol: String {
        switch self {
        case .expired: return "xmark.octagon.fill"
        case .expiringSoon: return "clock.badge.exclamationmark.fill"
        case .forgotten: return "moon.zzz.fill"
        case .ok: return "checkmark.circle.fill"
        }
    }
}

enum Clipboard {
    static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    static func read() -> String? {
        NSPasteboard.general.string(forType: .string)
    }
}
