import Foundation

/// Problem bei einem einzelnen Eintrag während des Imports.
public struct ImportIssue: Equatable, Sendable {
    /// Position des Eintrags im JSON (0-basiert), `nil` wenn das ganze Dokument betroffen ist.
    public var index: Int?
    public var message: String

    public init(index: Int?, message: String) {
        self.index = index
        self.message = message
    }
}

public struct ImportResult: Equatable, Sendable {
    public var records: [ItemRecord]
    public var issues: [ImportIssue]
}

/// Toleranter JSON-Import, gedacht für Daten, die eine KI aus einem Kassenzettel erzeugt.
///
/// Akzeptiert:
/// - ein Array von Objekten oder ein Objekt mit `items` (oder `artikel`, `products`)
/// - Text drumherum bzw. Markdown-Codeblöcke (```json … ```)
/// - englische oder deutsche Feldnamen (`name`/`produkt`, `quantity`/`menge`, …)
/// - Datumsangaben als `2026-11-26`, `26.11.2026` oder ISO 8601
/// - Mengen als Zahl oder Text (`"1,5"`)
public struct ImportParser {
    public var now: Date
    public var calendar: Calendar

    public init(now: Date = Date(), calendar: Calendar = .current) {
        self.now = now
        self.calendar = calendar
    }

