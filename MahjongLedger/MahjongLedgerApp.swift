import SwiftUI
import SwiftData

@main
struct MahjongLedgerApp: App {
    @AppStorage("preferredLanguage") private var languageCode = "system"

    private var chosenLocale: Locale {
        languageCode == "system" ? .current : Locale(identifier: languageCode)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.locale, chosenLocale)
                // Rebuild tab/navigation content when the app-language setting
                // changes, rather than waiting for a relaunch or navigation.
                .id(languageCode)
        }
        .modelContainer(for: MahjongRecord.self)
    }
}
