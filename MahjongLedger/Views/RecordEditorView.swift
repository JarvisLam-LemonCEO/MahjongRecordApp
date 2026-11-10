import SwiftUI
import SwiftData

// Editor-only value type. The persisted representation remains a single
// versioned String, keeping existing v1.0-v1.3 SwiftData stores compatible.
private struct PaymentDraft: Identifiable {
    let id: UUID
    var name: String
    var amountInput: String

    init(id: UUID = UUID(), name: String = "", amountInput: String = "") {
        self.id = id
        self.name = name
        self.amountInput = amountInput
    }

    init(_ payment: PersonPayment) {
        self.init(name: payment.name,
                  amountInput: NSDecimalNumber(decimal: payment.amount).stringValue)
    }
}

struct RecordEditorView: View {
    let record: MahjongRecord?
    let previousRecords: [MahjongRecord]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @AppStorage("currencyCode") private var currency = "HKD"

    @State private var amountInput: String
    @State private var isWin: Bool
    @State private var winDrafts: [PaymentDraft]
    @State private var lossDrafts: [PaymentDraft]
    @State private var playedAt: Date
    @State private var errorKey: String?
    @State private var showingError = false

    init(record: MahjongRecord?, previousRecords: [MahjongRecord]) {
        self.record = record
        self.previousRecords = previousRecords
        _amountInput = State(initialValue: record?.amountText ?? "")
        _isWin = State(initialValue: record?.isWin ?? true)
        let existing = record?.payments.map(PaymentDraft.init) ?? []
        _winDrafts = State(initialValue: (record?.isWin ?? true) ? existing : [])
        _lossDrafts = State(initialValue: (record?.isWin == false) ? existing : [])
        _playedAt = State(initialValue: record?.playedAt ?? .now)
    }

    // Switching Win/Loss keeps the two in-progress breakdowns distinct.
    // This avoids treating someone who paid you as a loss payee (or vice versa).
    private var activeDrafts: [PaymentDraft] { isWin ? winDrafts : lossDrafts }

    private var pastNames: [String] {
        let names = previousRecords.filter { $0.isWin == isWin }.flatMap(\.people)
        return Array(PayeeNames.normalized(names).prefix(20))
    }

    private func containsName(_ name: String) -> Bool {
        let target = normalizedKey(name)
        return activeDrafts.contains { normalizedKey($0.name) == target }
    }

    private func normalizedKey(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private func appendPerson(_ name: String = "") {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.isEmpty || !containsName(name) else { return }
        let draft = PaymentDraft(name: name)
        if isWin { winDrafts.append(draft) }
        else { lossDrafts.append(draft) }
    }

    private func removePerson(id: UUID) {
        if isWin { winDrafts.removeAll { $0.id == id } }
        else { lossDrafts.removeAll { $0.id == id } }
    }

    // The total is user-entered. Any money not attributed to a named person
    // remains part of the result, but is excluded from the person rankings.
    private var enteredTotal: Decimal? { LedgerCalculations.parsePositiveAmount(amountInput) }

    private var assignedTotal: Decimal {
        activeDrafts.reduce(.zero) { subtotal, draft in
            subtotal + (LedgerCalculations.parsePositiveAmount(draft.amountInput) ?? .zero)
        }
    }

    private var unassignedAmount: Decimal {
        guard let total = enteredTotal else { return .zero }
        return max(.zero, total - assignedTotal)
    }

    var body: some View {
        Form {
            Section {
                Picker("result_label", selection: $isWin) {
                    Text("win").tag(true)
                    Text("loss").tag(false)
                }
                .pickerStyle(.segmented)
                .padding(.vertical, 5)
            } header: {
                Text("result_label")
            }

            Section {
                HStack {
                    Text(currency)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    TextField("amount_placeholder", text: $amountInput)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.title2.weight(.semibold))
                        .accessibilityLabel(Text("money_amount"))
                }
            } header: {
                Text("total_record_amount")
            } footer: {
                Text("record_scope_hint")
            }

            Section {
                ForEach(isWin ? $winDrafts : $lossDrafts) { $draft in
                    HStack(spacing: 10) {
                        TextField("person_name", text: $draft.name)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .frame(maxWidth: .infinity, alignment: .leading)

                        TextField("amount_placeholder", text: $draft.amountInput)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 106)
                            .accessibilityLabel(Text("person_amount"))

                        Button(role: .destructive) {
                            removePerson(id: draft.id)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(LedgerStyle.loss)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(Text("remove_person"))
                    }
                }

                Button {
                    appendPerson()
                } label: {
                    Label("add_person_amount", systemImage: "plus.circle.fill")
                }

                if !pastNames.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(LocalizedStringKey(isWin ? "previous_payers" : "previous_payees"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(pastNames, id: \.self) { name in
                                    Button {
                                        appendPerson(name)
                                    } label: {
                                        HStack(spacing: 5) {
                                            if containsName(name) {
                                                Image(systemName: "checkmark")
                                            }
                                            Text(name)
                                        }
                                    }
                                    .font(.footnote)
                                    .buttonStyle(.bordered)
                                    .tint(containsName(name) ? LedgerStyle.teal : .secondary)
                                    .disabled(containsName(name))
                                }
                            }
                        }
                    }
                }

                HStack {
                    Text("assigned_amount")
                    Spacer()
                    Text(DisplayFormatter.money(assignedTotal, currency: currency, locale: locale))
                        .fontWeight(.semibold)
                }

                HStack {
                    Text("unassigned_amount")
                    Spacer()
                    Text(DisplayFormatter.money(unassignedAmount, currency: currency, locale: locale))
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }

                if let total = enteredTotal, assignedTotal > total {
                    Label("amounts_exceed_total", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(LedgerStyle.loss)
                        .font(.footnote)
                }
            } header: {
                Text(LocalizedStringKey(isWin ? "payer_label" : "payee_label"))
            } footer: {
                Text("split_optional_hint")
            }

            Section("date_time") {
                DatePicker("date_time", selection: $playedAt,
                           displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(Text(LocalizedStringKey(record == nil ? "new_entry" : "edit_entry")))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("save") { save() }
                    .fontWeight(.bold)
            }
        }
        .alert("error", isPresented: $showingError) {
            Button("ok", role: .cancel) { }
        } message: {
            Text(LocalizedStringKey(errorKey ?? "saving_failed"))
        }
    }

    private func save() {
        guard let total = enteredTotal else {
            showError("invalid_amount")
            return
        }

        var payments: [PersonPayment] = []
        for draft in activeDrafts {
            let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty,
                  let amount = LedgerCalculations.parsePositiveAmount(draft.amountInput) else {
                showError("invalid_person_amount")
                return
            }
            payments.append(PersonPayment(name: name, amount: amount))
        }

        guard PersonPayments.validated(payments, total: total) else {
            showError(PersonPayments.assignedTotal(payments) > total
                      ? "amounts_exceed_total" : "duplicate_person")
            return
        }

        if let record {
            record.update(amount: total, isWin: isWin, payments: payments, playedAt: playedAt)
        } else {
            let entry = MahjongRecord(amount: total, isWin: isWin,
                                      payments: payments, playedAt: playedAt)
            modelContext.insert(entry)
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            showError("saving_failed")
        }
    }

    private func showError(_ key: String) {
        errorKey = key
        showingError = true
    }
}