    public func parse(_ text: String) -> ImportResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ImportResult(records: [], issues: [])
        }
        guard let jsonText = Self.extractJSON(from: trimmed),
              let data = jsonText.data(using: .utf8) else {
            return ImportResult(records: [], issues: [ImportIssue(index: nil, message: "Kein JSON gefunden. Erwartet wird ein Array [ … ] oder ein Objekt { \"items\": [ … ] }.")])
        }

        let root: Any
        do {
            root = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            return ImportResult(records: [], issues: [ImportIssue(index: nil, message: "Ungültiges JSON: \(Self.describe(error))")])
        }

        guard let entries = Self.entries(in: root) else {
            return ImportResult(records: [], issues: [ImportIssue(index: nil, message: "Keine Artikelliste gefunden. Erwartet wird ein Array oder ein Objekt mit \"items\".")])
        }

        var records: [ItemRecord] = []
        var issues: [ImportIssue] = []
        for (i, entry) in entries.enumerated() {
            guard let dict = entry as? [String: Any] else {
                issues.append(ImportIssue(index: i, message: "Eintrag \(i + 1) ist kein Objekt und wurde übersprungen."))
                continue
            }
            switch record(from: dict, index: i) {
            case .success(let (record, warnings)):
                records.append(record)
                issues.append(contentsOf: warnings)
            case .failure(let issue):
                issues.append(issue)
            }
        }
        return ImportResult(records: records, issues: issues)
    }

    // MARK: - Einzelner Eintrag

    private enum EntryResult {
        case success((ItemRecord, [ImportIssue]))
        case failure(ImportIssue)
    }

    private func record(from raw: [String: Any], index i: Int) -> EntryResult {
        let dict = Self.normalizedKeys(raw)
        var warnings: [ImportIssue] = []

        func string(_ keys: [String]) -> String? {
            for key in keys {
                if let value = dict[key] {
                    if let s = value as? String {
                        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !t.isEmpty { return t }
                    } else if let n = value as? NSNumber {
                        return n.stringValue
                    }
                }
            }
            return nil
        }

        func date(_ keys: [String], label: String) -> Date? {
            guard let s = string(keys) else { return nil }
            if let d = Self.parseDate(s, calendar: calendar) { return d }
            warnings.append(ImportIssue(index: i, message: "„\(s)\" ist kein gültiges Datum (\(label)) und wurde ignoriert."))
            return nil
        }

        guard let name = string(Keys.name) else {
            return .failure(ImportIssue(index: i, message: "Eintrag \(i + 1) hat keinen Namen und wurde übersprungen."))
        }

        var quantity: Double = 1
        if let q = dict.firstValue(for: Keys.quantity) {
            if let n = q as? NSNumber {
                quantity = n.doubleValue
            } else if let s = q as? String, let parsed = Self.parseNumber(s) {
                quantity = parsed
            } else {
                warnings.append(ImportIssue(index: i, message: "Menge von „\(name)\" nicht lesbar – 1 angenommen."))
            }
        }
        if quantity <= 0 {
            warnings.append(ImportIssue(index: i, message: "Menge von „\(name)\" ist nicht positiv – 1 angenommen."))
            quantity = 1
        }

        let record = ItemRecord(
            name: name,
            category: string(Keys.category) ?? Defaults.category,
            location: Defaults.normalizedLocation(string(Keys.location)),
            quantity: quantity,
            unit: string(Keys.unit) ?? Defaults.unit,
            purchaseDate: date(Keys.purchaseDate, label: "Kaufdatum") ?? calendar.startOfDay(for: now),
            expiryDate: date(Keys.expiryDate, label: "Ablaufdatum"),
            openedDate: date(Keys.openedDate, label: "Geöffnet am"),
            lastUsedDate: date(Keys.lastUsedDate, label: "Zuletzt benutzt"),
            notes: string(Keys.notes) ?? ""
        )
        return .success((record, warnings))
    }

    // MARK: - Feldnamen

    /// Alle Schlüssel werden vor dem Vergleich vereinfacht (klein, ohne `_`, `-`, Leerzeichen, Umlaute).
    enum Keys {
        static let name = ["name", "produkt", "product", "artikel", "item", "bezeichnung", "title"]
        static let category = ["category", "kategorie", "type", "typ", "gruppe"]
        static let location = ["location", "ort", "lagerort", "storage", "place"]
        static let quantity = ["quantity", "menge", "anzahl", "amount", "qty", "count"]
        static let unit = ["unit", "einheit"]
        static let purchaseDate = ["purchasedate", "kaufdatum", "gekauft", "gekauftam", "purchased", "boughtat", "bought", "date", "datum"]
        static let expiryDate = ["expirydate", "ablaufdatum", "mhd", "haltbarbis", "bestbefore", "expires", "expiry", "expiration", "expirationdate", "verbrauchsdatum"]
        static let openedDate = ["openeddate", "geoffnet", "geoffnetam", "opened", "openedat"]
        static let lastUsedDate = ["lastuseddate", "zuletztbenutzt", "lastused", "zuletztverwendet"]
        static let notes = ["notes", "note", "notiz", "notizen", "bemerkung", "kommentar", "comment"]
    }

    static func normalizedKey(_ key: String) -> String {
        key.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .filter { $0 != "_" && $0 != "-" && $0 != " " }
    }

    static func normalizedKeys(_ dict: [String: Any]) -> [String: Any] {
        var out: [String: Any] = [:]
        for (k, v) in dict where !(v is NSNull) {
            out[normalizedKey(k)] = v
        }
        return out
    }

    // MARK: - Struktur

    static func entries(in root: Any) -> [Any]? {
        if let array = root as? [Any] { return array }
        if let dict = root as? [String: Any] {
            let normalized = normalizedKeys(dict)
            for key in ["items", "artikel", "products", "produkte", "einkauf", "vorrat", "inventory"] {
                if let array = normalized[key] as? [Any] { return array }
            }
            // Einzelnes Objekt mit Namen → als Liste mit einem Eintrag behandeln.
            if normalized.firstValue(for: Keys.name) != nil { return [dict] }
        }
        return nil
    }

    /// Schneidet umgebenden Text bzw. Markdown-Codeblöcke ab (KI-Antworten enthalten oft Erklärungen).
    static func extractJSON(from text: String) -> String? {
        guard let start = text.firstIndex(where: { $0 == "[" || $0 == "{" }) else { return nil }
        let closing: Character = text[start] == "[" ? "]" : "}"
        guard let end = text.lastIndex(of: closing), end > start else { return nil }
        return String(text[start...end])
    }

    // MARK: - Werte

    static func parseNumber(_ s: String) -> Double? {
        let cleaned = s.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        // Führende Zahl nehmen, z.B. "500 g" → 500
        var numberPart = ""
        for ch in cleaned {
            if ch.isNumber || ch == "." || (ch == "-" && numberPart.isEmpty) {
                numberPart.append(ch)
            } else if !numberPart.isEmpty {
                break
            } else if ch != " " {
                return nil
            }
        }
        return Double(numberPart)
    }

    static func parseDate(_ s: String, calendar: Calendar) -> Date? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        // Volle ISO-8601-Zeitstempel
        if t.count > 10 {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = iso.date(from: t) { return d }
            iso.formatOptions = [.withInternetDateTime]
            if let d = iso.date(from: t) { return d }
        }
        // Reine Datumsangaben → lokale Mitternacht
        let patterns: [(String, [Int])] = [
            ("-", [0, 1, 2]),   // 2026-11-26
            (".", [2, 1, 0]),   // 26.11.2026
            ("/", [2, 1, 0]),   // 26/11/2026
        ]
        let datePart = t.count > 10 ? String(t.prefix(10)) : t
        for (separator, order) in patterns {
            let parts = datePart.split(separator: Character(separator)).map(String.init)
            guard parts.count == 3, let a = Int(parts[order[0]]), let m = Int(parts[order[1]]), let d = Int(parts[order[2]]) else { continue }
            var year = a
            if year < 100 { year += 2000 }
            guard (1...12).contains(m), (1...31).contains(d), (1900...2200).contains(year) else { continue }
            var comps = DateComponents()
            comps.year = year
            comps.month = m
            comps.day = d
            if let date = calendar.date(from: comps),
               calendar.component(.day, from: date) == d { // 31.02. ablehnen
                return date
            }
        }
        return nil
    }

    static func describe(_ error: Error) -> String {
        let ns = error as NSError
        if let detail = ns.userInfo["NSDebugDescription"] as? String { return detail }
        return ns.localizedDescription
    }
}

extension Dictionary where Key == String, Value == Any {
    func firstValue(for keys: [String]) -> Any? {
        for key in keys { if let v = self[key] { return v } }
        return nil
    }
}
