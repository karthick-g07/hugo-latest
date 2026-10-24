import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quality_sweets/format.dart' as fmt;
import 'package:quality_sweets/main.dart';
import 'package:quality_sweets/models.dart';
import 'package:quality_sweets/screens/shell.dart';
import 'package:quality_sweets/store.dart';

/// Loads the real fonts so screenshots show readable text and icons.
Future<void> loadAppFonts() async {
  Future<ByteData> bytes(String path) async => ByteData.sublistView(await File(path).readAsBytes());
  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final path in paths) {
      loader.addFont(bytes(path));
    }
    await loader.load();
  }

  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '/opt/homebrew/share/flutter';
  await load('NotoSans', ['assets/fonts/NotoSans-Regular.ttf', 'assets/fonts/NotoSans-Bold.ttf']);
  await load('Playfair', ['assets/fonts/PlayfairDisplay-Bold.ttf']);
  await load('MaterialIcons', ['$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
}

/// Pumps the app on a device of [size] logical pixels with in-memory storage.
Future<AppStore> pumpApp(WidgetTester tester, {Size size = const Size(390, 844)}) async {
  tester.view
    ..devicePixelRatio = 2
    ..physicalSize = size * 2;
  addTearDown(tester.view.reset);
  Shell.tab.value = Shell.home;
  final store = AppStore(MemoryStorage());
  await tester.pumpWidget(QualitySweetsApp(store: store, splashDuration: Duration.zero));
  await tester.pumpAndSettle();
  return store;
}

/// Adds the spec's sample lines: weight, amount, unit and amount-only.
void seedBill(AppStore store) {
  BillLine weight(String name, double grams, double rate) => BillLine(
    id: newId(),
    name: name,
    productId: store.products.firstWhere((p) => p.name == name).id,
    mode: LineMode.weight,
    grams: grams,
    appliedRate: rate,
    defaultRate: rate,
    amount: fmt.Calc.weightAmount(grams, rate),
  );
  store
    ..addLine(weight('Ghee Mysore Pak', 8800, 280))
    ..addLine(weight('Kaju Katli', 500, 900))
    ..addLine(
      BillLine(
        id: newId(),
        name: 'Kaju Katli',
        mode: LineMode.amount,
        grams: fmt.Calc.gramsForAmount(100, 900),
        enteredAmount: 100,
        appliedRate: 900,
        defaultRate: 900,
        amount: 100,
      ),
    )
    ..addLine(
      BillLine(
        id: newId(),
        name: 'Snack Packet',
        mode: LineMode.unit,
        units: 3,
        unitLabel: 'packet',
        appliedRate: 20,
        defaultRate: 20,
        amount: 60,
      ),
    )
    ..addLine(BillLine(id: newId(), name: 'Other Item', mode: LineMode.amountOnly, amount: 35));
}
