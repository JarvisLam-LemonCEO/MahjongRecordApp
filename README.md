# Mahjong Ledger / 麻雀戰績 — v1.4

A native SwiftUI + SwiftData iPhone app for recording Mahjong wins, losses, and the *actual amounts* paid or received from different people. The project targets iOS 17+ and includes English, Traditional Chinese, Simplified Chinese, Japanese, and Korean.

## Open and run

1. On a Mac with Xcode 15 or newer, extract the ZIP and open `MahjongLedger.xcodeproj`.
2. Choose the MahjongLedger scheme and an iPhone simulator (iOS 17 or newer), then press **Run (⌘R)**.
3. For your own iPhone, select your Development Team in the app target's Signing & Capabilities settings. Change the example `com.example.MahjongLedger` bundle identifier if necessary.

## New in v1.4 — actual money amounts per person

Every record still has exactly **one total Win or Loss amount**, plus optional, individually named allocations. You do **not** have to split the money equally.

**Win example**

- Result: Win
- Total: HK$1,000
- Person 1: Tim paid HK$500
- Person 2: Ben paid HK$500
- Dashboard: **HK$1,000 won**, not HK$2,000
- Payer ranking: Tim HK$500; Ben HK$500

**Loss example**

- Result: Loss
- Total: HK$1,000
- Person 1: HK$200 paid to Alice
- Person 2: HK$800 paid to Sam
- Dashboard: **HK$1,000 lost**, not HK$2,000
- Payee ranking: Sam HK$800; Alice HK$200

### Different Mahjong game/payment styles

- **Per round:** Enter a record for each round, such as a HK$50 win paid by the winner's opponent. Enter just one person if applicable, or multiple people with their exact amounts.
- **Per session:** Enter one record for the overall result, optionally dividing it among multiple named people with their real amounts.
- **Total only / unknown people:** Enter a total with *no people* — both payer and payee lists are optional.
- **Partially known:** You can save a total of HK$1,000 with just HK$600 assigned to named people. The other HK$400 is included in the win/loss totals, but excluded from person rankings. The form displays this as “Not assigned to anyone.”
- **Validation:** Individual amounts must be positive numbers with at most two decimal places, no duplicate names, and their sum cannot exceed the record total. Tap **Add person & amount** to add entries; remove unwanted rows with the minus icon. Tapping a previously used name adds it with an empty amount ready to enter.

The History and dashboard recent-record rows display each person's name **and their own amount**, and both win and loss rankings use real individual amounts, not equal splits.

## Existing record compatibility

The original SwiftData record schema is unchanged. Versioned JSON for new amounts is stored inside the existing `payee` String field. **Existing v1.0–v1.3 records can still be read**:

- A record with a single old name attributes the full total to that name.
- A record with multiple old names had no individual amounts, so it retains v1.3's equal-split convention when displayed and ranked. If you edit it, the equal amounts appear prefilled; replace them with the actual amounts and save.
- Old unnamed records remain unnamed. Upgrading does not require deleting records or reinstalling the app.

## Language selector — updates immediately

Settings > **App Language** offers Follow System, English, 繁體中文, 简体中文, 日本語, and 한국어. The app's root view is rebuilt when the saved language changes while the selected locale is injected into the whole view tree; this is intended to refresh existing tabs/navigation labels, form labels, dates, month names, and settings without a force quit. Switching language resets the current tab to Home; the selection persists across launches. The behavior must still be verified on an iOS Simulator or device because this build environment has no Apple SDK.

## All existing features

- Dashboard filter: Day, Month, Year, All Time (relative to today).
- Dashboard: net result, won/lost totals, win rate and record counts, payee ranking and new payer ranking, recent entries.
- History: Today / specific Month+Year / specific Year / All Time, including years in older records. Tap to edit; swipe or long press to delete.
- Record entry: Win/Loss, total amount, optional people+amounts, date/time picker defaulted to now. Person lists on the Win and Loss side stay separate while editing.
- Local storage in SwiftData, no login, network, cloud service, or external packages.
- Currency display setting (HKD by default, plus USD, CNY, TWD, JPY, KRW, SGD, EUR, GBP).

## Financial and data caveats

- Only **one currency** is stored in the ledger. Changing the currency setting changes display labels but **does not convert historical numbers**.
- Amounts use decimal string storage, not binary floating point. Input is restricted to two decimal places, including JPY/KRW even though these may display as whole units.
- One entry describes one net Win or Loss. It does **not** settle debts between several players automatically, track who won every Mahjong hand, or combine a mixed win/loss round into one entry. To track separate rounds, enter separate records.
- Unnamed amounts count toward the overall totals but not the person rankings.
- App data remains local to the installed app. Back up your phone normally; CSV export and iCloud sync are not yet included.

## Source layout

- `MahjongLedger/Models/LedgerCalculations.swift` — pure-Foundation amount validation, legacy and V4 person-payment serialization, totals, filters, and rankings.
- `MahjongLedger/Models/MahjongRecord.swift` — SwiftData persisted model, with no schema-breaking modifications.
- `MahjongLedger/Views/RecordEditorView.swift` — individually editable person/amount rows, with validation.
- `MahjongLedger/Views/Components.swift` — history/recent display of per-person values.
- `MahjongLedger/Views/DashboardView.swift` — summary, loss payee and win payer leaderboards.
- `MahjongLedger/MahjongLedgerApp.swift` — reactive localization and view rebuild.
- `MahjongLedger/*.lproj/Localizable.strings` — five languages.
- `Tests/LedgerCalculationsSmokeTests.swift` — standalone Foundation regression tests.

## Run the Foundation tests (macOS Swift or Linux Swift)

```sh
swiftc MahjongLedger/Models/LedgerCalculations.swift Tests/LedgerCalculationsSmokeTests.swift -o /tmp/mahjong-ledger-v14-tests
/tmp/mahjong-ledger-v14-tests
```

## Build/test status

**Passed:** Pure-Foundation calculation/regression tests, Swift syntax parsing, and translation key checks across all five languages. The local environment lacks Xcode and iOS SDK; the full SwiftUI app has **not** been compiled, nor tested in an iOS Simulator or on a device. Verify the app in Xcode before relying on it to retain actual money records.
