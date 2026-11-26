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

    /// Fertiger Prompt für Rezeptvorschläge inkl. aktuellem Vorrat.
    /// Erlaubt ausdrücklich Rezepte, für die noch eingekauft werden muss – fehlende Zutaten werden ausgewiesen.
    /// - Parameters:
    ///   - inventoryMarkdown: Ergebnis von `ExportFormatter.markdown(_:)`
    ///   - servings: Anzahl Personen (`nil` = keine Angabe)
    ///   - wishes: freie Wünsche, z.B. „vegetarisch, max. 30 Minuten"
    public static func recipeRequest(inventoryMarkdown: String, servings: Int? = nil, wishes: String = "") -> String {
        var lines: [String] = []
        lines.append("Ich suche Rezeptideen. Unten findest du meinen aktuellen Vorrat (Kühlschrank, Gefrierschrank, Vorratsschrank).")
        lines.append("")
        lines.append("So wünsche ich mir die Vorschläge:")
        lines.append("- Schlage 4–6 Rezepte vor, die möglichst viel aus meinem Vorrat verwenden – vor allem die Artikel unter „Bitte bevorzugt verwenden“, weil sie bald ablaufen oder schon lange unbenutzt herumliegen.")
        lines.append("- Du musst dich NICHT auf das Vorhandene beschränken: Wenn ein Rezept mit ein paar zusätzlichen Zutaten deutlich besser oder überhaupt erst möglich wird, schlag es trotzdem vor – ich kann noch einkaufen gehen.")
        lines.append("- Mische: mindestens ein Rezept, das komplett mit dem Vorhandenen auskommt, und einige, für die nur wenige Zutaten fehlen.")
        lines.append("- Gib pro Rezept an:")
        lines.append("  - Name und eine kurze Beschreibung")
        lines.append("  - ungefähre Zubereitungszeit")
        lines.append("  - **Aus dem Vorrat:** welche meiner Artikel verwendet werden")
        lines.append("  - **Muss eingekauft werden:** fehlende Zutaten mit Menge (oder „nichts“)")
        lines.append("  - kurze Zubereitungsschritte")
        lines.append("- Am Ende: eine zusammengefasste **Einkaufsliste** mit allen fehlenden Zutaten, sortiert nach Supermarkt-Bereich, damit ich sie direkt mitnehmen kann.")
        lines.append("- Salz, Pfeffer, Speiseöl und Wasser kannst du als vorhanden annehmen.")
        lines.append("- Abgelaufene Artikel nur einplanen, wenn sie typischerweise noch gut sind (z.B. Trockenware nach dem MHD) – und weise darauf hin, sie vorher zu prüfen.")
        if let servings, servings > 0 {
            lines.append("- Mengenangaben bitte für \(servings) \(servings == 1 ? "Person" : "Personen").")
        }
        let trimmedWishes = wishes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedWishes.isEmpty {
            lines.append("- Meine Wünsche: \(trimmedWishes)")
        }
        lines.append("")
        lines.append("---")
        lines.append("")
        return lines.joined(separator: "\n") + "\n" + inventoryMarkdown
    }
}
