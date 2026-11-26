import SwiftUI
import VorratCore

struct SidebarView: View {
    let items: [Item]
    let rules: StatusRules
    @Binding var filter: SidebarFilter?

    var body: some View {
        let now = Date()
        let statuses = items.map { $0.status(rules, now: now) }

        List(selection: $filter) {
            Section("Übersicht") {
                Label("Alle Artikel", systemImage: "tray.full")
                    .badge(items.count)
                    .tag(SidebarFilter.all)
                ForEach([ItemStatus.expiringSoon, .expired, .forgotten], id: \.self) { status in
                    let count = statuses.filter { $0 == status }.count
                    Label {
                        Text(status.title)
                    } icon: {
                        Image(systemName: status.symbol).foregroundStyle(status.color)
                    }
                    .badge(count)
                    .tag(SidebarFilter.status(status))
                }
            }

            Section("Orte") {
                ForEach(ExportFormatter.orderedLocations(Array(Set(items.map(\.location)))), id: \.self) { location in
                    Label(location, systemImage: Self.icon(forLocation: location))
                        .badge(items.filter { $0.location == location }.count)
                        .tag(SidebarFilter.location(location))
                }
            }

            Section("Kategorien") {
                ForEach(Array(Set(items.map(\.category))).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }, id: \.self) { category in
                    Label(category, systemImage: "tag")
                        .badge(items.filter { $0.category == category }.count)
                        .tag(SidebarFilter.category(category))
                }
            }
        }
        .listStyle(.sidebar)
    }

    static func icon(forLocation location: String) -> String {
        switch location {
        case "Kühlschrank": return "refrigerator"
        case "Gefrierschrank": return "snowflake"
        case "Vorratsschrank": return "cabinet"
        default: return "shippingbox"
        }
    }
}
