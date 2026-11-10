import Foundation

enum TimeRange: String, CaseIterable, Identifiable {
    case day
    case month
    case year
    case all

    var id: String { rawValue }

    func contains(_ date: Date, relativeTo now: Date, calendar: Calendar = .current) -> Bool {
        switch self {
        case .day: return calendar.isDate(date, equalTo: now, toGranularity: .day)
        case .month: return calendar.isDate(date, equalTo: now, toGranularity: .month)
        case .year: return calendar.isDate(date, equalTo: now, toGranularity: .year)
        case .all: return true
        }
    }
}

// Retain v1.0–v1.3 decoding exactly, including multiple-name JSON.
// Legacy entries have no per-person amounts; they are displayed using the
// previous equal-split convention only until they are edited and re-saved.
enum PayeeNames {
    private static let multiplePrefix = "__ML_PAYEES_V2__:"

    static func normalized(_ names: [String]) -> [String] {
        var seen = Set<String>()
        return names.compactMap { raw in
            let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            let key = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            return seen.insert(key).inserted ? name : nil
        }
    }

    static func encode(_ names: [String]) -> String {
        let uniqueNames = normalized(names)
        if uniqueNames.isEmpty { return "" }
        if uniqueNames.count == 1 { return uniqueNames[0] }
        guard let data = try? JSONEncoder().encode(uniqueNames),
              let json = String(data: data, encoding: .utf8) else {
            return uniqueNames[0]
        }
        return multiplePrefix + json
    }

    static func decode(_ stored: String) -> [String] {
        guard stored.hasPrefix(multiplePrefix) else { return normalized([stored]) }
        let payload = String(stored.dropFirst(multiplePrefix.count))
        guard let data = payload.data(using: .utf8),
              let names = try? JSONDecoder().decode([String].self, from: data) else {
            return normalized([stored])
        }
        return normalized(names)
    }
}

struct PersonPayment: Equatable {
    let name: String
    let amount: Decimal
}

// Store individual payments in the EXISTING SwiftData `payee` String column,
// with an unmistakable versioned prefix. SwiftData's persisted model has not
// changed, so the upgrade doesn't require a destructive migration.
enum PersonPayments {
    private static let prefix = "__ML_PAYMENTS_V4__:"
    private struct StoredPayment: Codable {
        let name: String
        let amountText: String
    }

    static func encode(_ payments: [PersonPayment]) -> String {
        let stored = payments.map {
            StoredPayment(name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines),
                          amountText: NSDecimalNumber(decimal: $0.amount).stringValue)
        }
        guard !stored.isEmpty else { return "" }
        guard let data = try? JSONEncoder().encode(stored),
              let json = String(data: data, encoding: .utf8) else { return "" }
        return prefix + json
    }

    static func decode(_ raw: String, total: Decimal) -> [PersonPayment] {
        guard raw.hasPrefix(prefix) else {
            // v1.3 and earlier: a single name got the entire total, and
            // multiple names were split evenly to exact cents for ranking.
            return equalSplit(names: PayeeNames.decode(raw), total: total)
        }
        let json = String(raw.dropFirst(prefix.count))
        guard let data = json.data(using: .utf8),
              let stored = try? JSONDecoder().decode([StoredPayment].self, from: data) else {
            return []
        }
        return stored.compactMap { item in
            guard let value = Decimal(string: item.amountText, locale: Locale(identifier: "en_US_POSIX")),
                  value > .zero else { return nil }
            let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            return PersonPayment(name: name, amount: value)
        }
    }

    static func equalSplit(names: [String], total: Decimal) -> [PersonPayment] {
        let distinct = PayeeNames.normalized(names)
        guard !distinct.isEmpty, total > .zero else { return [] }
        let cents = NSDecimalNumber(decimal: total * 100).int64Value
        let each = cents / Int64(distinct.count)
        let remainder = cents % Int64(distinct.count)
        return distinct.enumerated().map { index, name in
            PersonPayment(name: name,
                          amount: Decimal(each + (Int64(index) < remainder ? 1 : 0)) / 100)
        }
    }

    static func assignedTotal(_ payments: [PersonPayment]) -> Decimal {
        payments.reduce(.zero) { $0 + $1.amount }
    }

    // The unnamed part belongs to the win/loss totals, but to no person.
    static func unassigned(total: Decimal, payments: [PersonPayment]) -> Decimal {
        max(.zero, total - assignedTotal(payments))
    }

    static func validated(_ payments: [PersonPayment], total: Decimal) -> Bool {
        guard total > .zero else { return false }
        var names = Set<String>()
        for payment in payments {
            let name = payment.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            guard !name.isEmpty, names.insert(key).inserted,
                  payment.amount > .zero, payment.amount <= total,
                  // Save at most two decimal places, just like the total.
                  payment.amount * 100 == Decimal(NSDecimalNumber(decimal: payment.amount * 100).int64Value)
            else { return false }
        }
        return assignedTotal(payments) <= total
    }
}

