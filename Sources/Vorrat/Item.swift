import Foundation
import SwiftData
import VorratCore

@Model
final class Item {
    var name: String = ""
    var category: String = "Sonstiges"
    var location: String = "Vorratsschrank"
    var quantity: Double = 1
    var unit: String = "Stk"
    var purchaseDate: Date = Date()
    var expiryDate: Date?
    var openedDate: Date?
    var lastUsedDate: Date?
    var notes: String = ""
    var createdAt: Date = Date()

    init(record: ItemRecord) {
        self.createdAt = Date()
        apply(record)
    }

    func apply(_ record: ItemRecord) {
        name = record.name
        category = record.category
        location = record.location
        quantity = record.quantity
        unit = record.unit
        purchaseDate = record.purchaseDate
        expiryDate = record.expiryDate
        openedDate = record.openedDate
        lastUsedDate = record.lastUsedDate
        notes = record.notes
    }

    var record: ItemRecord {
        ItemRecord(
            name: name, category: category, location: location,
            quantity: quantity, unit: unit, purchaseDate: purchaseDate,
            expiryDate: expiryDate, openedDate: openedDate,
            lastUsedDate: lastUsedDate, notes: notes
        )
    }

    // Nicht-optionale Sortierschlüssel für die Tabelle.
    var expirySortKey: Date { expiryDate ?? .distantFuture }
    var lastTouchedDate: Date { lastUsedDate ?? purchaseDate }

    func status(_ rules: StatusRules, now: Date = Date()) -> ItemStatus {
        rules.status(expiryDate: expiryDate, lastTouchedDate: lastTouchedDate, now: now)
    }

    var quantityText: String { "\(ExportFormatter.quantityNumber(quantity)) \(unit)" }
}
