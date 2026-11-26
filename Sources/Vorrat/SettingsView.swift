import SwiftUI

struct SettingsView: View {
    @AppStorage(SettingsKey.soonDays) private var soonDays = 3
    @AppStorage(SettingsKey.forgottenDays) private var forgottenDays = 30

    var body: some View {
        Form {
            Section {
                Stepper(value: $soonDays, in: 0...60) {
                    LabeledContent("„Läuft bald ab“", value: "\(soonDays) Tage vor Ablauf")
                }
                Stepper(value: $forgottenDays, in: 7...365, step: 7) {
                    LabeledContent("„Vergessen“", value: "nach \(forgottenDays) Tagen ohne Verwendung")
                }
            } footer: {
                Text("„Vergessen“ zählt ab dem letzten „Heute benutzt“ – oder ab dem Kaufdatum, falls der Artikel noch nie benutzt wurde.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .padding(.vertical)
    }
}
