import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'format.dart' as fmt;
import 'models.dart';
import 'tamil_invoice_raster.dart';

const _maroon = PdfColor.fromInt(0xFFC90000);
const _gold = PdfColor.fromInt(0xFFC9973A);
const _muted = PdfColor.fromInt(0xFF6E6262);
const _border = PdfColor.fromInt(0xFFE8D9C7);
const _cream = PdfColor.fromInt(0xFFFFF8EE);
const _green = PdfColor.fromInt(0xFF2E7D32);

final Map<bool, pw.ThemeData> _themes = {};

Future<pw.ThemeData> _loadTheme({bool tamil = false}) async {
  final cached = _themes[tamil];
  if (cached != null) return cached;
  final regularPath = tamil
      ? 'assets/fonts/NotoSansTamil.ttf'
      : 'assets/fonts/NotoSans-Regular.ttf';
  final boldPath = tamil
      ? 'assets/fonts/NotoSansTamil.ttf'
      : 'assets/fonts/NotoSans-Bold.ttf';
  final theme = pw.ThemeData.withFont(
    base: pw.Font.ttf(await rootBundle.load(regularPath)),
    bold: pw.Font.ttf(await rootBundle.load(boldPath)),
  );
  return _themes[tamil] = theme;
}

/// Bill number shown on invoices; drafts are clearly marked.
String invoiceNumber(Bill bill) =>
    bill.isSaved ? (bill.displayNumber ?? '-') : 'Draft (not saved)';

