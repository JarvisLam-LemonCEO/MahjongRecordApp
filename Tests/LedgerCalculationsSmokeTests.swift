import Foundation

@main
struct CalculationSmokeTests {
    static func main() {
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 20))!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let october2025 = calendar.date(from: DateComponents(year: 2025, month: 10, day: 10))!

        func item(_ amount: Decimal, _ win: Bool, _ payments: [PersonPayment], _ date: Date = now) -> LedgerItem {
            LedgerItem(id: UUID(), amount: amount, isWin: win, payments: payments, playedAt: date)
        }
        func paid(_ name: String, _ amount: Decimal) -> PersonPayment {
            PersonPayment(name: name, amount: amount)
        }

        // Actual examples: HK$1,000 won, paid by Tim (500) and Ben (500);
        // HK$1,000 lost, paid to Alice (200) and Sam (800).
        let winPayments = [paid("Tim", 500), paid("Ben", 500)]
        let lossPayments = [paid("Alice", 200), paid("Sam", 800)]
        precondition(PersonPayments.validated(winPayments, total: 1000))
        precondition(PersonPayments.validated(lossPayments, total: 1000))
        precondition(PersonPayments.assignedTotal(winPayments) == 1000)
        precondition(PersonPayments.unassigned(total: 1000, payments: winPayments) == 0)

        let records = [item(1000, true, winPayments), item(1000, false, lossPayments)]
        let total = LedgerCalculations.summary(of: records)
        precondition(total.totalWon == 1000 && total.totalLost == 1000 && total.net == 0)
        precondition(total.winCount == 1 && total.lossCount == 1)
        let losses = LedgerCalculations.payeeRanking(of: records)
        precondition(losses.map(\.name) == ["Sam", "Alice"])
        precondition(losses.map(\.totalLost) == [800, 200])
        let wins = LedgerCalculations.payerRanking(of: records)
        precondition(wins.count == 2 && wins[0].name == "Ben" && wins[0].totalWon == 500)
        precondition(wins[1].name == "Tim" && wins[1].totalWon == 500)
        precondition(losses.reduce(Decimal.zero) { $0 + $1.totalLost } == 1000)
        precondition(wins.reduce(Decimal.zero) { $0 + $1.totalWon } == 1000)

        // Save and reload named individual amounts using the unchanged SwiftData
        // String column. Exact monetary Decimal values survive JSON round-trip.
        let encodedWin = PersonPayments.encode(winPayments)
        let encodedLoss = PersonPayments.encode(lossPayments)
        precondition(encodedWin.hasPrefix("__ML_PAYMENTS_V4__:"))
        precondition(PersonPayments.decode(encodedWin, total: 1000) == winPayments)
        precondition(PersonPayments.decode(encodedLoss, total: 1000) == lossPayments)
        let unicode = [paid("張先生", Decimal(string: "2.10")!),
                       paid("김,선우", Decimal(string: "3.75")!),
                       paid("A \"B\"", Decimal(string: "4.15")!)]
        precondition(PersonPayments.decode(PersonPayments.encode(unicode), total: 10) == unicode)
        precondition(PersonPayments.encode([]).isEmpty)
        precondition(PersonPayments.decode("", total: 1000).isEmpty)

        // Old app versions stored a plain name or a multiple-name list. They
        // still decode, with the *old* equal split only for legacy entries.
        precondition(PayeeNames.decode("Tim") == ["Tim"])
        precondition(PayeeNames.decode("").isEmpty)
        precondition(PersonPayments.decode("Alice", total: 125) == [paid("Alice", 125)])
        let legacy = PayeeNames.encode(["Tim", "Ben", "tim"])
        precondition(PersonPayments.decode(legacy, total: 1000) == winPayments)
        let oneCent = PersonPayments.decode(PayeeNames.encode(["A", "B", "C"]),
                                            total: Decimal(string: "0.01")!)
        precondition(oneCent.map(\.amount) == [Decimal(string: "0.01")!, 0, 0])
        precondition(PersonPayments.assignedTotal(oneCent) == Decimal(string: "0.01")!)

        // Optional payers/payees and partially attributed payments still keep
        // their full amount in totals; the unnamed part is not ranked.
        let partiallyNamed = [paid("Tim", 350), paid("Ben", 250)]
        precondition(PersonPayments.validated(partiallyNamed, total: 1000))
        precondition(PersonPayments.unassigned(total: 1000, payments: partiallyNamed) == 400)
        let optional = [item(1000, true, partiallyNamed), item(50, false, []),
                        item(100, false, [paid("Alice", 75)])]
        let optionalTotal = LedgerCalculations.summary(of: optional)
        precondition(optionalTotal.totalWon == 1000 && optionalTotal.totalLost == 150)
        let optionalLosses = LedgerCalculations.payeeRanking(of: optional)
        precondition(optionalLosses.count == 1 && optionalLosses[0].totalLost == 75)
        precondition(PersonPayments.unassigned(total: 100, payments: [paid("Alice", 75)]) == 25)

        // A separate entry can represent just one round, or a whole session.
        let roundRecords = [item(25, true, [paid("Tim", 25)]),
                            item(35, false, [paid("Sam", 35)]),
                            item(5, true, [])]
        let rounds = LedgerCalculations.summary(of: roundRecords)
        precondition(rounds.totalCount == 3 && rounds.net == -5)
        precondition(LedgerCalculations.payeeRanking(of: roundRecords).first?.totalLost == 35)

        // Per-person validation never silently doubles or exceeds totals.
        precondition(!PersonPayments.validated([paid("A", 700), paid("B", 500)], total: 1000))
        precondition(!PersonPayments.validated([paid("A", 0)], total: 1000))
        precondition(!PersonPayments.validated([paid("", 100)], total: 1000))
        precondition(!PersonPayments.validated([paid("Tim", 100), paid("tim", 200)], total: 1000))
        precondition(!PersonPayments.validated([paid("Tim", Decimal(string: "1.005")!)], total: 1000))
        precondition(PersonPayments.validated([], total: 1000))
        precondition(!PersonPayments.validated([], total: 0))

        // Filter both relative dashboard ranges and specifically selected
        // month / year (History v1.1 behavior must still work).
        let mixedDates = [item(12, true, [], now), item(25, false, [], yesterday),
                          item(50, false, [], october2025)]
        precondition(LedgerCalculations.filtered(mixedDates, by: .day, relativeTo: now, calendar: calendar).count == 1)
        precondition(LedgerCalculations.filtered(mixedDates, by: .month, relativeTo: now, calendar: calendar).count == 2)
        precondition(LedgerCalculations.filtered(mixedDates, by: .year, relativeTo: now, calendar: calendar).count == 2)
        precondition(LedgerCalculations.filtered(mixedDates, by: .all, relativeTo: now, calendar: calendar).count == 3)
        precondition(mixedDates.filter { LedgerCalculations.isInCalendarPeriod($0.playedAt, year: 2025, month: 10, calendar: calendar) }.count == 1)
        precondition(mixedDates.filter { LedgerCalculations.isInCalendarPeriod($0.playedAt, year: 2026, month: 11, calendar: calendar) }.count == 2)
        precondition(!LedgerCalculations.isInCalendarPeriod(now, year: 2026, month: 13, calendar: calendar))

        precondition(LedgerCalculations.parsePositiveAmount("23,50") == Decimal(string: "23.50")!)
        precondition(LedgerCalculations.parsePositiveAmount("1.234") == nil)
        precondition(LedgerCalculations.parsePositiveAmount("0") == nil)
        precondition(LedgerCalculations.parsePositiveAmount("-2") == nil)

        print("All v1.4 LedgerCalculations tests passed: exact splits, legacy data, rankings, dates and validation.")
    }
}
