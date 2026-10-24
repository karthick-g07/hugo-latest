import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quality_sweets/models.dart';

import 'test_helpers.dart';

Finder field(String label) => find.widgetWithText(TextField, label);

/// Lets any "Added …" snackbar time out so it does not cover buttons.
Future<void> settleSnackBars(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

Future<void> openProduct(WidgetTester tester, String category, String product) async {
  await settleSnackBars(tester);
  await tester.ensureVisible(find.text(category));
  await tester.pumpAndSettle();
  await tester.tap(find.text(category));
  await tester.pumpAndSettle();
  await tester.tap(find.text(product));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('Journey A: weight sale, save bill, appears in saved bills', (tester) async {
    final store = await pumpApp(tester);
    for (final name in [
      'Normal Sweets',
      'Special Sweets',
      'Karam & Savories',
      'Top Rated Specials',
      'Other Items',
    ]) {
      expect(find.text(name), findsWidgets);
    }

    await openProduct(tester, 'Special Sweets', 'Ghee Mysore Pak');
    await tester.enterText(field('Weight'), '8800');
    await tester.pump();
    expect(find.text('Equivalent: 8.8 kg  ·  8,800 g'), findsOneWidget);
    expect(find.text('₹2,464.00'), findsOneWidget);

    await tester.tap(find.descendant(of: find.byType(SegmentedButton<bool>), matching: find.text('kg')));
    await tester.pump();
    expect(
      tester.widget<TextField>(field('Weight')).controller!.text,
      '8.8',
      reason: 'unit switch converts once',
    );

    await tester.tap(find.text('Add to Bill'));
    await tester.pumpAndSettle();
    expect(store.draft.lines.single.amount, 2464);

    await tester.tap(find.byTooltip('Current bill'));
    await tester.pumpAndSettle();
    expect(find.text('Grand Total'), findsOneWidget);
    expect(find.text('₹2,464.00'), findsWidgets);

    await tester.tap(find.text('Save Bill'));
    await tester.pumpAndSettle();
    expect(find.text('Save Current Bill'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('Bill Saved Successfully!'), findsOneWidget);
    await tester.tap(find.text('Start New Bill'));
    await tester.pumpAndSettle();
    expect(store.draft.isEmpty, isTrue);
    expect(store.savedBills.single.grandTotal, 2464);

    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();
    expect(find.text(store.savedBills.single.name!), findsOneWidget);
  });

  testWidgets('Journey B and E: amount billing and temporary rate change', (tester) async {
    final store = await pumpApp(tester);
    await openProduct(tester, 'Special Sweets', 'Kaju Katli');
    await tester.tap(find.text('By Amount'));
    await tester.pump();
    await tester.enterText(field('Enter amount (₹)'), '100');
    await tester.pump();
    expect(find.textContaining('approx. 111.11 g'), findsOneWidget);
    await tester.tap(find.text('Add to Bill'));
    await tester.pumpAndSettle();
    expect(store.draft.lines.single.amount, 100);

    await tester.tap(find.text('Ghee Mysore Pak'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Weight'), '1000');
    await tester.enterText(field('Rate per kg (₹)'), '260');
    await tester.pump();
    expect(find.textContaining('Changed for this bill only'), findsOneWidget);
    await tester.tap(find.text('Add to Bill'));
    await tester.pumpAndSettle();
    expect(store.draft.lines.last.amount, 260);
    expect(store.products.firstWhere((p) => p.name == 'Ghee Mysore Pak').ratePerKg, 280);
  });

  testWidgets('Journey C and D: quick add amount-only and fixed-price packets', (tester) async {
    final store = await pumpApp(tester);
    await tester.tap(find.text('Quick Add'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Item name'), 'Other Snack');
    await tester.enterText(field('Amount (₹)'), '35');
    await tester.pump();
    await tester.tap(find.text('Add to Bill'));
    await tester.pumpAndSettle();
    expect(store.draft.lines.single.name, 'Other Snack');
    expect(store.draft.lines.single.amount, 35);

    await openProduct(tester, 'Other Items', 'Snack Packet');
    await tester.tap(find.byTooltip('Increase quantity'));
    await tester.tap(find.byTooltip('Increase quantity'));
    await tester.pump();
    expect(find.text('₹60.00'), findsOneWidget);
    await tester.tap(find.text('Add to Bill'));
    await tester.pumpAndSettle();
    expect(store.draft.subtotal, 95);
  });

  testWidgets('validation: empty weight shows an error and adds nothing', (tester) async {
    final store = await pumpApp(tester);
    await openProduct(tester, 'Special Sweets', 'Ghee Mysore Pak');
    await tester.tap(find.text('Add to Bill'));
    await tester.pump();
    expect(find.text('Enter the weight'), findsOneWidget);
    await tester.enterText(field('Weight'), '0');
    await tester.pump();
    expect(find.text('Weight must be greater than zero'), findsOneWidget);
    expect(store.draft.isEmpty, isTrue);
  });

  testWidgets('Journey F: New Bill protects the draft', (tester) async {
    final store = await pumpApp(tester);
    await openProduct(tester, 'Special Sweets', 'Ghee Mysore Pak');
    await tester.tap(find.text('1 kg'));
    await tester.tap(find.text('Add to Bill'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Current bill'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New Bill'));
    await tester.pumpAndSettle();
    expect(find.text('Start a New Bill?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(store.draft.lines.length, 1);

    await tester.tap(find.text('New Bill'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save & Start New Bill'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start New Bill'));
    await tester.pumpAndSettle();
    expect(store.draft.isEmpty, isTrue);
    expect(store.savedBills.length, 1);
  });

  testWidgets('editing a saved bill while another bill is open asks to save or delete it', (tester) async {
    final store = await pumpApp(tester);
    store.addLine(
      BillLine(
        id: newId(),
        name: 'Jangiri',
        mode: LineMode.weight,
        grams: 500,
        appliedRate: 240,
        amount: 120,
      ),
    );
    final saved = store.saveDraft(name: 'Morning bill');
    expect(store.draft.isEmpty, isTrue);
    store.addLine(BillLine(id: newId(), name: 'Gift box', mode: LineMode.amountOnly, amount: 50));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Saved').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Morning bill'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit / Resume Bill'));
    await tester.pumpAndSettle();
    expect(find.text('A bill is already open'), findsOneWidget);
    await tester.tap(find.text('Delete current bill'));
    await tester.pumpAndSettle();

    expect(store.draft.sourceBillId, saved.id);
    expect(store.draft.lines.single.name, 'Jangiri');
  });

  testWidgets('item discount: free grams reduce the amount and show actual vs discounted', (tester) async {
    final store = await pumpApp(tester);
    await openProduct(tester, 'Special Sweets', 'Ghee Mysore Pak');
    await tester.tap(find.text('1 kg'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Minus g'));
    await tester.tap(find.text('Minus g'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Minus weight (g)'), '100');
    await tester.pumpAndSettle();
    expect(find.text('After discount'), findsOneWidget);
    expect(find.text('Actual ₹280.00 · Discount - ₹28.00'), findsOneWidget);
    await tester.tap(find.text('Add to Bill'));
    await tester.pumpAndSettle();

    final line = store.draft.lines.single;
    expect(line.amount, 280);
    expect(line.netAmount, 252);
    expect(store.draft.grandTotal, 252);
  });

  testWidgets('tablet shows catalog and bill side by side', (tester) async {
    await pumpApp(tester, size: const Size(1280, 800));
    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('Current Bill'), findsOneWidget);
  });

  testWidgets('small phone renders every tab without overflow', (tester) async {
    await pumpApp(tester, size: const Size(320, 568));
    for (final tab in ['Bill', 'Saved', 'Admin', 'Home']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
    }
    await openProduct(tester, 'Special Sweets', 'Ghee Mysore Pak');
    await tester.tap(find.text('By Amount'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text("Quick Add"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quick Add'));
    await tester.pumpAndSettle();
  });
}
