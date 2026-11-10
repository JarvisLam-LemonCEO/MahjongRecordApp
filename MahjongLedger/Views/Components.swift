import SwiftUI

// Distinct, accessible colors for gains and losses in both system appearances.
enum LedgerStyle {
    static let teal = Color(red: 0.07, green: 0.66, blue: 0.57)
    static let darkTeal = Color(red: 0.04, green: 0.30, blue: 0.34)
    static let loss = Color(red: 0.85, green: 0.31, blue: 0.31)
    static let canvas = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
}

extension TimeRange {
    var localizedTitle: LocalizedStringKey {
        switch self {
        case .day: return "period_day"
        case .month: return "period_month"
        case .year: return "period_year"
        case .all: return "period_all"
        }
    }
}

enum DisplayFormatter {
    static func money(_ amount: Decimal, currency: String, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSDecimalNumber(decimal: amount))
            ?? "\(currency) \(NSDecimalNumber(decimal: amount))"
    }

    static func dateTime(_ date: Date, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func percent(_ ratio: Double, locale: Locale) -> String {
        ratio.formatted(.percent.precision(.fractionLength(0)).locale(locale))
    }
}

struct LedgerSurface<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LedgerStyle.surface, in: RoundedRectangle(cornerRadius: 22))
    }
}

struct SectionHeading: View {
    let title: LocalizedStringKey
    var body: some View {
        Text(title)
            .font(.title3.weight(.bold))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct RecordRow: View {
    let record: MahjongRecord
    let currency: String
    @Environment(\.locale) private var locale

    private var namedBreakdown: String {
        record.payments.map { person in
            "\(person.name)  \(DisplayFormatter.money(person.amount, currency: currency, locale: locale))"
        }.joined(separator: "  ·  ")
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: record.isWin ? "arrow.down.left" : "arrow.up.right")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(record.isWin ? LedgerStyle.teal : LedgerStyle.loss)
                .frame(width: 44, height: 44)
                .background((record.isWin ? LedgerStyle.teal : LedgerStyle.loss).opacity(0.11),
                            in: RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(record.isWin ? "win_record" : "loss_record"))
                    .font(.subheadline.weight(.semibold))
                if !record.payments.isEmpty {
                    Text(namedBreakdown)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                } else if !record.isWin {
                    Text("payee_not_specified")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(DisplayFormatter.dateTime(record.playedAt, locale: locale))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Text("\(record.isWin ? "+" : "−")\(DisplayFormatter.money(record.amount, currency: currency, locale: locale))")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(record.isWin ? LedgerStyle.teal : LedgerStyle.loss)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
