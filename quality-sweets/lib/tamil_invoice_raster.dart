import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/painting.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'format.dart' as fmt;
import 'models.dart';

String _invoiceNumber(Bill bill) =>
    bill.isSaved ? (bill.displayNumber ?? '-') : 'Draft (not saved)';

/// Tamil text must be shaped by Flutter's text engine before it is embedded
/// in the PDF. The PDF package's text renderer does not apply Tamil OpenType
/// shaping, which can separate vowel marks and produce missing glyphs.
Future<Uint8List> buildTamilInvoicePdf(
  Bill bill,
  ShopSettings shop, {
  Uint8List? logo,
  Uint8List? gpayQr,
}) async {
  const margin = 28.0;
  const scale = 3.0;
  final pageWidth = PdfPageFormat.a5.width;
  final pageHeight = PdfPageFormat.a5.height;
  final width = pageWidth - margin * 2;
  final maroon = const ui.Color(0xffc90000);
  final muted = const ui.Color(0xff6e6262);
  final green = const ui.Color(0xff2e7d32);
  final border = const ui.Color(0xffe8d9c7);
  final cream = const ui.Color(0xfffff8ee);

  final logoBytes =
      logo ??
      (await rootBundle.load('assets/brand/ganesha.png')).buffer.asUint8List();
  final logoImage = await _decodeImage(logoBytes);
  final qrImage = gpayQr == null ? null : await _decodeImage(gpayQr);
  final shopName = shop.shopNameTamil.trim().isNotEmpty
      ? shop.shopNameTamil
      : shop.shopName;
  final tagline = shop.taglineTamil.trim().isNotEmpty
      ? shop.taglineTamil
      : shop.tagline;
  final address = shop.addressTamil.trim().isNotEmpty
      ? shop.addressTamil
      : shop.address;
  final footer = shop.footerTamil.trim().isNotEmpty
      ? shop.footerTamil
      : shop.footer;

  final pages = <({ui.PictureRecorder recorder, ui.Canvas canvas})>[];
  late ui.Canvas canvas;
  late ui.PictureRecorder recorder;
  late double y;

  TextPainter textLayout(
    String text,
    double maxWidth,
    double fontSize, {
    bool bold = false,
    ui.TextAlign align = ui.TextAlign.left,
    ui.Color color = const ui.Color(0xff222222),
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'NotoSansTamilInvoice',
          fontSize: fontSize,
          fontWeight: bold ? ui.FontWeight.bold : ui.FontWeight.normal,
          color: color,
        ),
      ),
      textAlign: align,
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    return painter;
  }

  double drawText(
    String text,
    double x,
    double top,
    double maxWidth,
    double fontSize, {
    bool bold = false,
    ui.TextAlign align = ui.TextAlign.left,
    ui.Color color = const ui.Color(0xff222222),
  }) {
    final painter = textLayout(
      text,
      maxWidth,
      fontSize,
      bold: bold,
      align: align,
      color: color,
    );
    painter.paint(canvas, ui.Offset(x, top));
    return painter.height;
  }

  void drawTableHeading() {
    canvas.drawRect(
      ui.Rect.fromLTWH(margin, y, width, 19),
      ui.Paint()..color = cream,
    );
    drawText('பொருள்', margin + 5, y + 3, 175, 8, bold: true);
    drawText('அளவு', margin + 184, y + 3, 94, 8, bold: true);
    drawText(
      'தொகை',
      margin + 280,
      y + 3,
      width - 285,
      8,
      bold: true,
      align: ui.TextAlign.right,
    );
    y += 23;
  }

  void startPage({bool first = false}) {
    recorder = ui.PictureRecorder();
    canvas = ui.Canvas(recorder)
      ..scale(scale)
      ..drawColor(const ui.Color(0xffffffff), ui.BlendMode.src);
    pages.add((recorder: recorder, canvas: canvas));
    canvas.drawImageRect(
      logoImage,
      ui.Rect.fromLTWH(
        0,
        0,
        logoImage.width.toDouble(),
        logoImage.height.toDouble(),
      ),
      const ui.Rect.fromLTWH(margin, 24, 48, 48),
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );
    var headerY = 25.0;
    headerY +=
        drawText(
          shopName,
          88,
          headerY,
          width - 60,
          17,
          bold: true,
          color: maroon,
        ) +
        2;
    if (tagline.trim().isNotEmpty) {
      headerY +=
          drawText(
            tagline,
            88,
            headerY,
            width - 60,
            9,
            color: const ui.Color(0xffa37a31),
          ) +
          1;
    }
    if (address.trim().isNotEmpty) {
      headerY +=
          drawText(address.trim(), 88, headerY, width - 60, 8, color: muted) +
          1;
    }
    if (bill.shopPhoneFor(shop).isNotEmpty) {
      headerY +=
          drawText(
            'தொலைபேசி: ${bill.shopPhoneFor(shop)}',
            88,
            headerY,
            width - 60,
            8,
            color: muted,
          ) +
          1;
    }
    if (shop.taxNumber.trim().isNotEmpty) {
      headerY +=
          drawText(
            'வரி எண்: ${shop.taxNumber.trim()}',
            88,
            headerY,
            width - 60,
            8,
            color: muted,
          ) +
          1;
    }
    final lineY = (headerY + 8).clamp(92.0, 118.0);
    canvas.drawRect(
      ui.Rect.fromLTWH(margin, lineY, width, 1.5),
      ui.Paint()..color = maroon,
    );
    if (first) {
      final infoY = lineY + 8;
      drawText(
        'ரசீது எண்: ${_invoiceNumber(bill)}',
        margin,
        infoY,
        width * .55,
        9,
        bold: true,
      );
      drawText(
        'தேதி: ${fmt.dateTime(bill.createdAt)}',
        margin,
        infoY + 14,
        width * .55,
        8,
      );
      if (bill.name?.isNotEmpty == true) {
        drawText(bill.name!, margin, infoY + 27, width * .55, 8, color: muted);
      }
      if (bill.customerName?.isNotEmpty == true ||
          bill.customerPhone?.isNotEmpty == true) {
        final customerX = margin + width * .58;
        drawText(
          'வாடிக்கையாளர்',
          customerX,
          infoY,
          width * .42,
          8,
          color: muted,
        );
        if (bill.customerName?.isNotEmpty == true) {
          drawText(
            bill.customerName!,
            customerX,
            infoY + 12,
            width * .42,
            9,
            bold: true,
          );
        }
        if (bill.customerPhone?.isNotEmpty == true) {
          drawText(bill.customerPhone!, customerX, infoY + 26, width * .42, 8);
        }
      }
      y = infoY + 52;
    } else {
      drawText(
        '$shopName · ${_invoiceNumber(bill)}',
        margin,
        lineY + 8,
        width,
        9,
        bold: true,
        color: muted,
      );
      y = lineY + 28;
    }
    drawTableHeading();
  }

  void newPage() => startPage();

  startPage(first: true);
  for (final line in bill.lines) {
    final name = line.nameTamil.trim().isNotEmpty ? line.nameTamil : line.name;
    final details = <String>[
      if (fmt.rateLabel(line) != '—') fmt.rateLabel(line),
      if (line.note?.isNotEmpty == true && line.mode != LineMode.amountOnly)
        line.note!,
      if (line.discount > 0) 'தள்ளுபடி: ${fmt.lineDiscountLabel(line)}',
    ];
    final nameLayout = textLayout(name, 172, 9.5, bold: true);
    final detailLayouts = details
        .map((s) => textLayout(s, 172, 7.5, color: muted))
        .toList();
    final qty = _tamilQuantity(line);
    final qtyLayout = textLayout(qty, 91, 8);
    final amountText = line.discount > 0
        ? '${fmt.money2(line.amount)}\n− ${fmt.money2(line.discount)}\n${fmt.money2(line.netAmount)}'
        : fmt.money2(line.amount);
    final amountLayout = textLayout(
      amountText,
      width - 285,
      8,
      align: ui.TextAlign.right,
    );
    final rowHeight =
        [
          nameLayout.height +
              detailLayouts.fold<double>(
                0,
                (sum, item) => sum + item.height + 1,
              ),
          qtyLayout.height,
          amountLayout.height,
        ].reduce((a, b) => a > b ? a : b) +
        9;
    if (y + rowHeight > pageHeight - 46) newPage();
    var itemY = y + 3;
    itemY += drawText(name, margin + 5, itemY, 172, 9.5, bold: true);
    for (final detail in details) {
      itemY += 1 + drawText(detail, margin + 5, itemY, 172, 7.5, color: muted);
    }
    drawText(qty, margin + 184, y + 3, 91, 8);
    drawText(
      amountText,
      margin + 280,
      y + 3,
      width - 285,
      8,
      align: ui.TextAlign.right,
    );
    y += rowHeight;
    canvas.drawRect(
      ui.Rect.fromLTWH(margin, y, width, .5),
      ui.Paint()..color = border,
    );
  }

  y += 8;
  final rows = <(String, String)>[];
  for (final row in fmt.billSummary(bill)) {
    rows.add((_tamilSummaryLabel(row.label), row.value));
  }
  rows.add(('மொத்தம்', fmt.money2(bill.grandTotal)));
  if ((bill.advanceAmount ?? 0) > 0) {
    rows.add(('முன்பணம்', fmt.money2(bill.advanceAmount!)));
    rows.add(('செலுத்த வேண்டிய தொகை', fmt.money2(bill.balanceDue)));
  }
  if (bill.paymentMethod != null) rows.add(('கட்டணம்', bill.paymentMethod!));
  for (final (label, value) in rows) {
    if (y + 18 > pageHeight - 45) newPage();
    final isTotal = label == 'மொத்தம்' || label == 'செலுத்த வேண்டிய தொகை';
    drawText(
      label,
      margin,
      y,
      width * .66,
      isTotal ? 10 : 8.5,
      bold: isTotal,
      color: isTotal ? maroon : const ui.Color(0xff222222),
    );
    drawText(
      value,
      margin + width * .66,
      y,
      width * .34,
      isTotal ? 10 : 8.5,
      bold: isTotal,
      align: ui.TextAlign.right,
      color: isTotal ? maroon : const ui.Color(0xff222222),
    );
    y += 16;
  }
  if (bill.paymentDone) {
    y += 3;
    drawText(
      'கட்டணம் செலுத்தப்பட்டது',
      margin,
      y,
      width,
      9,
      bold: true,
      align: ui.TextAlign.right,
      color: green,
    );
    y += 16;
  }
  if (bill.notes?.trim().isNotEmpty == true) {
    y += 3;
    y += drawText('குறிப்பு: ${bill.notes}', margin, y, width, 8);
  }
  if (qrImage != null) {
    if (y + 140 > pageHeight - 35) newPage();
    y += 8;
    drawText(
      'ஆன்லைனில் செலுத்த · GPay / UPI',
      margin,
      y,
      width,
      9,
      bold: true,
      align: ui.TextAlign.center,
      color: maroon,
    );
    y += 15;
    const qrSize = 105.0;
    canvas.drawImageRect(
      qrImage,
      ui.Rect.fromLTWH(
        0,
        0,
        qrImage.width.toDouble(),
        qrImage.height.toDouble(),
      ),
      ui.Rect.fromLTWH((pageWidth - qrSize) / 2, y, qrSize, qrSize),
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );
    y += qrSize + 8;
  }
  if (footer.trim().isNotEmpty) {
    final footerPainter = textLayout(
      footer.trim(),
      width,
      9,
      bold: true,
      align: ui.TextAlign.center,
      color: maroon,
    );
    if (y + footerPainter.height + 5 > pageHeight - 28) newPage();
    drawText(
      footer.trim(),
      margin,
      y + 2,
      width,
      9,
      bold: true,
      align: ui.TextAlign.center,
      color: maroon,
    );
  }

  final pngPages = <Uint8List>[];
  for (var i = 0; i < pages.length; i++) {
    final page = pages[i];
    final footerPainter = textLayout(
      'பக்கம் ${i + 1} / ${pages.length}',
      width,
      6,
      align: ui.TextAlign.right,
      color: muted,
    );
    page.canvas..drawRect(
      ui.Rect.fromLTWH(margin, pageHeight - 24, width, .5),
      ui.Paint()..color = border,
    );
    footerPainter.paint(page.canvas, ui.Offset(margin, pageHeight - 19));
    final picture = page.recorder.endRecording();
    final image = await picture.toImage(
      (pageWidth * scale).ceil(),
      (pageHeight * scale).ceil(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    pngPages.add(
      bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
    image.dispose();
  }

  final document = pw.Document(
    title: '$shopName ${_invoiceNumber(bill)}',
    author: shopName,
  );
  for (final page in pngPages) {
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Image(pw.MemoryImage(page), fit: pw.BoxFit.fill),
      ),
    );
  }
  return document.save();
}

Future<ui.Image> _decodeImage(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

String _tamilSummaryLabel(String label) {
  if (label.startsWith('Bill discount')) return 'பில் தள்ளுபடி';
  return switch (label) {
    'Actual amount' => 'உண்மையான தொகை',
    'Item discounts' => 'பொருள் தள்ளுபடி',
    'Total discount' => 'மொத்த தள்ளுபடி',
    'After discount' => 'தள்ளுபடிக்குப் பின்',
    _ => label,
  };
}

String _tamilQuantity(BillLine line) => switch (line.mode) {
  LineMode.weight =>
    '${fmt.grams(line.grams ?? 0)} / ${fmt.kg(line.grams ?? 0)}',
  LineMode.amount =>
    line.grams == null ? 'தொகை மட்டும்' : 'சுமார் ${fmt.weight(line.grams!)}',
  LineMode.unit =>
    '${fmt.editable(line.units ?? 0)} ${line.unitLabel ?? 'அலகு'}',
  LineMode.amountOnly =>
    line.note?.isNotEmpty == true ? line.note! : 'தொகை மட்டும்',
};
