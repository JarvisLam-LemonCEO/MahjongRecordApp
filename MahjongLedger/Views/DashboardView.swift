import SwiftUI

struct DashboardView: View {
    let records: [MahjongRecord]
    let onAdd: () -> Void
    let onEdit: (MahjongRecord) -> Void
    let onShowHistory: () -> Void

    @AppStorage("currencyCode") private var currency = "HKD"
    @Environment(\.locale) private var locale
    @State private var period: TimeRange = .month

    private var selectedRecords: [MahjongRecord] {
        records.filter { period.contains($0.playedAt, relativeTo: .now) }
    }

    var body: some View {
        let selected = selectedRecords
        let items = selected.map(\.ledgerItem)
        let summary = LedgerCalculations.summary(of: items)
        let ranking = LedgerCalculations.payeeRanking(of: items)
        let payerRanking = LedgerCalculations.payerRanking(of: items)

        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("dashboard_title")
                            .font(.largeTitle.bold())
                        Text("dashboard_subtitle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(action: onAdd) {
                        Image(systemName: "plus")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                            .background(LedgerStyle.teal, in: Circle())
                    }
                    .accessibilityLabel(Text("new_entry"))
                }

                Picker("period_filter", selection: $period) {
                    ForEach(TimeRange.allCases) { choice in
                        Text(choice.localizedTitle).tag(choice)
                    }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 17) {
                    HStack {
                        Label("net_result", systemImage: "chart.line.uptrend.xyaxis")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Image(systemName: "suit.club.fill")
                            .font(.title2)
                            .opacity(0.5)
                    }
                    .foregroundStyle(.white.opacity(0.85))

                    Text(DisplayFormatter.money(summary.net, currency: currency, locale: locale))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    HStack(spacing: 18) {
                        Label {
                            Text("\(summary.winCount)") + Text(" ") + Text("wins_count")
                        } icon: {
                            Image(systemName: "arrow.up.right")
                        }
                        Label {
                            Text("\(summary.lossCount)") + Text(" ") + Text("losses_count")
                        } icon: {
                            Image(systemName: "arrow.down.right")
                        }
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(colors: [LedgerStyle.darkTeal, LedgerStyle.teal],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 25)
                )

                HStack(spacing: 12) {
                    moneyMetric("total_won", value: summary.totalWon, icon: "arrow.down.left", color: LedgerStyle.teal)
                    moneyMetric("total_lost", value: summary.totalLost, icon: "arrow.up.right", color: LedgerStyle.loss)
                }

                LedgerSurface {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("win_rate").font(.subheadline).foregroundStyle(.secondary)
                            Text(DisplayFormatter.percent(summary.winRate, locale: locale))
                                .font(.title2.weight(.bold))
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 5) {
                            Text("total_records").font(.subheadline).foregroundStyle(.secondary)
                            Text("\(summary.totalCount)").font(.title2.weight(.bold))
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeading(title: "top_payees")
                    Text("top_payees_description")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if ranking.isEmpty {
                        emptyBlock("no_payees", symbol: "person.2")
                    } else {
                        LedgerSurface {
                            VStack(spacing: 18) {
                                ForEach(Array(ranking.indices), id: \.self) { index in
                                    personRow(rank: index + 1, name: ranking[index].name,
                                              amount: ranking[index].totalLost,
                                              highest: ranking[0].totalLost,
                                              color: LedgerStyle.loss)
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeading(title: "top_payers")
                    Text("top_payers_description")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if payerRanking.isEmpty {
                        emptyBlock("no_payers", symbol: "person.2")
                    } else {
                        LedgerSurface {
                            VStack(spacing: 18) {
                                ForEach(Array(payerRanking.indices), id: \.self) { index in
                                    personRow(rank: index + 1, name: payerRanking[index].name,
                                              amount: payerRanking[index].totalWon,
                                              highest: payerRanking[0].totalWon,
                                              color: LedgerStyle.teal)
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        SectionHeading(title: "recent_records")
                        Button("see_all", action: onShowHistory)
                            .font(.subheadline.weight(.semibold))
                    }
                    if selected.isEmpty {
                        VStack(spacing: 12) {
                            emptyBlock("no_records", symbol: "rectangle.stack")
                            Button("add_first_record", action: onAdd)
                                .buttonStyle(.borderedProminent)
                                .tint(LedgerStyle.teal)
                        }
                    } else {
                        LedgerSurface {
                            VStack(spacing: 0) {
                                ForEach(Array(selected.indices.prefix(5)), id: \.self) { index in
                                    let record = selected[index]
                                    Button { onEdit(record) } label: {
                                        RecordRow(record: record, currency: currency)
                                            .padding(.vertical, 11)
                                    }
                                    .buttonStyle(.plain)
                                    if index < min(5, selected.count) - 1 { Divider() }
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 12)
        }
        .background(LedgerStyle.canvas)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func moneyMetric(_ title: LocalizedStringKey, value: Decimal, icon: String, color: Color) -> some View {
        LedgerSurface {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                Text(title).font(.subheadline).foregroundStyle(.secondary)
                Text(DisplayFormatter.money(value, currency: currency, locale: locale))
                    .font(.title3.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
        }
    }

    private func personRow(rank: Int, name: String, amount: Decimal,
                           highest: Decimal, color: Color) -> some View {
        let ratio = highest > 0
            ? (NSDecimalNumber(decimal: amount).doubleValue /
               NSDecimalNumber(decimal: highest).doubleValue)
            : 0.0

        return HStack(spacing: 12) {
            Text("\(rank)")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(name).font(.subheadline.weight(.semibold)).lineLimit(1)
                    Spacer(minLength: 5)
                    Text(DisplayFormatter.money(amount, currency: currency, locale: locale))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                GeometryReader { geometry in
                    Capsule().fill(color.opacity(0.1))
                        .overlay(alignment: .leading) {
                            Capsule().fill(color.opacity(0.75))
                                .frame(width: max(0, geometry.size.width * ratio))
                        }
                }
                .frame(height: 6)
            }
        }
    }

    private func emptyBlock(_ title: LocalizedStringKey, symbol: String) -> some View {
        LedgerSurface {
            HStack(spacing: 12) {
                Image(systemName: symbol).foregroundStyle(.secondary)
                Text(title).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
