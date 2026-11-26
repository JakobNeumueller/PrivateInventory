import Foundation
import SwiftData
import VorratCore

/// Gemeinsame Aktionen für Tabelle und Heute-Übersicht.
/// Alles läuft über denselben ModelContext – ⌘Z macht es rückgängig.
struct InventoryActions {
    let context: ModelContext
    let rules: StatusRules

    func markUsed(_ items: [Item]) {
        let now = Date()
        for item in items { item.lastUsedDate = now }
    }

    /// Menge −1; bei Menge ≤ 1 gilt der Artikel als aufgebraucht.
    func decrement(_ items: [Item]) {
        let now = Date()
        for item in items {
            if item.quantity > 1 {
                item.quantity -= 1
                item.lastUsedDate = now
            } else {
                remove([item], outcome: .consumed)
            }
        }
    }

    /// Entfernt Artikel. Mit `outcome` wird ein Verlaufseintrag für die Statistik geschrieben,
    /// ohne (`nil`) gilt es als Korrektur einer Fehleingabe.
    func remove(_ items: [Item], outcome: RemovalOutcome?) {
        let now = Date()
        for item in items {
            if let outcome {
                let expired = item.status(rules, now: now) == .expired
                context.insert(HistoryEntry(item: item, outcome: outcome, wasExpired: expired, date: now))
            }
            context.delete(item)
        }
    }
}
