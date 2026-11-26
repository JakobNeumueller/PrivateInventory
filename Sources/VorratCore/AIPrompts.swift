import Foundation

/// Fertige Texte zum Kopieren für eine beliebige KI (ChatGPT, Claude, …).
public enum AIPrompts {
    /// Prompt, den man zusammen mit einem Foto des Kassenzettels an eine KI schickt.
    public static func receiptToJSON(today: Date = Date(), calendar: Calendar = .current) -> String {
        let date = ExportFormatter.isoDate(today, calendar: calendar)
        return """
        Ich schicke dir ein Foto meines Kassenzettels. Wandle alle Lebensmittel und Haushaltsvorräte darauf in JSON um, damit ich sie in meine Vorrats-App importieren kann.

        Regeln:
        - Antworte NUR mit dem JSON, ohne Erklärung.
        - Format: {"items": [ … ]}
        - Felder pro Artikel:
          - "name" (Pflicht): verständlicher Produktname auf Deutsch, ohne Markenkürzel/Codes (z.B. "Vollmilch" statt "VOLLM.3,5% 1L")
          - "category": eine von \(Defaults.categories.map { "\"\($0)\"" }.joined(separator: ", "))
          - "location": eine von \(Defaults.locations.filter { $0 != "Sonstiges" }.map { "\"\($0)\"" }.joined(separator: ", ")) – wo man das Produkt üblicherweise lagert
          - "quantity": Zahl (z.B. 2 bei zwei Packungen, 500 bei 500 g)
          - "unit": eine von \(Defaults.units.map { "\"\($0)\"" }.joined(separator: ", "))
          - "purchaseDate": Kaufdatum vom Beleg im Format YYYY-MM-DD (falls nicht lesbar: \(date))
          - "expiryDate": realistisch geschätztes Mindesthaltbarkeitsdatum ab Kaufdatum im Format YYYY-MM-DD (frische Ware kurz, Konserven/Trockenware lang). Weglassen, wenn sinnvoll keine Schätzung möglich ist.
          - "notes": optional, z.B. "Haltbarkeit geschätzt"
        - Pfand, Tragetaschen, Rabatte und Nicht-Lebensmittel ohne Vorratsbezug weglassen.
        - Mehrfach gekaufte gleiche Artikel zu einem Eintrag mit passender Menge zusammenfassen.

        Beispiel:
        {"items": [
          {"name": "Vollmilch", "category": "Milchprodukte", "location": "Kühlschrank", "quantity": 2, "unit": "l", "purchaseDate": "\(date)", "expiryDate": "2026-12-05"},
          {"name": "Kichererbsen", "category": "Konserven", "location": "Vorratsschrank", "quantity": 1, "unit": "Dose", "purchaseDate": "\(date)", "expiryDate": "2028-06-30"}
        ]}
        """
    }

    /// Wird optional vor den Markdown-Export gestellt.
    public static let recipeSuggestions = """
    Hier ist mein aktueller Vorrat. Schlage mir 3–5 Rezepte vor, die möglichst viel davon verwenden – vor allem die Artikel unter „Bitte bevorzugt verwenden". Gib zu jedem Rezept an, welche Zutaten aus meinem Vorrat es nutzt und was ich ggf. noch zukaufen müsste (möglichst wenig). Grundzutaten wie Salz, Pfeffer, Öl und Wasser kannst du als vorhanden annehmen.

    ---

    """
}
