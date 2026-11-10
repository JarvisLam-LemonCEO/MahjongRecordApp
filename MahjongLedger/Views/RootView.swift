import SwiftUI
import SwiftData

private struct EntrySelection: Identifiable {
    let id = UUID()
    let record: MahjongRecord?
}

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MahjongRecord.playedAt, order: .reverse) private var records: [MahjongRecord]
    @State private var tab = 0
    @State private var editorSelection: EntrySelection?
    @State private var deleteTarget: MahjongRecord?
    @State private var showingDeleteAlert = false

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack {
                DashboardView(
                    records: records,
                    onAdd: { editorSelection = EntrySelection(record: nil) },
                    onEdit: { editorSelection = EntrySelection(record: $0) },
                    onShowHistory: { tab = 1 }
                )
            }
            .tabItem { Label("tab_home", systemImage: "square.grid.2x2.fill") }
            .tag(0)

            NavigationStack {
                HistoryView(
                    records: records,
                    onAdd: { editorSelection = EntrySelection(record: nil) },
                    onEdit: { editorSelection = EntrySelection(record: $0) },
                    onDelete: { record in
                        deleteTarget = record
                        showingDeleteAlert = true
                    }
                )
            }
            .tabItem { Label("tab_history", systemImage: "clock.arrow.circlepath") }
            .tag(1)

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("tab_settings", systemImage: "gearshape.fill") }
            .tag(2)
        }
        .tint(LedgerStyle.teal)
        .sheet(item: $editorSelection) { selection in
            NavigationStack {
                RecordEditorView(record: selection.record, previousRecords: records)
            }
        }
        .alert("delete_record_title", isPresented: $showingDeleteAlert) {
            Button("delete", role: .destructive) {
                guard let target = deleteTarget else { return }
                modelContext.delete(target)
                try? modelContext.save()
                deleteTarget = nil
            }
            Button("cancel", role: .cancel) { deleteTarget = nil }
        } message: {
            Text("delete_record_message")
        }
    }
}