/// Builds the invoice PDF. Only configured shop details and taxes are printed.
Future<Uint8List> buildInvoicePdf(
  Bill bill,
  ShopSettings shop, {
  Uint8List? logo,
  Uint8List? gpayQr,
  String language = 'en',
}) async {
  if (language == 'ta') {
    return buildTamilInvoicePdf(bill, shop, logo: logo, gpayQr: gpayQr);
  }
  final tamil = language == 'ta';
  String tr(String english, String tamilText) => tamil ? tamilText : english;
  final shopName = tamil && shop.shopNameTamil.trim().isNotEmpty
      ? shop.shopNameTamil
      : shop.shopName;
  final shopTagline = tamil && shop.taglineTamil.trim().isNotEmpty
      ? shop.taglineTamil
      : shop.tagline;
  final shopAddress = tamil && shop.addressTamil.trim().isNotEmpty
      ? shop.addressTamil
      : shop.address;
  final shopFooter = tamil && shop.footerTamil.trim().isNotEmpty
      ? shop.footerTamil
      : shop.footer;
  final doc = pw.Document(
    title: '$shopName ${invoiceNumber(bill)}',
    author: shopName,
  );
  final theme = await _loadTheme(tamil: tamil);

  pw.Widget cell(
    String text, {
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor? color,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
    child: pw.Text(
      text,
      textAlign: align,
      style: pw.TextStyle(
        fontSize: 9,
        fontWeight: bold ? pw.FontWeight.bold : null,
        color: color,
      ),
    ),
  );

  pw.Widget totalRow(String label, String value, {bool big = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(
                label,
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  fontSize: big ? 12 : 10,
                  fontWeight: big ? pw.FontWeight.bold : null,
                ),
              ),
            ),
            pw.SizedBox(
              width: 90,
              child: pw.Text(
                value,
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  fontSize: big ? 12 : 10,
                  fontWeight: big ? pw.FontWeight.bold : null,
                  color: big ? _maroon : null,
                ),
              ),
            ),
          ],
        ),
      );

  final mark =
      logo ??
      (await rootBundle.load('assets/brand/ganesha.png')).buffer.asUint8List();
  final shopPhone = bill.shopPhoneFor(shop);
  final contact = [
    shopAddress.trim(),
    if (shopPhone.isNotEmpty) '${tr('Phone', 'தொலைபேசி')}: $shopPhone',
  ].where((s) => s.isNotEmpty).toList();

  doc.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        theme: theme,
        pageFormat: PdfPageFormat.a5.copyWith(
          marginLeft: 28,
          marginRight: 28,
          marginTop: 28,
          marginBottom: 28,
        ),
        buildBackground: (_) => pw.FullPage(
          ignoreMargins: true,
          child: pw.Container(color: PdfColors.white),
        ),
      ),
      header: (context) => context.pageNumber == 1
          ? pw.Column(
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.ClipOval(
                      child: pw.Container(
                        width: 52,
                        height: 52,
                        color: PdfColors.white,
                        alignment: pw.Alignment.center,
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Image(
                            pw.MemoryImage(mark),
                            fit: pw.BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 12),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            shopName,
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: _maroon,
                            ),
                          ),
                          if (shopTagline.isNotEmpty)
                            pw.Text(
                              shopTagline,
                              style: const pw.TextStyle(
                                fontSize: 9,
                                color: _gold,
                              ),
                            ),
                          for (final line in contact)
                            pw.Text(
                              line,
                              style: const pw.TextStyle(
                                fontSize: 8,
                                color: _muted,
                              ),
                            ),
                          if (shop.taxEnabled &&
                              shop.taxNumber.trim().isNotEmpty)
                            pw.Text(
                              '${tr('Tax No', 'வரி எண்')}: ${shop.taxNumber.trim()}',
                              style: const pw.TextStyle(
                                fontSize: 8,
                                color: _muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Container(height: 2, color: _maroon),
                pw.SizedBox(height: 10),
              ],
            )
          : pw.SizedBox(),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Page ${context.pageNumber} of ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 7, color: _muted),
        ),
      ),
      build: (context) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '${tr('Bill No', 'ரசீது எண்')}: ${invoiceNumber(bill)}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '${tr('Date', 'தேதி')}: ${fmt.dateTime(bill.createdAt)}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  if (bill.name?.isNotEmpty == true)
                    pw.Text(
                      bill.name!,
                      style: const pw.TextStyle(fontSize: 9, color: _muted),
                    ),
                ],
              ),
            ),
            if (bill.customerName?.isNotEmpty == true ||
                bill.customerPhone?.isNotEmpty == true)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    tr('Customer', 'வாடிக்கையாளர்'),
                    style: const pw.TextStyle(fontSize: 8, color: _muted),
                  ),
                  if (bill.customerName?.isNotEmpty == true)
                    pw.Text(
                      bill.customerName!,
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  if (bill.customerPhone?.isNotEmpty == true)
                    pw.Text(
                      bill.customerPhone!,
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                ],
              ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Table(
          border: const pw.TableBorder(
            horizontalInside: pw.BorderSide(color: _border, width: 0.5),
          ),
          columnWidths: const {
            0: pw.FixedColumnWidth(18),
            1: pw.FlexColumnWidth(3),
            2: pw.FlexColumnWidth(2.4),
            3: pw.FlexColumnWidth(1.6),
            4: pw.FlexColumnWidth(1.8),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _cream),
              children: [
                cell('#', bold: true),
                cell(tr('Item', 'பொருள்'), bold: true),
                cell(tr('Qty', 'அளவு'), bold: true),
                cell(tr('Rate', 'விலை'), bold: true, align: pw.TextAlign.right),
                cell(
                  tr('Amount', 'தொகை'),
                  bold: true,
                  align: pw.TextAlign.right,
                ),
              ],
            ),
            for (final (i, line) in bill.lines.indexed)
              pw.TableRow(
                children: [
                  cell('${i + 1}'),
                  cell(
                    [
                      tamil && line.nameTamil.trim().isNotEmpty
                          ? line.nameTamil
                          : line.name,
                      if (line.note != null && line.mode != LineMode.amountOnly)
                        line.note!,
                      if (line.discount > 0) fmt.lineDiscountLabel(line),
                    ].join('\n'),
                  ),
                  cell(fmt.quantityLabel(line)),
                  cell(fmt.rateLabel(line), align: pw.TextAlign.right),
                  if (line.discount > 0)
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        cell(
                          fmt.money2(line.amount),
                          align: pw.TextAlign.right,
                          color: _muted,
                        ),
                        cell(
                          '- ${fmt.money2(line.discount)}',
                          align: pw.TextAlign.right,
                          color: _green,
                        ),
                        cell(
                          fmt.money2(line.netAmount),
                          align: pw.TextAlign.right,
                          bold: true,
                        ),
                      ],
                    )
                  else
                    cell(
                      fmt.money2(line.amount),
                      align: pw.TextAlign.right,
                      bold: true,
                    ),
                ],
              ),
          ],
        ),
        pw.Container(height: 1, color: _border),
        pw.SizedBox(height: 8),
        for (final row in fmt.billSummary(bill))
          totalRow(_summaryLabel(row.label, tamil), row.value),
        pw.SizedBox(height: 4),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: _maroon)),
          ),
          child: totalRow(
            tr('Total', 'மொத்தம்'),
            fmt.money2(bill.grandTotal),
            big: true,
          ),
        ),
        if ((bill.advanceAmount ?? 0) > 0) ...[
          totalRow(
            tr('Advance Paid', 'முன்பணம்'),
            fmt.money2(bill.advanceAmount!),
          ),
          totalRow(
            tr('Total Due', 'செலுத்த வேண்டிய தொகை'),
            fmt.money2(bill.balanceDue),
            big: true,
          ),
        ],
        if (bill.paymentDone)
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(5),
              color: _green,
              child: pw.Text(
                tr('PAYMENT DONE', 'கட்டணம் செலுத்தப்பட்டது'),
                style: const pw.TextStyle(color: PdfColors.white, fontSize: 9),
              ),
            ),
          ),
        if (bill.paymentMethod != null)
          totalRow(tr('Payment', 'கட்டணம்'), bill.paymentMethod!),
        if (bill.notes?.isNotEmpty == true) ...[
          pw.SizedBox(height: 8),
          pw.Text(
            '${tr('Note', 'குறிப்பு')}: ${bill.notes}',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
        if (gpayQr != null) ...[
          pw.SizedBox(height: 16),
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text(
                  tr('Pay online', 'ஆன்லைனில் செலுத்த'),
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: _maroon,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  tr(
                    'Scan with GPay or any UPI app',
                    'GPay அல்லது UPI செயலியில் ஸ்கேன் செய்யவும்',
                  ),
                  style: const pw.TextStyle(fontSize: 8, color: _muted),
                ),
                pw.SizedBox(height: 8),
                pw.Image(
                  pw.MemoryImage(gpayQr),
                  width: 110,
                  height: 110,
                  fit: pw.BoxFit.contain,
                ),
              ],
            ),
          ),
        ],
        pw.SizedBox(height: 24),
        if (shopFooter.trim().isNotEmpty)
          pw.Center(
            child: pw.Text(
              shopFooter.trim(),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 10,
                color: _maroon,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
      ],
    ),
  );
  return doc.save();
}

