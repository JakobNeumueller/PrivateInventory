import XCTest
@testable import VorratCore

final class VorratCoreTests: XCTestCase {
    var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Zurich")!
        return c
    }()

    func day(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    var now: Date { day(2026, 11, 26, hour: 18) }

    // MARK: - Import

    func testParsesObjectWithItems() {
        let json = """
        {"items": [
          {"name": "Vollmilch", "category": "Milchprodukte", "location": "Kühlschrank",
           "quantity": 2, "unit": "l", "purchaseDate": "2026-11-20", "expiryDate": "2026-12-05"}
        ]}
        """
        let result = ImportParser(now: now, calendar: calendar).parse(json)
        XCTAssertEqual(result.issues, [])
        XCTAssertEqual(result.records.count, 1)
        let r = result.records[0]
        XCTAssertEqual(r.name, "Vollmilch")
        XCTAssertEqual(r.category, "Milchprodukte")
        XCTAssertEqual(r.location, "Kühlschrank")
        XCTAssertEqual(r.quantity, 2)
        XCTAssertEqual(r.unit, "l")
        XCTAssertEqual(ExportFormatter.isoDate(r.purchaseDate, calendar: calendar), "2026-11-20")
        XCTAssertEqual(r.expiryDate.map { ExportFormatter.isoDate($0, calendar: calendar) }, "2026-12-05")
    }

    func testParsesPlainArrayWithDefaults() {
        let result = ImportParser(now: now, calendar: calendar).parse(#"[{"name": "Reis"}]"#)
        XCTAssertEqual(result.records.count, 1)
        let r = result.records[0]
        XCTAssertEqual(r.quantity, 1)
        XCTAssertEqual(r.unit, Defaults.unit)
        XCTAssertEqual(r.location, Defaults.location)
        XCTAssertEqual(r.category, Defaults.category)
        XCTAssertEqual(ExportFormatter.isoDate(r.purchaseDate, calendar: calendar), "2026-11-26")
        XCTAssertNil(r.expiryDate)
    }

    func testStripsMarkdownFenceAndProse() {
        let text = """
        Klar! Hier ist dein Einkauf:
        ```json
        [{"name": "Äpfel", "quantity": "1,5", "unit": "kg"}]
        ```
        Guten Appetit!
        """
        let result = ImportParser(now: now, calendar: calendar).parse(text)
        XCTAssertEqual(result.issues, [])
        XCTAssertEqual(result.records.first?.name, "Äpfel")
        XCTAssertEqual(result.records.first?.quantity, 1.5)
    }

    func testGermanKeysAndDateFormats() {
        let json = """
        [{"Produkt": "Joghurt", "Menge": 4, "Einheit": "Stk", "Ort": "fridge",
          "Kaufdatum": "24.11.2026", "MHD": "2026-12-01T00:00:00Z", "Kategorie": "Milchprodukte"}]
        """
        let result = ImportParser(now: now, calendar: calendar).parse(json)
        XCTAssertEqual(result.issues, [])
        let r = result.records[0]
        XCTAssertEqual(r.name, "Joghurt")
        XCTAssertEqual(r.quantity, 4)
        XCTAssertEqual(r.location, "Kühlschrank")
        XCTAssertEqual(ExportFormatter.isoDate(r.purchaseDate, calendar: calendar), "2026-11-24")
        XCTAssertNotNil(r.expiryDate)
    }

    func testReportsProblemsPerEntry() {
        let json = """
        [{"name": "Brot", "expiryDate": "irgendwann"}, {"quantity": 3}, 42, {"name": "Butter", "quantity": -1}]
        """
        let result = ImportParser(now: now, calendar: calendar).parse(json)
        XCTAssertEqual(result.records.map(\.name), ["Brot", "Butter"])
        XCTAssertNil(result.records[0].expiryDate)
        XCTAssertEqual(result.records[1].quantity, 1)
        XCTAssertEqual(result.issues.compactMap(\.index), [0, 1, 2, 3])
    }

    func testInvalidJSON() {
        let result = ImportParser(now: now, calendar: calendar).parse("{ name: kaputt ")
        XCTAssertTrue(result.records.isEmpty)
        XCTAssertEqual(result.issues.count, 1)
        XCTAssertNil(result.issues[0].index)
    }

    func testEmptyInputHasNoIssues() {
        let result = ImportParser(now: now, calendar: calendar).parse("   \n")
        XCTAssertTrue(result.records.isEmpty)
        XCTAssertTrue(result.issues.isEmpty)
    }

    func testRejectsImpossibleDate() {
        XCTAssertNil(ImportParser.parseDate("31.02.2026", calendar: calendar))
        XCTAssertNotNil(ImportParser.parseDate("29.02.2028", calendar: calendar))
        XCTAssertNotNil(ImportParser.parseDate("1.3.26", calendar: calendar))
    }

    func testParseNumber() {
        XCTAssertEqual(ImportParser.parseNumber("500 g"), 500)
        XCTAssertEqual(ImportParser.parseNumber("0,75"), 0.75)
        XCTAssertNil(ImportParser.parseNumber("viel"))
    }

    // MARK: - Status

    func testStatusRules() {
        let rules = StatusRules(soonDays: 3, forgottenDays: 30)
        let recent = day(2026, 11, 20)
        XCTAssertEqual(rules.status(expiryDate: day(2026, 11, 25), lastTouchedDate: recent, now: now, calendar: calendar), .expired)
        XCTAssertEqual(rules.status(expiryDate: day(2026, 11, 26, hour: 0), lastTouchedDate: recent, now: now, calendar: calendar), .expiringSoon)
        XCTAssertEqual(rules.status(expiryDate: day(2026, 11, 29), lastTouchedDate: recent, now: now, calendar: calendar), .expiringSoon)
        XCTAssertEqual(rules.status(expiryDate: day(2026, 11, 30), lastTouchedDate: recent, now: now, calendar: calendar), .ok)
        XCTAssertEqual(rules.status(expiryDate: nil, lastTouchedDate: day(2026, 10, 27), now: now, calendar: calendar), .ok)
        XCTAssertEqual(rules.status(expiryDate: nil, lastTouchedDate: day(2026, 10, 26), now: now, calendar: calendar), .forgotten)
        // Ablauf hat Vorrang vor „vergessen"
        XCTAssertEqual(rules.status(expiryDate: day(2026, 11, 27), lastTouchedDate: day(2025, 1, 1), now: now, calendar: calendar), .expiringSoon)
    }

    func testLastUsedResetsForgotten() {
        var r = ItemRecord(name: "Linsen", purchaseDate: day(2026, 1, 1))
        XCTAssertEqual(StatusRules.default.status(of: r, now: now, calendar: calendar), .forgotten)
        r.lastUsedDate = day(2026, 11, 25)
        XCTAssertEqual(StatusRules.default.status(of: r, now: now, calendar: calendar), .ok)
    }

    func testDescriptions() {
        XCTAssertEqual(DayMath.expiryDescription(day(2026, 11, 26), now: now, calendar: calendar), "läuft heute ab")
        XCTAssertEqual(DayMath.expiryDescription(day(2026, 11, 27), now: now, calendar: calendar), "läuft morgen ab")
        XCTAssertEqual(DayMath.expiryDescription(day(2026, 12, 1), now: now, calendar: calendar), "noch 5 Tage")
        XCTAssertEqual(DayMath.expiryDescription(day(2026, 11, 25), now: now, calendar: calendar), "seit gestern abgelaufen")
        XCTAssertEqual(DayMath.expiryDescription(day(2026, 11, 20), now: now, calendar: calendar), "seit 6 Tagen abgelaufen")
        XCTAssertEqual(DayMath.agoDescription(day(2026, 11, 14), now: now, calendar: calendar), "vor 12 Tagen")
    }

    // MARK: - Matching & Orte

    func testSimilarNames() {
        XCTAssertTrue(Matching.isSimilar("Milch", "Vollmilch"))
        XCTAssertTrue(Matching.isSimilar("kichererbsen", "Kichererbsen "))
        XCTAssertTrue(Matching.isSimilar("Käse", "Kase"))
        XCTAssertFalse(Matching.isSimilar("Ei", "Eisbergsalat"))
        XCTAssertFalse(Matching.isSimilar("Reis", "Nudeln"))
    }

    func testLocationNormalization() {
        XCTAssertEqual(Defaults.normalizedLocation("Fridge"), "Kühlschrank")
        XCTAssertEqual(Defaults.normalizedLocation("kühlschrank"), "Kühlschrank")
        XCTAssertEqual(Defaults.normalizedLocation("Tiefkühler"), "Gefrierschrank")
        XCTAssertEqual(Defaults.normalizedLocation("Keller"), "Keller")
        XCTAssertEqual(Defaults.normalizedLocation(nil), Defaults.location)
    }

    // MARK: - Export

    func testQuantityFormatting() {
        XCTAssertEqual(ExportFormatter.quantityNumber(2), "2")
        XCTAssertEqual(ExportFormatter.quantityNumber(1.5), "1,5")
        XCTAssertEqual(ExportFormatter.quantityNumber(0.25), "0,25")
    }

    func testMarkdownExport() {
        let records = [
            ItemRecord(name: "Vollmilch", category: "Milchprodukte", location: "Kühlschrank", quantity: 2, unit: "l",
                       purchaseDate: day(2026, 11, 24), expiryDate: day(2026, 11, 27)),
            ItemRecord(name: "Kichererbsen", category: "Konserven", location: "Vorratsschrank", quantity: 1, unit: "Dose",
                       purchaseDate: day(2026, 6, 1), expiryDate: day(2028, 6, 1)),
            ItemRecord(name: "Erbsen", location: "Gefrierschrank", quantity: 500, unit: "g", purchaseDate: day(2026, 11, 20)),
        ]
        let md = ExportFormatter(now: now, calendar: calendar).markdown(records)
        XCTAssertTrue(md.hasPrefix("# Mein Vorrat – Stand 26.11.2026"))
        XCTAssertTrue(md.contains("3 Artikel"))
        XCTAssertTrue(md.contains("## Bitte bevorzugt verwenden"))
        XCTAssertTrue(md.contains("- Vollmilch (2 l) – Kühlschrank – läuft morgen ab"))
        XCTAssertTrue(md.contains("- Kichererbsen (1 Dose) – Vorratsschrank – seit 178 Tagen unbenutzt"))
        XCTAssertTrue(md.contains("- Erbsen – 500 g"))
        // Reihenfolge der Orte
        let fridge = md.range(of: "## Kühlschrank")!.lowerBound
        let freezer = md.range(of: "## Gefrierschrank")!.lowerBound
        let pantry = md.range(of: "## Vorratsschrank")!.lowerBound
        XCTAssertTrue(fridge < freezer && freezer < pantry)
    }

    func testJSONRoundTrip() {
        let original = [
            ItemRecord(name: "Butter", category: "Milchprodukte", location: "Kühlschrank", quantity: 0.5, unit: "Pkg",
                       purchaseDate: day(2026, 11, 20, hour: 0), expiryDate: day(2026, 12, 10, hour: 0),
                       openedDate: day(2026, 11, 22, hour: 0), lastUsedDate: day(2026, 11, 25, hour: 0), notes: "Bio"),
            ItemRecord(name: "Pasta", location: "Vorratsschrank", quantity: 3, unit: "Pkg", purchaseDate: day(2026, 10, 1, hour: 0)),
        ]
        let json = ExportFormatter(now: now, calendar: calendar).json(original)
        let parsed = ImportParser(now: now, calendar: calendar).parse(json)
        XCTAssertEqual(parsed.issues, [])
        XCTAssertEqual(parsed.records, original)
    }

    func testRecipeRequestContainsInventoryAndAllowsShopping() {
        let records = [ItemRecord(name: "Kichererbsen", location: "Vorratsschrank", quantity: 2, unit: "Dose",
                                  purchaseDate: day(2026, 11, 20), expiryDate: day(2026, 11, 28))]
        let md = ExportFormatter(now: now, calendar: calendar).markdown(records)
        let prompt = AIPrompts.recipeRequest(inventoryMarkdown: md, servings: 3, wishes: "  vegetarisch ")
        XCTAssertTrue(prompt.hasSuffix(md))
        XCTAssertTrue(prompt.contains("Kichererbsen"))
        XCTAssertTrue(prompt.contains("NICHT auf das Vorhandene beschränken"))
        XCTAssertTrue(prompt.contains("Muss eingekauft werden"))
        XCTAssertTrue(prompt.contains("Einkaufsliste"))
        XCTAssertTrue(prompt.contains("für 3 Personen"))
        XCTAssertTrue(prompt.contains("Meine Wünsche: vegetarisch"))

        let plain = AIPrompts.recipeRequest(inventoryMarkdown: md)
        XCTAssertFalse(plain.contains("Personen"))
        XCTAssertFalse(plain.contains("Meine Wünsche"))
    }

    func testReceiptPromptMentionsFormat() {
        let prompt = AIPrompts.receiptToJSON(today: now, calendar: calendar)
        XCTAssertTrue(prompt.contains("\"items\""))
        XCTAssertTrue(prompt.contains("2026-11-26"))
        // Das Beispiel im Prompt muss selbst importierbar sein.
        let example = prompt.components(separatedBy: "Beispiel:").last!
        XCTAssertEqual(ImportParser(now: now, calendar: calendar).parse(example).records.count, 2)
    }
}
