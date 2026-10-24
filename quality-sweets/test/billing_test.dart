import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quality_sweets/format.dart' as fmt;
import 'package:quality_sweets/models.dart';
import 'package:quality_sweets/store.dart';

BillLine weightLine(
  double grams,
  double rate, {
  String name = 'Ghee Mysore Pak',
  double? defaultRate,
}) => BillLine(
  id: newId(),
  name: name,
  mode: LineMode.weight,
  grams: grams,
  appliedRate: rate,
  defaultRate: defaultRate ?? rate,
  amount: fmt.Calc.weightAmount(grams, rate),
);

Future<AppStore> freshStore([MemoryStorage? storage]) async {
  final store = AppStore(storage ?? MemoryStorage());
  await store.load();
  return store;
}

void main() {
  group('Calculations', () {
    test('8,800 g displays as 8.8 kg and back', () {
      expect(fmt.kg(8800), '8.8 kg');
      expect(fmt.grams(8.8 * 1000), '8,800 g');
    });

    test('₹280/kg × 8.8 kg = ₹2,464', () {
      expect(fmt.Calc.weightAmount(8800, 280), 2464);
      expect(fmt.money2(2464), '₹2,464.00');
    });

    test('spec weight examples', () {
      expect(fmt.Calc.weightAmount(250, 280), 70);
      expect(fmt.Calc.weightAmount(500, 900), 450);
      expect(fmt.Calc.weightAmount(1250, 240), 300);
    });

    test('₹100 of ₹900/kg ≈ 111.11 g, amount stays ₹100', () {
      final grams = fmt.Calc.gramsForAmount(100, 900)!;
      expect(grams, closeTo(111.111, 0.001));
      expect(fmt.grams(grams), '111.11 g');
    });

    test('no weight estimate without a rate', () {
      expect(fmt.Calc.gramsForAmount(100, 0), isNull);
    });

    test('unit billing: 3 packets × ₹20 = ₹60', () {
      expect(fmt.Calc.unitAmount(3, 20), 60);
      expect(fmt.units(3, 'packet'), '3 packets');
      expect(fmt.units(1, 'box'), '1 box');
      expect(fmt.units(2, 'box'), '2 boxes');
    });

    test('subtotal is decimal safe', () {
      final bill = Bill(
        id: 'b',
        lines: [
          for (var i = 0; i < 10; i++)
            BillLine(
              id: '$i',
              name: 'x',
              mode: LineMode.amountOnly,
              amount: 0.1,
            ),
        ],
      );
      expect(bill.subtotal, 1.0);
    });

    test('Indian currency grouping', () {
      expect(fmt.money2(123456.5), '₹1,23,456.50');
    });

    test('discount and tax only when configured', () {
      final bill = Bill(
        id: 'b',
        lines: [
          BillLine(id: '1', name: 'x', mode: LineMode.amountOnly, amount: 1000),
        ],
      );
      expect(bill.grandTotal, 1000);
      bill
        ..discountType = DiscountType.percent
        ..discountValue = 10;
      expect(bill.discountAmount, 100);
      expect(bill.grandTotal, 900);
      bill
        ..taxName = 'GST'
        ..taxPercent = 5;
      expect(bill.taxAmount, 45);
      expect(bill.grandTotal, 945);
      bill
        ..discountType = DiscountType.fixed
        ..discountValue = 5000;
      expect(
        bill.discountAmount,
        1000,
        reason: 'discount never exceeds subtotal',
      );
    });

    test('parses only finite numbers', () {
      expect(fmt.parseNumber('8,800'), 8800);
      expect(fmt.parseNumber('abc'), isNull);
      expect(fmt.parseNumber(''), isNull);
    });

    test('item discounts: percent, rupees, free grams and free units', () {
      BillLine discounted(BillLine line, LineDiscountType type, double value) =>
          BillLine.fromJson({
            ...line.toJson(),
            'discountType': type.name,
            'discountValue': value,
          });

      final kg = weightLine(1000, 280); // ₹280
      expect(discounted(kg, LineDiscountType.percent, 10).discount, 28);
      expect(discounted(kg, LineDiscountType.fixed, 30).netAmount, 250);
      expect(
        discounted(kg, LineDiscountType.quantity, 100).netAmount,
        252,
      ); // 100 g free
      expect(
        discounted(kg, LineDiscountType.fixed, 500).netAmount,
        0,
      ); // never below zero

      const packets = BillLine(
        id: 'p',
        name: 'Murukku',
        mode: LineMode.unit,
        units: 3,
        unitLabel: 'packet',
        appliedRate: 20,
        amount: 60,
      );
      final oneFree = discounted(packets, LineDiscountType.quantity, 1);
      expect(oneFree.netAmount, 40);
      expect(fmt.lineDiscountLabel(oneFree), '1 packet free');

      const amountOnly = BillLine(
        id: 'a',
        name: 'Gift box',
        mode: LineMode.amountOnly,
        amount: 100,
      );
      expect(amountOnly.allowsQuantityDiscount, isFalse);
      expect(discounted(amountOnly, LineDiscountType.quantity, 5).discount, 0);
    });

    test('bill shows actual, item + bill discounts, after-discount and tax on the reduced amount', () {
      final bill = Bill(
        id: 'b',
        lines: [
          BillLine.fromJson({
            ...weightLine(1000, 280).toJson(),
            'discountType': 'percent',
            'discountValue': 10,
          }),
          weightLine(500, 900, name: 'Kaju Katli'), // ₹450
        ],
        discountType: DiscountType.fixed,
        discountValue: 22,
        taxName: 'GST',
        taxPercent: 5,
      );
      expect(bill.itemsTotal, 730);
      expect(bill.itemDiscount, 28);
      expect(bill.subtotal, 702);
      expect(bill.discountAmount, 22);
      expect(bill.totalDiscount, 50);
      expect(bill.afterDiscount, 680);
      expect(bill.taxAmount, 34);
      expect(bill.grandTotal, 714);
      expect(fmt.billSummary(bill).map((r) => r.label), [
        'Actual amount',
        'Item discounts',
        'Bill discount',
        'Total discount',
        'After discount',
        'GST (5%)',
      ]);
      expect(
        fmt.billSummary(Bill(id: 'plain', lines: [weightLine(1000, 280)])),
        isEmpty,
      );
    });

    test('phone numbers normalise to digits with a country code', () {
      expect(fmt.normalisePhone('+91 98765 43210'), '919876543210');
      expect(
        fmt.normalisePhone('9876543210'),
        '919876543210',
      ); // bare 10 digits -> India
      expect(fmt.normalisePhone('1 415 555 0132'), '14155550132');
      expect(fmt.normalisePhone('12345'), isNull); // too short
      expect(fmt.normalisePhone('abc'), isNull);
      expect(fmt.displayPhone('919876543210'), '+919876543210');
    });
  });

  group('Store', () {
    test('starter sweets get bundled photos, including a catalog saved before photos existed', () async {
      final storage = MemoryStorage();
      final store = await freshStore(storage);
      expect(
        store.products.firstWhere((p) => p.name == 'Jangiri').imageName,
        'asset:assets/products/jangiri.jpg',
      );
      expect(
        store.categoryById('cat_special')!.imageName,
        'asset:assets/products/special_sweets.jpg',
      );

      final custom = store.products.firstWhere((p) => p.name == 'Kaju Katli')
        ..imageName = 'shop-photo.jpg';
      store.upsertProduct(custom);
      for (final product in store.products.where(
        (p) => p.name != 'Kaju Katli',
      )) {
        store.upsertProduct(product..imageName = null);
      }
      store.upsertCategory(store.categoryById('cat_normal')!..imageName = null);
      await store.flush();

      final reopened = await freshStore(storage);
      expect(
        reopened.products
            .firstWhere((p) => p.name == 'Ghee Mysore Pak')
            .imageName,
        'asset:assets/products/ghee_mysore_pak.jpg',
      );
      expect(
        reopened.products.firstWhere((p) => p.name == 'Kaju Katli').imageName,
        'shop-photo.jpg',
      );
      expect(
        reopened.categoryById('cat_normal')!.imageName,
        'asset:assets/products/normal_sweets.jpg',
      );
    });

    test(
      'bill can override shop phone and GPay QR without changing shop settings',
      () async {
        final storage = MemoryStorage();
        final store = await freshStore(storage);
        store.updateSettings(
          (s) => s
            ..phone = '9876543210'
            ..gpayQrName = 'shop-qr.jpg',
        );
        expect(store.draft.shopPhone, '9876543210');
        expect(store.draft.gpayQrName, 'shop-qr.jpg');

        store.updateDraft(
          (bill) => bill
            ..shopPhone = '9000000000'
            ..gpayQrName = 'bill-qr.jpg'
            ..payOnlineEnabled = true,
        );
        store.addLine(weightLine(1000, 280));
        final saved = store.saveDraft(name: 'UPI bill');
        expect(saved.shopPhoneFor(store.settings), '9000000000');
        expect(saved.gpayQrFor(store.settings), 'bill-qr.jpg');
        expect(store.settings.phone, '9876543210');
        expect(store.settings.gpayQrName, 'shop-qr.jpg');

        await store.flush();
        final reopened = await freshStore(storage);
        expect(reopened.settings.gpayQrName, 'shop-qr.jpg');
        expect(reopened.billById(saved.id)!.shopPhone, '9000000000');
        expect(reopened.billById(saved.id)!.gpayQrName, 'bill-qr.jpg');
      },
    );

    test(
      'owner WhatsApp numbers and the auto-forward toggle persist',
      () async {
        expect(
          ShopSettings().notifyOwnerOnShare,
          isTrue,
        ); // on by default once numbers are added
        expect(
          ShopSettings().ownerWhatsAppNumbers,
          isEmpty,
        ); // but nobody to send to yet

        final storage = MemoryStorage();
        final store = await freshStore(storage);
        store.updateSettings(
          (s) => s
            ..ownerWhatsAppNumbers = ['919876543210', '14155550132']
            ..notifyOwnerOnShare = false,
        );
        await store.flush();

        final reopened = await freshStore(storage);
        expect(reopened.settings.ownerWhatsAppNumbers, [
          '919876543210',
          '14155550132',
        ]);
        expect(reopened.settings.notifyOwnerOnShare, isFalse);
      },
    );

    test(
      'first launch has required categories including Other Items',
      () async {
        final store = await freshStore();
        final names = store.activeCategories.map((c) => c.name).toList();
        expect(names, [
          'Normal Sweets',
          'Special Sweets',
          'Karam & Savories',
          'Top Rated Specials',
          'Other Items',
        ]);
        expect(store.draft.isEmpty, isTrue);
      },
    );

    test('rate override does not change the product default', () async {
      final store = await freshStore();
      final product = store.products.firstWhere(
        (p) => p.name == 'Ghee Mysore Pak',
      );
      store.addLine(weightLine(1000, 260, defaultRate: product.ratePerKg));
      expect(store.draft.lines.single.amount, 260);
      expect(store.draft.lines.single.rateOverridden, isTrue);
      expect(product.ratePerKg, 280);
    });

    test('same product at different rates stays as separate lines', () async {
      final store = await freshStore();
      store
        ..addLine(weightLine(1000, 280))
        ..addLine(weightLine(1000, 260));
      expect(store.draft.lines.length, 2);
      expect(store.draft.subtotal, 540);
    });

    test(
      'editing and removing a line recalculates totals; undo restores',
      () async {
        final store = await freshStore();
        final first = weightLine(500, 900, name: 'Kaju Katli');
        store
          ..addLine(weightLine(8800, 280))
          ..addLine(first);
        expect(store.draft.subtotal, 2914);
        store.updateLine(
          weightLine(1000, 900, name: 'Kaju Katli').copyWithId(first.id),
        );
        expect(store.draft.subtotal, 3364);
        final index = store.removeLine(first);
        expect(store.draft.subtotal, 2464);
        store.restoreLine(first, index);
        expect(store.draft.subtotal, 2914);
      },
    );

    test(
      'saving keeps a snapshot; product rate changes do not alter it',
      () async {
        final store = await freshStore();
        final product = store.products.firstWhere(
          (p) => p.name == 'Ghee Mysore Pak',
        );
        store.addLine(weightLine(8800, product.ratePerKg));
        final saved = store.saveDraft(name: 'Bill - test');
        store.upsertProduct(product..ratePerKg = 300);
        expect(store.billById(saved.id)!.grandTotal, 2464);
        expect(saved.displayNumber, 'QS0001');
        expect(store.draftNeedsProtection, isFalse);
      },
    );

    test('new bill protection when the billing area has items, even a resumed bill', () async {
      final store = await freshStore();
      expect(store.draftNeedsProtection, isFalse);
      store.addLine(weightLine(100, 280));
      expect(store.draftNeedsProtection, isTrue);
      final saved = store.saveDraft(name: 'A');
      expect(store.draftNeedsProtection, isFalse);
      expect(store.draft.isEmpty, isTrue);

      store.resumeBill(saved);
      expect(store.draftDirty, isFalse);
      expect(store.draftNeedsProtection, isTrue);
    });

    test(
      'resume + save changes overwrites; save as copy adds a new bill',
      () async {
        final store = await freshStore();
        store.addLine(weightLine(1000, 280));
        final original = store.saveDraft(name: 'Original');
        store.startNewDraft();

        store.resumeBill(original);
        store.addLine(weightLine(500, 900));
        store.saveDraft(name: 'Original', overwrite: true);
        expect(store.savedBills.length, 1);
        expect(store.savedBills.single.grandTotal, 730);
        expect(store.savedBills.single.displayNumber, 'QS0001');

        store.addLine(weightLine(100, 1000));
        final copy = store.saveDraft(name: 'Copy');
        expect(store.savedBills.length, 2);
        expect(copy.displayNumber, 'QS0002');
        expect(store.billById(original.id)!.grandTotal, 730);
      },
    );

    test('duplicate bill leaves the original untouched', () async {
      final store = await freshStore();
      store.addLine(weightLine(1000, 280));
      final original = store.saveDraft(name: 'Original');
      store.duplicateBill(original);
      store.addLine(weightLine(1000, 280));
      expect(store.draft.sourceBillId, isNull);
      expect(store.billById(original.id)!.lines.length, 1);
    });

    test('data persists across reloads, including the draft', () async {
      final storage = MemoryStorage();
      final store = await freshStore(storage);
      store.addLine(weightLine(1000, 280));
      store.saveDraft(name: 'Saved');
      store.addLine(weightLine(250, 280));
      await store.flush();

      final reopened = await freshStore(storage);
      expect(reopened.savedBills.single.name, 'Saved');
      expect(reopened.draft.lines.length, 1);
      expect(reopened.draftNeedsProtection, isTrue);
    });

    test(
      'saving clears the billing area; the bill lives only in saved bills',
      () async {
        final store = await freshStore();
        store.addLine(weightLine(1000, 280));
        final saved = store.saveDraft(name: 'Morning');
        expect(store.draft.isEmpty, isTrue);
        expect(store.draft.sourceBillId, isNull);
        expect(store.billById(saved.id)!.lines.length, 1);

        store.resumeBill(saved);
        expect(store.draft.lines.length, 1);
        expect(store.draftSource, same(store.billById(saved.id)));
      },
    );

    test(
      'saved bills filter by date, payment, discount and customer',
      () async {
        final store = await freshStore();
        Bill save(
          String name, {
          String? payment,
          String? customer,
          double discount = 0,
        }) {
          store.addLine(weightLine(1000, 280));
          store.updateDraft(
            (b) => b
              ..paymentMethod = payment
              ..customerName = customer
              ..discountType = discount > 0
                  ? DiscountType.fixed
                  : DiscountType.none
              ..discountValue = discount,
          );
          return store.saveDraft(name: name);
        }

        save('Cash bill', payment: 'Cash');
        save('UPI bill', payment: 'UPI', customer: 'Ravi');
        final old = save('Old bill', discount: 20)
          ..createdAt = DateTime(2024, 1, 15);
        store.addLine(weightLine(1, 1, name: 'Kaju Katli'));
        save('Kaju bill');

        final today = DateTime.now();
        final start = DateTime(today.year, today.month, today.day);
        expect(store.findBills(from: start).length, 3);
        expect(
          store
              .findBills(from: DateTime(2024, 1, 1), to: DateTime(2024, 2, 1))
              .single,
          same(old),
        );
        expect(store.findBills(paymentMethod: 'UPI').single.name, 'UPI bill');
        expect(store.findBills(discountedOnly: true).single.name, 'Old bill');
        expect(store.findBills(withCustomerOnly: true).single.name, 'UPI bill');
        expect(store.findBills(query: 'kaju').single.name, 'Kaju bill');
      },
    );

    test(
      'product search filters by category, type, top rated and sorts by price',
      () async {
        final store = await freshStore();
        final special = store.search('', categoryId: 'cat_special');
        expect(special, isNotEmpty);
        expect(special.every((p) => p.categoryId == 'cat_special'), isTrue);
        expect(
          store
              .search('', mode: ProductMode.unit)
              .every((p) => p.mode == ProductMode.unit),
          isTrue,
        );
        expect(
          store.search('', popularOnly: true).every((p) => p.isPopular),
          isTrue,
        );
        final byPrice = store.search('', sort: ProductSort.priceHigh);
        for (var i = 1; i < byPrice.length; i++) {
          expect(byPrice[i - 1].defaultRate >= byPrice[i].defaultRate, isTrue);
        }
      },
    );

    test('deleting a category moves its products', () async {
      final store = await freshStore();
      final special = store.categoryById('cat_special')!;
      final count = store.productsIn(special, activeOnly: false).length;
      final before = store
          .productsIn(store.otherCategory, activeOnly: false)
          .length;
      store.deleteCategory(special, store.otherCategory);
      expect(store.categoryById('cat_special'), isNull);
      expect(
        store.productsIn(store.otherCategory, activeOnly: false).length,
        before + count,
      );
    });

    test('system categories cannot be deleted', () async {
      final store = await freshStore();
      store.deleteCategory(
        store.otherCategory,
        store.categoryById('cat_normal')!,
      );
      expect(store.otherCategory, isNotNull);
    });

    test('backup export/import validates and round-trips', () async {
      final store = await freshStore();
      store.addLine(weightLine(1000, 280));
      store.saveDraft(name: 'Backup me');
      final json = await store.exportBackup();

      expect(() => store.previewImport('not json'), throwsFormatException);
      expect(
        () => store.previewImport(jsonEncode({'hello': 1})),
        throwsFormatException,
      );

      final target = await freshStore();
      final preview = target.previewImport(json);
      expect(preview.bills.length, 1);
      await target.applyImport(preview, replace: false);
      expect(target.savedBills.single.name, 'Backup me');
      expect(target.settings.nextBillNumber, 2);

      await target.applyImport(target.previewImport(json), replace: false);
      expect(target.savedBills.length, 1, reason: 'merge skips existing IDs');
    });

    test('setup and bill-history backups import only their own data', () async {
      final source = await freshStore();
      source.addLine(weightLine(1000, 280));
      source.saveDraft(name: 'History only');
      final setupJson = await source.exportBackup(kind: BackupKind.setup);
      final setupData = jsonDecode(setupJson) as Map<String, dynamic>;
      expect(setupData['bills'], isEmpty);
      expect((setupData['draft'] as Map<String, dynamic>)['lines'], isEmpty);

      final target = await freshStore();
      target.addLine(weightLine(500, 280));
      target.saveDraft(name: 'Keep this history');
      await target.applyImport(target.previewImport(setupJson), replace: true);
      expect(target.savedBills.single.name, 'Keep this history');
      expect(target.products, isNotEmpty);

      final billsJson = await source.exportBackup(kind: BackupKind.bills);
      final billsData = jsonDecode(billsJson) as Map<String, dynamic>;
      expect(billsData.keys, contains('bills'));
      expect(billsData.containsKey('products'), isFalse);
      final existingProducts = target.products.length;
      await target.applyImport(target.previewImport(billsJson), replace: true);
      expect(target.savedBills.single.name, 'History only');
      expect(target.products.length, existingProducts);
    });

    test('clear all data keeps default categories', () async {
      final store = await freshStore();
      store.addLine(weightLine(1000, 280));
      store.saveDraft(name: 'x');
      store.clearAllData();
      expect(store.savedBills, isEmpty);
      expect(store.products, isEmpty);
      expect(store.categories.length, 5);
    });

    test('suggested bill names count bills saved today', () async {
      final store = await freshStore();
      final today = DateTime.now();
      expect(store.suggestedBillName(today), 'Bill - ${fmt.date(today)} - 01');
      store.addLine(weightLine(100, 280));
      store.saveDraft(name: 'x');
      expect(store.suggestedBillName(today), 'Bill - ${fmt.date(today)} - 02');
    });
  });
}

extension on BillLine {
  BillLine copyWithId(String id) => BillLine.fromJson({...toJson(), 'id': id});
}