/// Plain-text bill summary for WhatsApp messages.
String _summaryLabel(String label, bool tamil) {
  if (!tamil) return label;
  return switch (label) {
    'Actual amount' => 'உண்மையான தொகை',
    'Item discounts' => 'பொருள் தள்ளுபடி',
    'Bill discount' || 'Bill discount (%)' => 'பில் தள்ளுபடி',
    'Total discount' => 'மொத்த தள்ளுபடி',
    'After discount' => 'தள்ளுபடிக்குப் பின்',
    _ => label,
  };
}

String invoiceText(Bill bill, ShopSettings shop, {String language = 'en'}) {
  final tamil = language == 'ta';
  String tr(String english, String tamilText) => tamil ? tamilText : english;
  final shopName = tamil && shop.shopNameTamil.trim().isNotEmpty
      ? shop.shopNameTamil
      : shop.shopName;
  final footer = tamil && shop.footerTamil.trim().isNotEmpty
      ? shop.footerTamil
      : shop.footer;
  final lines = [
    '*$shopName*',
    if (bill.shopPhoneFor(shop).isNotEmpty)
      '${tr('Phone', 'தொலைபேசி')}: ${bill.shopPhoneFor(shop)}',
    '${tr('Bill', 'ரசீது')} ${invoiceNumber(bill)} · ${fmt.dateTime(bill.createdAt)}',
    '',
    for (final line in bill.lines)
      line.discount > 0
          ? '${tamil && line.nameTamil.trim().isNotEmpty ? line.nameTamil : line.name} — ${fmt.quantityLabel(line)} — ${fmt.money2(line.amount)} '
                '(${fmt.lineDiscountLabel(line)}) = ${fmt.money2(line.netAmount)}'
          : '${tamil && line.nameTamil.trim().isNotEmpty ? line.nameTamil : line.name} — ${fmt.quantityLabel(line)} — ${fmt.money2(line.amount)}',
    '',
    for (final row in fmt.billSummary(bill))
      '${_summaryLabel(row.label, tamil)}: ${row.value}',
    '*${tr('Total', 'மொத்தம்')}: ${fmt.money2(bill.grandTotal)}*',
    if ((bill.advanceAmount ?? 0) > 0)
      '${tr('Advance Paid', 'முன்பணம்')}: ${fmt.money2(bill.advanceAmount!)}',
    if ((bill.advanceAmount ?? 0) > 0)
      '${tr('Total Due', 'செலுத்த வேண்டிய தொகை')}: ${fmt.money2(bill.balanceDue)}',
    if (bill.paymentDone) '*${tr('PAYMENT DONE', 'கட்டணம் செலுத்தப்பட்டது')}*',
    if (bill.gpayQrFor(shop) != null)
      tr(
        'Pay online: scan the GPay QR on the bill',
        'ஆன்லைன் கட்டணம்: ரசீதில் உள்ள GPay QR-ஐ ஸ்கேன் செய்யவும்',
      ),
    if (footer.trim().isNotEmpty) ...['', footer.trim()],
  ];
  return lines.join('\n');
}
