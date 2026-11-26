import Foundation
import SwiftData
import VorratCore

/// Verlaufseintrag: ein Artikel wurde verbraucht oder weggeworfen.
@Model
final class HistoryEntry {
    var name: String = ""
    var category: String = "Sonstiges"
    var location: String = "Vorratsschrank"
    var quantity: Double = 1
    var unit: String = "Stk"
    /// `RemovalOutcome.rawValue` – als String gespeichert, damit das Schema einfach bleibt.
    var outcomeRaw: String = "consumed"
    var date: Date = Date()
    var wasExpired: Bool = false

    init(item: Item, outcome: RemovalOutcome, wasExpired: Bool, date: Date = Date()) {
        self.name = item.name
        self.category = item.category
        self.location = item.location
        self.quantity = item.quantity
        self.unit = item.unit
        self.outcomeRaw = outcome.rawValue
        self.date = date
        self.wasExpired = wasExpired
    }

    var outcome: RemovalOutcome { RemovalOutcome(rawValue: outcomeRaw) ?? .consumed }

    var record: HistoryRecord {
        HistoryRecord(name: name, category: category, location: location, quantity: quantity,
                      unit: unit, outcome: outcome, date: date, wasExpired: wasExpired)
    }
}
