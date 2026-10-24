import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final name in ['app_icon', 'app_icon_foreground']) {
    test('$name uses the centered baby artwork on white', () {
      final source = File('assets/brand/baby_icon.png').readAsBytesSync();
      final icon = File('assets/icon/$name.png').readAsBytesSync();
      expect(icon, source);
    });
  }
}
