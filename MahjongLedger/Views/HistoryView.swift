import SwiftUI

struct HistoryView: View {
    let records: [MahjongRecord]
    let onAdd: () -> Void
    let onEdit: (MahjongRecord) -> Void
    let onDelete: (MahjongRecord) -> Void

    @AppStorage("currencyCode") private var currency = "HKD"
    @Environment(\.locale) private var locale
    @State private var period: TimeRange = .all
    @State private var selectedYear = Calendar.current.component(.year, from: .now)
    @State private var selectedMonth = Calendar.current.component(.month, from: .now)

    // Include years already in the ledger, the selected year, and a useful
    // range around the current year (including years with no records).
    private var availableYears: [Int] {
        let currentYear = Calendar.current.component(.year, from: .now)
        let years = records.map { Calendar.current.component(.year, from: $0.playedAt) }
            + [selectedYear, currentYear - 5, currentYear + 1]
        guard let earliest = years.min(), let latest = years.max() else {
            return [currentYear]
        }
        return Array((earliest...latest).reversed())
    }

    private var monthNames: [String] {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = .current
        return formatter.standaloneMonthSymbols
    }

    private var selectedRecords: [MahjongRecord] {
        switch period {
        case .month:
            return records.filter {
                LedgerCalculations.isInCalendarPeriod($0.playedAt, year: selectedYear, month: selectedMonth)
            }
        case .year:
            return records.filter {
                LedgerCalculations.isInCalendarPeriod($0.playedAt, year: selectedYear)
            }
        case .day:
            return records.filter { period.contains($0.playedAt, relativeTo: .now) }
        case .all:
            return records
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("period_filter", selection: $period) {
                ForEach(TimeRange.allCases) { choice in
                    Text(choice.historyLocalizedTitle).tag(choice)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)

            if period == .month || period == .year {
                HStack(spacing: 12) {
                    if period == .month {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("history_month")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Picker("history_month", selection: $selectedMonth) {
                                ForEach(1...12, id: \.self) { month in
                                    Text(monthNames.indices.contains(month - 1)
                                         ? monthNames[month - 1] : String(month))
                                        .tag(month)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text("history_year")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("history_year", selection: $selectedYear) {
                            ForEach(availableYears, id: \.self) { year in
                                Text(String(year)).tag(year)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(12)
                .background(LedgerStyle.surface, in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 18)
                .padding(.bottom, 12)
            }

            if selectedRecords.isEmpty {
                if records.isEmpty {
                    ContentUnavailableView {
                        Label("no_history_title", systemImage: "clock.arrow.circlepath")
                    } description: {
                        Text("no_history_message")
                    } actions: {
                        Button("add_first_record", action: onAdd)
                            .buttonStyle(.borderedProminent)
                            .tint(LedgerStyle.teal)
                    }
                } else {
                    ContentUnavailableView {
                        Label("history_no_matching_title", systemImage: "calendar.badge.exclamationmark")
                    } description: {
                        Text("history_no_matching_records")
                    }
                }
                Spacer()
            } else {
                List {
                    ForEach(selectedRecords, id: \.id) { record in
                        Button { onEdit(record) } label: {
                            RecordRow(record: record, currency: currency)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) { onDelete(record) } label: {
                                Label("delete", systemImage: "trash")
                            }
                            Button { onEdit(record) } label: {
                                Label("edit", systemImage: "pencil")
                            }
                            .tint(LedgerStyle.teal)
                        }
                        .contextMenu {
                            Button { onEdit(record) } label: {
                                Label("edit", systemImage: "pencil")
                            }
                            Button(role: .destructive) { onDelete(record) } label: {
                                Label("delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .background(LedgerStyle.canvas)
        .navigationTitle("tab_history")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onAdd) {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(Text("new_entry"))
            }
        }
    }
}

private extension TimeRange {
    var historyLocalizedTitle: LocalizedStringKey {
        switch self {
        case .month: return "history_month"
        case .year: return "history_year"
        default: return localizedTitle
        }
    }
}
