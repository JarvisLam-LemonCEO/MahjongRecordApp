import Foundation
import SwiftData

@Model
final class MahjongRecord {
    @Attribute(.unique) var id: UUID
    var amountText: String
    var isWin: Bool
    // Storage schema is intentionally unchanged. V4 stores per-person payment
    // amounts as prefixed JSON; v1.0–v1.3 plain names remain readable.
    var payee: String
    var playedAt: Date
    var createdAt: Date

    init(amount: Decimal, isWin: Bool, payments: [PersonPayment], playedAt: Date) {
        self.id = UUID()
        self.amountText = NSDecimalNumber(decimal: amount).stringValue
        self.isWin = isWin
        self.payee = PersonPayments.encode(payments)
        self.playedAt = playedAt
        self.createdAt = .now
    }

    var amount: Decimal {
        Decimal(string: amountText, locale: Locale(identifier: "en_US_POSIX")) ?? .zero
    }

    var payments: [PersonPayment] { PersonPayments.decode(payee, total: amount) }
    var people: [String] { payments.map(\.name) }
    var payees: [String] { isWin ? [] : people }
    var payers: [String] { isWin ? people : [] }

    var ledgerItem: LedgerItem {
        LedgerItem(id: id, amount: amount, isWin: isWin,
                   payments: payments, playedAt: playedAt)
    }

    func update(amount: Decimal, isWin: Bool, payments: [PersonPayment], playedAt: Date) {
        amountText = NSDecimalNumber(decimal: amount).stringValue
        self.isWin = isWin
        self.payee = PersonPayments.encode(payments)
        self.playedAt = playedAt
    }
}
