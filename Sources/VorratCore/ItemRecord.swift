import Foundation

/// Plattformunabhängige Darstellung eines Vorrats-Artikels.
/// Wird für Import, Export und Status-Berechnung verwendet – das SwiftData-Modell
/// der App lässt sich verlustfrei in diese Struktur umwandeln und zurück.
public struct ItemRecord: Equatable, Sendable {
    public var name: String
    public var category: String
    public var location: String
    public var quantity: Double
    public var unit: String
    public var purchaseDate: Date
    public var expiryDate: Date?
    public var openedDate: Date?
    public var lastUsedDate: Date?
    public var notes: String

    public init(
        name: String,
        category: String = Defaults.category,
        location: String = Defaults.location,
        quantity: Double = 1,
        unit: String = Defaults.unit,
        purchaseDate: Date = Date(),
        expiryDate: Date? = nil,
        openedDate: Date? = nil,
        lastUsedDate: Date? = nil,
        notes: String = ""
    ) {
        self.name = name
        self.category = category
        self.location = location
        self.quantity = quantity
        self.unit = unit
        self.purchaseDate = purchaseDate
        self.expiryDate = expiryDate
        self.openedDate = openedDate
        self.lastUsedDate = lastUsedDate
        self.notes = notes
    }

    /// Letzter Zeitpunkt, an dem der Artikel „angefasst" wurde (benutzt oder gekauft).
    public var lastTouchedDate: Date { lastUsedDate ?? purchaseDate }
}

/// Standardwerte und Vorschlagslisten.
public enum Defaults {
    public static let category = "Sonstiges"
    public static let location = "Vorratsschrank"
    public static let unit = "Stk"

    public static let locations = ["Kühlschrank", "Gefrierschrank", "Vorratsschrank", "Sonstiges"]

    public static let categories = [
        "Milchprodukte", "Gemüse", "Obst", "Fleisch & Fisch", "Brot & Backwaren",
        "Konserven", "Trockenware", "Nudeln & Reis", "Gewürze & Saucen",
        "Süsses & Snacks", "Getränke", "Tiefkühl", "Sonstiges",
    ]

    public static let units = ["Stk", "g", "kg", "ml", "l", "Pkg", "Dose", "Glas", "Flasche", "Bund"]

    /// Bringt Orts-Angaben (z.B. von einer KI: "fridge", "Schrank") auf die Standardnamen.
    public static func normalizedLocation(_ raw: String?) -> String {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return location }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = trimmed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        switch key {
        case "kuhlschrank", "kuehlschrank", "fridge", "refrigerator", "kuhl", "gekuhlt":
            return "Kühlschrank"
        case "gefrierschrank", "tiefkuhler", "tiefkuhlschrank", "tiefkuhltruhe", "freezer", "tiefkuhl", "gefroren":
            return "Gefrierschrank"
        case "vorratsschrank", "schrank", "vorrat", "vorratskammer", "speisekammer", "pantry", "cupboard", "kuchenschrank":
            return "Vorratsschrank"
        case "sonstiges", "other", "andere":
            return "Sonstiges"
        default:
            return trimmed
        }
    }
}

extension String {
    /// Vergleichsschlüssel ohne Gross-/Kleinschreibung und Akzente.
    var comparisonKey: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}

public enum Matching {
    /// Findet vermutlich gleiche Artikel ("Milch" ↔ "Vollmilch", "Kichererbsen" ↔ "kichererbsen").
    public static func isSimilar(_ a: String, _ b: String) -> Bool {
        let ka = a.comparisonKey, kb = b.comparisonKey
        guard !ka.isEmpty, !kb.isEmpty else { return false }
        if ka == kb { return true }
        // Teilwort nur ab 4 Zeichen, damit z.B. "Ei" nicht überall passt.
        if ka.count >= 4, kb.contains(ka) { return true }
        if kb.count >= 4, ka.contains(kb) { return true }
        return false
    }
}
