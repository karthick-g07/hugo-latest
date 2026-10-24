// Renders key screens to test/screenshots/*.png for visual review.
// Regenerate with:
//   flutter test test/screenshots_test.dart --update-goldens --dart-define=SCREENSHOTS=true
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quality_sweets/main.dart';

import 'test_helpers.dart';

Future<void> shot(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  await expectLater(find.byType(QualitySweetsApp), matchesGoldenFile('screenshots/$name.png'));
}

Future<void> go(WidgetTester tester, String text) async {
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

/// Screenshots include the clock, so they only run when explicitly requested.
const _enabled = bool.fromEnvironment('SCREENSHOTS');

void main() {
  setUpAll(loadAppFonts);

  testWidgets('phone screens', skip: !_enabled, (tester) async {
    final store = await pumpApp(tester);
    await shot(tester, '01_home');

    await go(tester, 'Special Sweets');
    await shot(tester, '02_category');

    await go(tester, 'Ghee Mysore Pak');
    await tester.enterText(find.widgetWithText(TextField, 'Weight'), '8800');
    await shot(tester, '03_weight_dialog');

    await go(tester, 'By Amount');
    await tester.enterText(find.widgetWithText(TextField, 'Enter amount (₹)'), '100');
    await tester.enterText(find.widgetWithText(TextField, 'Rate per kg (₹, optional)'), '900');
    await shot(tester, '04_amount_dialog');
    await go(tester, 'Cancel');
    await tester.pageBack();
    await tester.pumpAndSettle();

    await go(tester, 'Quick Add');
    await go(tester, 'Fixed price');
    await tester.enterText(find.widgetWithText(TextField, 'Item name'), 'Mixture Special');
    await shot(tester, '05_custom_item');
    await go(tester, 'Cancel');

    seedBill(store);
    await tester.tap(find.byTooltip('Current bill'));
    await shot(tester, '06_current_bill');

    await go(tester, 'New Bill');
    await shot(tester, '07_new_bill_dialog');
    await go(tester, 'Save & Start New Bill');
    await shot(tester, '08_save_bill_name');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await shot(tester, '09_bill_saved');
    await go(tester, 'View Saved Bills');
    await shot(tester, '10_saved_bills');

    await go(tester, store.savedBills.single.name!);
    await shot(tester, '11_saved_bill_actions');
    await go(tester, 'View Bill');
    await shot(tester, '12_invoice_preview');
    await tester.tap(find.byTooltip('Share options'));
    await shot(tester, '13_share_options');
    await go(tester, 'Share via WhatsApp');
    await shot(tester, '14_whatsapp');
  });

  testWidgets('admin screens', skip: !_enabled, (tester) async {
    await pumpApp(tester);
    await go(tester, 'Admin');
    await shot(tester, '15_admin');
    await go(tester, 'Products');
    await shot(tester, '16_products');
    await go(tester, 'Ghee Mysore Pak');
    await shot(tester, '17_product_form');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await go(tester, 'Categories');
    await shot(tester, '18_categories');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Data Backup'), 200);
    await go(tester, 'Shop Settings');
    await shot(tester, '19_shop_settings');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await go(tester, 'Data Backup');
    await shot(tester, '20_backup');
  });

  testWidgets('tablet', skip: !_enabled, (tester) async {
    final store = await pumpApp(tester, size: const Size(1280, 800));
    seedBill(store);
    await shot(tester, '21_tablet');
  });
}
