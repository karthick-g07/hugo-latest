import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quality_sweets/invoice_pdf.dart';
import 'package:quality_sweets/models.dart';
import 'package:quality_sweets/store.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('builds an invoice PDF and text summary for a saved bill', () async {
    final store = AppStore(MemoryStorage());
    await store.load();
    seedBill(store);
    store.updateSettings((s) => s.phone = '044 1234 5678');
    store.updateDraft(
      (bill) => bill
        ..customerName = 'Ramesh'
        ..customerPhone = '+91 98765 43210'
        ..shopPhone = '044 1234 5678'
        ..notes = 'Gift packing',
    );
    final bill = store.saveDraft(name: 'Diwali Order');

    final bytes = await buildInvoicePdf(bill, store.settings);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    await File('test/screenshots/invoice_sample.pdf').writeAsBytes(bytes);

    final text = invoiceText(bill, store.settings);
    expect(text, contains('QS0001'));
    expect(text, contains('Phone: 044 1234 5678'));
    expect(text, contains('Total: ₹3,109.00'));
    expect(
      bill.lines.where((l) => l.mode == LineMode.amount).single.amount,
      100,
    );
  });
}
