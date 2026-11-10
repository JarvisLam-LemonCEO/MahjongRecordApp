import SwiftUI

struct SettingsView: View {
    @AppStorage("preferredLanguage") private var languageCode = "system"
    @AppStorage("currencyCode") private var currency = "HKD"

    var body: some View {
        Form {
            Section {
                Picker("display_language", selection: $languageCode) {
                    Text("language_system").tag("system")
                    Text("English").tag("en")
                    Text("繁體中文").tag("zh-Hant")
                    Text("简体中文").tag("zh-Hans")
                    Text("日本語").tag("ja")
                    Text("한국어").tag("ko")
                }
            } header: {
                Text("language")
            } footer: {
                Text("language_note")
            }

            Section {
                Picker("currency", selection: $currency) {
                    Text("currency_hkd").tag("HKD")
                    Text("currency_usd").tag("USD")
                    Text("currency_cny").tag("CNY")
                    Text("currency_twd").tag("TWD")
                    Text("currency_jpy").tag("JPY")
                    Text("currency_krw").tag("KRW")
                    Text("currency_sgd").tag("SGD")
                    Text("currency_eur").tag("EUR")
                    Text("currency_gbp").tag("GBP")
                }
            } header: {
                Text("currency")
            } footer: {
                Text("currency_note")
            }

            Section("storage_title") {
                HStack {
                    Text("data_storage")
                    Spacer()
                    Text("local_only")
                        .foregroundStyle(.secondary)
                }
                Text("privacy_note")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("settings_about") {
                HStack {
                    Text("app_name")
                    Spacer()
                    Text("1.4")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("tab_settings")
    }
}
