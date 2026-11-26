import Foundation

/// Erzeugt Exporte des Bestands – Markdown (für Menschen und KIs) und JSON (Backup / Re-Import).
public struct ExportFormatter {
    public var rules: StatusRules
    public var now: Date
    public var calendar: Calendar

    public init(rules: StatusRules = .default, now: Date = Date(), calendar: Calendar = .current) {
        self.rules = rules
        self.now = now
        self.calendar = calendar
    }

    // MARK: - Markdown

    public func markdown(_ records: [ItemRecord]) -> String {
        var lines: [String] = []
        lines.append("# Mein Vorrat – Stand \(Self.displayDate(now, calendar: calendar))")
        lines.append("")
        lines.append("\(records.count) Artikel")

        guard !records.isEmpty else {
            lines.append("")
            lines.append("_Der Vorrat ist leer._")
            return lines.joined(separator: "\n") + "\n"
        }

        let sorted = records.sorted(by: sortOrder)

        let urgent = sorted
            .map { ($0, rules.status(of: $0, now: now, calendar: calendar)) }
            .filter { $0.1.needsAttention }
            .sorted { $0.1 < $1.1 }
        if !urgent.isEmpty {
            lines.append("")
            lines.append("## Bitte bevorzugt verwenden")
            for (record, status) in urgent {
                lines.append("- \(record.name) (\(Self.quantityText(record))) – \(record.location) – \(reason(for: record, status: status))")
            }
        }

        let grouped = Dictionary(grouping: sorted, by: \.location)
        for location in Self.orderedLocations(Array(grouped.keys)) {
            guard let items = grouped[location] else { continue }
            lines.append("")
            lines.append("## \(location)")
            for record in items {
                var line = "- \(record.name) – \(Self.quantityText(record))"
                if record.category != Defaults.category { line += " – \(record.category)" }
                if let expiry = record.expiryDate {
                    line += " – haltbar bis \(Self.displayDate(expiry, calendar: calendar))"
                }
                if record.openedDate != nil { line += " – geöffnet" }
                if !record.notes.isEmpty { line += " (\(record.notes))" }
                lines.append(line)
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private func reason(for record: ItemRecord, status: ItemStatus) -> String {
        switch status {
        case .expired, .expiringSoon:
            if let expiry = record.expiryDate {
                return DayMath.expiryDescription(expiry, now: now, calendar: calendar)
            }
            return status.title
        case .forgotten:
            let days = DayMath.days(from: record.lastTouchedDate, to: now, calendar: calendar)
            return "seit \(days) Tagen unbenutzt"
        case .ok:
            return ""
        }
    }

    private func sortOrder(_ a: ItemRecord, _ b: ItemRecord) -> Bool {
        switch (a.expiryDate, b.expiryDate) {
        case let (x?, y?) where x != y: return x < y
        case (.some, .none): return true
        case (.none, .some): return false
        default: return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    // MARK: - JSON

    /// JSON im selben Format, das der Import versteht – also verlustfrei wieder importierbar.
    public func json(_ records: [ItemRecord]) -> String {
        let file = ExportFile(
            exportedAt: Self.isoDate(now, calendar: calendar),
            items: records.map { record in
                ExportItem(
                    name: record.name,
                    category: record.category,
                    location: record.location,
                    quantity: record.quantity,
                    unit: record.unit,
                    purchaseDate: Self.isoDate(record.purchaseDate, calendar: calendar),
                    expiryDate: record.expiryDate.map { Self.isoDate($0, calendar: calendar) },
                    openedDate: record.openedDate.map { Self.isoDate($0, calendar: calendar) },
                    lastUsedDate: record.lastUsedDate.map { Self.isoDate($0, calendar: calendar) },
                    notes: record.notes.isEmpty ? nil : record.notes
                )
            }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(file), let text = String(data: data, encoding: .utf8) else {
            return "{ \"items\": [] }"
        }
        return text + "\n"
    }

    private struct ExportFile: Encodable {
        var exportedAt: String
        var items: [ExportItem]
    }

    private struct ExportItem: Encodable {
        var name: String
        var category: String
        var location: String
        var quantity: Double
        var unit: String
        var purchaseDate: String
        var expiryDate: String?
        var openedDate: String?
        var lastUsedDate: String?
        var notes: String?
    }

    // MARK: - Formatierung

    /// Standardorte zuerst in fester Reihenfolge, eigene Orte danach alphabetisch.
    public static func orderedLocations(_ locations: [String]) -> [String] {
        let known = Defaults.locations.filter { locations.contains($0) && $0 != "Sonstiges" }
        let custom = locations
            .filter { !Defaults.locations.contains($0) }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        let other = locations.contains("Sonstiges") ? ["Sonstiges"] : []
        return known + custom + other
    }

    /// „2", „1,5", „0,25" – deutsche Schreibweise, ohne unnötige Nachkommastellen.
    public static func quantityNumber(_ value: Double) -> String {
        if value == value.rounded() && abs(value) < 1e12 {
            return String(Int(value))
        }
        var text = String(format: "%.2f", value)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text.replacingOccurrences(of: ".", with: ",")
    }

    public static func quantityText(_ record: ItemRecord) -> String {
        "\(quantityNumber(record.quantity)) \(record.unit)"
    }

    public static func displayDate(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%02ld.%02ld.%04ld", c.day ?? 0, c.month ?? 0, c.year ?? 0)
    }

    public static func isoDate(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04ld-%02ld-%02ld", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
