# Quality Sweets Billing App

Local-first counter billing app for Android and iOS, built with Flutter from
`Quality_Sweets_Billing_App_Full_Idea.md` and `Quality Sweets App UI Flow.png`.
All data stays on the device; there is no backend.

## Run

```sh
flutter pub get
flutter run                 # on a connected phone, emulator or simulator
```

Release builds:

```sh
flutter build apk --release        # Android (needs Android SDK / Android Studio)
flutter build appbundle --release  # Play Store
flutter build ipa --release        # iOS (needs Xcode + Apple signing team)
```

## Test

```sh
flutter test
# Regenerate UI screenshots in test/screenshots/
flutter test test/screenshots_test.dart --update-goldens --dart-define=SCREENSHOTS=true
```

## Code map

| Path | Purpose |
| --- | --- |
| `lib/models.dart` | Product, Category, Bill, BillLine snapshot, ShopSettings |
| `lib/format.dart` | Money/weight formatting and billing maths (`Calc`) |
| `lib/store.dart` | App state, JSON file persistence, draft safety, backup/import |
| `lib/invoice_pdf.dart` | Invoice PDF and WhatsApp text |
| `lib/screens/` | Home, category, item dialog, bill, saved bills, invoice |
| `lib/screens/admin/` | Dashboard, products, categories, settings, billing options, backup |

App icon artwork: `flutter test tool/app_icon_test.dart --update-goldens && dart run flutter_launcher_icons`.