struct LedgerItem: Identifiable {
    let id: UUID
    let amount: Decimal
    let isWin: Bool
    let payments: [PersonPayment]
    let playedAt: Date

    var payees: [String] { payments.map(\.name) }

    init(id: UUID, amount: Decimal, isWin: Bool, payments: [PersonPayment], playedAt: Date) {
        self.id = id
        self.amount = amount
        self.isWin = isWin
        self.payments = payments
        self.playedAt = playedAt
    }

    // Backward-compatible constructor for older Foundation smoke tests.
    init(id: UUID, amount: Decimal, isWin: Bool, payees: [String], playedAt: Date) {
        self.init(id: id, amount: amount, isWin: isWin,
                  payments: PersonPayments.equalSplit(names: payees, total: amount), playedAt: playedAt)
    }
}

struct LedgerSummary {
    var totalWon: Decimal = .zero
    var totalLost: Decimal = .zero
    var winCount: Int = 0
    var lossCount: Int = 0

    var net: Decimal { totalWon - totalLost }
    var totalCount: Int { winCount + lossCount }
    var winRate: Double { totalCount == 0 ? 0 : Double(winCount) / Double(totalCount) }
}

struct PayeeLoss: Identifiable {
    let name: String
    let totalLost: Decimal
    let lossCount: Int

    var id: String { name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) }
}

struct PayerWin: Identifiable {
    let name: String
    let totalWon: Decimal
    let winCount: Int

    var id: String { name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) }
}

enum LedgerCalculations {
    static func isInCalendarPeriod(
        _ date: Date,
        year: Int,
        month: Int? = nil,
        calendar: Calendar = .current
    ) -> Bool {
        if let month, !(1...12).contains(month) { return false }
        let parts = calendar.dateComponents([.year, .month], from: date)
        return parts.year == year && (month == nil || parts.month == month)
    }

    static func filtered(
        _ records: [LedgerItem],
        by period: TimeRange,
        relativeTo now: Date = .now,
        calendar: Calendar = .current
    ) -> [LedgerItem] {
        records.filter { period.contains($0.playedAt, relativeTo: now, calendar: calendar) }
    }

    static func summary(of records: [LedgerItem]) -> LedgerSummary {
        records.reduce(into: LedgerSummary()) { total, item in
            if item.isWin {
                total.totalWon += item.amount
                total.winCount += 1
            } else {
                total.totalLost += item.amount
                total.lossCount += 1
            }
        }
    }

    private struct NamedTotals {
        var displayName: String
        var amount: Decimal
        var count: Int
    }

    private static func rankings(_ records: [LedgerItem], isWin: Bool) -> [NamedTotals] {
        var grouped: [String: NamedTotals] = [:]
        for record in records where record.isWin == isWin {
            // Each named payment has its OWN amount: no artificial equal split.
            // The total of the record is never added again here.
            for person in record.payments where person.amount > .zero {
                let key = person.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                if var group = grouped[key] {
                    group.amount += person.amount
                    group.count += 1
                    grouped[key] = group
                } else {
                    grouped[key] = NamedTotals(displayName: person.name, amount: person.amount, count: 1)
                }
            }
        }
        return grouped.values.sorted {
            if $0.amount != $1.amount { return $0.amount > $1.amount }
            return $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
        }
    }

    static func payeeRanking(of records: [LedgerItem]) -> [PayeeLoss] {
        rankings(records, isWin: false).map {
            PayeeLoss(name: $0.displayName, totalLost: $0.amount, lossCount: $0.count)
        }
    }

    static func payerRanking(of records: [LedgerItem]) -> [PayerWin] {
        rankings(records, isWin: true).map {
            PayerWin(name: $0.displayName, totalWon: $0.amount, winCount: $0.count)
        }
    }

    static func parsePositiveAmount(_ raw: String) -> Decimal? {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard normalized.range(of: #"^\d+(\.\d{1,2})?$"#, options: .regularExpression) != nil,
              let amount = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")),
              amount > .zero,
              amount < Decimal(1_000_000_000_000) else {
            return nil
        }
        return amount
    }
}
