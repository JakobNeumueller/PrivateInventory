import Foundation

/// Zustand eines Artikels. Die Reihenfolge entspricht der Dringlichkeit.
public enum ItemStatus: Int, CaseIterable, Comparable, Sendable {
    case expired = 0
    case expiringSoon = 1
    case forgotten = 2
    case ok = 3

    public static func < (lhs: ItemStatus, rhs: ItemStatus) -> Bool { lhs.rawValue < rhs.rawValue }

    public var title: String {
        switch self {
        case .expired: return "Abgelaufen"
        case .expiringSoon: return "Läuft bald ab"
        case .forgotten: return "Vergessen"
        case .ok: return "OK"
        }
    }

    /// Braucht der Artikel Aufmerksamkeit?
    public var needsAttention: Bool { self != .ok }
}

/// Regeln, nach denen der Status berechnet wird (in der App einstellbar).
public struct StatusRules: Equatable, Sendable {
    /// Ab wie vielen Tagen vor Ablauf gilt ein Artikel als „läuft bald ab".
    public var soonDays: Int
    /// Nach wie vielen Tagen ohne Verwendung gilt ein Artikel als „vergessen".
    public var forgottenDays: Int

    public init(soonDays: Int = 3, forgottenDays: Int = 30) {
        self.soonDays = soonDays
        self.forgottenDays = forgottenDays
    }

    public static let `default` = StatusRules()

    public func status(
        expiryDate: Date?,
        lastTouchedDate: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ItemStatus {
        if let expiryDate {
            let days = DayMath.days(from: now, to: expiryDate, calendar: calendar)
            if days < 0 { return .expired }
            if days <= soonDays { return .expiringSoon }
        }
        if DayMath.days(from: lastTouchedDate, to: now, calendar: calendar) > forgottenDays {
            return .forgotten
        }
        return .ok
    }

    public func status(of record: ItemRecord, now: Date = Date(), calendar: Calendar = .current) -> ItemStatus {
        status(expiryDate: record.expiryDate, lastTouchedDate: record.lastTouchedDate, now: now, calendar: calendar)
    }
}

/// Hilfsfunktionen für Tagesdifferenzen und deutsche Beschreibungen.
public enum DayMath {
    /// Ganze Kalendertage zwischen zwei Zeitpunkten (Uhrzeit wird ignoriert).
    public static func days(from: Date, to: Date, calendar: Calendar = .current) -> Int {
        let a = calendar.startOfDay(for: from)
        let b = calendar.startOfDay(for: to)
        return calendar.dateComponents([.day], from: a, to: b).day ?? 0
    }

    /// „heute", „morgen", „in 5 Tagen", „seit gestern abgelaufen", „seit 3 Tagen abgelaufen".
    public static func expiryDescription(_ expiry: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let d = days(from: now, to: expiry, calendar: calendar)
        switch d {
        case ..<(-1): return "seit \(-d) Tagen abgelaufen"
        case -1: return "seit gestern abgelaufen"
        case 0: return "läuft heute ab"
        case 1: return "läuft morgen ab"
        default: return "noch \(d) Tage"
        }
    }

    /// „heute", „gestern", „vor 12 Tagen".
    public static func agoDescription(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let d = days(from: date, to: now, calendar: calendar)
        switch d {
        case ..<1: return "heute"
        case 1: return "gestern"
        default: return "vor \(d) Tagen"
        }
    }
}
