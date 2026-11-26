import Foundation

/// Wie ein Artikel den Vorrat verlassen hat.
public enum RemovalOutcome: String, CaseIterable, Sendable {
    case consumed
    case discarded

    public var title: String {
        switch self {
        case .consumed: return "Verbraucht"
        case .discarded: return "Weggeworfen"
        }
    }
}

/// Ein Eintrag im Verlauf – entsteht bei „Aufgebraucht“ oder „Weggeworfen“.
public struct HistoryRecord: Equatable, Sendable {
    public var name: String
    public var category: String
    public var location: String
    public var quantity: Double
    public var unit: String
    public var outcome: RemovalOutcome
    public var date: Date
    public var wasExpired: Bool

    public init(name: String, category: String = Defaults.category, location: String = Defaults.location,
                quantity: Double = 1, unit: String = Defaults.unit, outcome: RemovalOutcome,
                date: Date = Date(), wasExpired: Bool = false) {
        self.name = name
        self.category = category
        self.location = location
        self.quantity = quantity
        self.unit = unit
        self.outcome = outcome
        self.date = date
        self.wasExpired = wasExpired
    }
}

/// Auswertung des Verlaufs: Wie viel wird verbraucht, wie viel weggeworfen?
public struct WasteStats: Equatable, Sendable {
    public struct Month: Equatable, Sendable, Identifiable {
        /// Erster Tag des Monats (lokale Mitternacht).
        public var start: Date
        public var consumed: Int
        public var discarded: Int
        public var id: Date { start }
    }

    public struct Ranked: Equatable, Sendable, Identifiable {
        public var name: String
        public var count: Int
        public var id: String { name }
    }

    public var thisMonth: Month
    public var lastMonth: Month
    /// Älteste zuerst, inklusive Monaten ohne Einträge. Der letzte Eintrag ist der aktuelle Monat.
    public var months: [Month]
    public var topDiscardedItems: [Ranked]
    public var topDiscardedCategories: [Ranked]
    public var totalConsumed: Int
    public var totalDiscarded: Int

    /// Anteil weggeworfen im aktuellen Monat (0…1), `nil` wenn noch nichts erfasst wurde.
    public var thisMonthWasteRate: Double? { Self.rate(thisMonth) }
    public var lastMonthWasteRate: Double? { Self.rate(lastMonth) }

    static func rate(_ month: Month) -> Double? {
        let total = month.consumed + month.discarded
        return total == 0 ? nil : Double(month.discarded) / Double(total)
    }

    public init(history: [HistoryRecord], now: Date = Date(), monthCount: Int = 6, topCount: Int = 5,
                calendar: Calendar = .current) {
        let currentStart = Self.monthStart(now, calendar: calendar)
        var months: [Month] = []
        for offset in stride(from: max(monthCount, 2) - 1, through: 0, by: -1) {
            let start = calendar.date(byAdding: .month, value: -offset, to: currentStart) ?? currentStart
            months.append(Month(start: start, consumed: 0, discarded: 0))
        }
        for record in history {
            let start = Self.monthStart(record.date, calendar: calendar)
            guard let index = months.firstIndex(where: { $0.start == start }) else { continue }
            switch record.outcome {
            case .consumed: months[index].consumed += 1
            case .discarded: months[index].discarded += 1
            }
        }
        self.months = Array(months.suffix(monthCount))
        self.thisMonth = months[months.count - 1]
        self.lastMonth = months[months.count - 2]

        let discarded = history.filter { $0.outcome == .discarded }
        self.totalDiscarded = discarded.count
        self.totalConsumed = history.count - discarded.count
        self.topDiscardedItems = Self.rank(discarded.map(\.name), top: topCount)
        self.topDiscardedCategories = Self.rank(discarded.map(\.category), top: topCount)
    }

    /// Zählt Namen, wobei Gross-/Kleinschreibung und Akzente ignoriert werden.
    /// Angezeigt wird die zuerst gesehene Schreibweise.
    static func rank(_ names: [String], top: Int) -> [Ranked] {
        var counts: [String: (display: String, count: Int, firstIndex: Int)] = [:]
        for (i, name) in names.enumerated() {
            let key = name.comparisonKey
            guard !key.isEmpty else { continue }
            if let existing = counts[key] {
                counts[key] = (existing.display, existing.count + 1, existing.firstIndex)
            } else {
                counts[key] = (name.trimmingCharacters(in: .whitespacesAndNewlines), 1, i)
            }
        }
        return counts.values
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.firstIndex < $1.firstIndex }
            .prefix(top)
            .map { Ranked(name: $0.display, count: $0.count) }
    }

    static func monthStart(_ date: Date, calendar: Calendar) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: comps) ?? calendar.startOfDay(for: date)
    }
}
