import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../format.dart' as fmt;
import '../invoice_pdf.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Invoice preview with PDF, image, print and WhatsApp sharing.
class InvoiceScreen extends StatefulWidget {
  const InvoiceScreen({super.key, required this.bill, this.isDraft = false});

  final Bill bill;
  final bool isDraft;

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  String? _busy;
  late String _billLanguage = _store.settings.language;

  AppStore get _store => context.read<AppStore>();
  Bill get _bill => widget.bill;

  String get _fileBase =>
      (_bill.isSaved ? (_bill.displayNumber ?? 'bill') : 'draft-bill')
          .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  Rect? _origin() {
    final box = context.findRenderObject() as RenderBox?;
    return box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  }

  Future<Uint8List> _pdf() async {
    final settings = _store.settings;
    final logoName = settings.logoName;
    final qrName = _bill.gpayQrFor(settings);
    final logo = logoName == null
        ? null
        : await _store.storage.readImage(logoName);
    final gpayQr = qrName == null
        ? null
        : await _store.storage.readImage(qrName);
    return buildInvoicePdf(
      _bill,
      settings,
      logo: logo,
      gpayQr: gpayQr,
      language: _billLanguage,
    );
  }

  Future<void> _run(String label, Future<void> Function() task) async {
    if (_busy != null) return;
    setState(() => _busy = label);
    try {
      await task();
    } catch (error) {
      if (mounted) showMessage(context, 'Could not complete: $error');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<File> _tempFile(String name, List<int> bytes) async {
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/$name').writeAsBytes(bytes, flush: true);
  }

  Future<void> _share(List<XFile> files, {String? text}) async {
    final result = await SharePlus.instance.share(
      ShareParams(
        files: files,
        text: text,
        subject: '${_store.settings.shopName} bill ${invoiceNumber(_bill)}',
        sharePositionOrigin: _origin(),
      ),
    );
    if (!mounted) return;
    if (result.status == ShareResultStatus.success) {
      showMessage(context, 'Shared');
    } else if (result.status == ShareResultStatus.dismissed) {
      showMessage(context, 'Sharing cancelled — nothing was sent');
    }
  }

  Future<void> sharePdf() => _run('Preparing PDF…', () async {
    final file = await _tempFile('$_fileBase.pdf', await _pdf());
    await _share([XFile(file.path, mimeType: 'application/pdf')]);
  });

  Future<List<XFile>> _invoiceImages() async {
    final pdf = await _pdf();
    final files = <XFile>[];
    var page = 1;
    await for (final raster in Printing.raster(pdf, dpi: 200)) {
      final file = await _tempFile(
        '${_fileBase}_$page.png',
        await raster.toPng(),
      );
      files.add(XFile(file.path, mimeType: 'image/png'));
      page++;
    }
    return files;
  }

  Future<void> shareImage() => _run('Preparing image…', () async {
    await _share(await _invoiceImages());
  });

  Future<void> printBill() => _run('Opening printer…', () async {
    final pdf = await _pdf();
    await Printing.layoutPdf(onLayout: (_) async => pdf, name: _fileBase);
  });

  Future<void> shareText() => _run('Sharing…', () async {
    await SharePlus.instance.share(
      ShareParams(
        text: invoiceText(_bill, _store.settings, language: _billLanguage),
        sharePositionOrigin: _origin(),
      ),
    );
  });

  void _shareOptions() => showSheet<void>(
    context,
    (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Share Options',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (final (icon, title, subtitle, action) in [
            (
              Icons.picture_as_pdf_outlined,
              'Share as PDF',
              'Best for printing and records',
              sharePdf,
            ),
            (
              Icons.image_outlined,
              'Share as Image',
              'Quick to view on any phone',
              shareImage,
            ),
            (
              Icons.chat_outlined,
              'WhatsApp',
              'Choose a number and send text, PDF or image',
              _whatsApp,
            ),
            (
              Icons.print_outlined,
              'Print Invoice',
              'Use a connected or network printer',
              printBill,
            ),
            (
              Icons.short_text,
              'Share as Text',
              'Plain bill summary to any app',
              shareText,
            ),
          ])
            ListTile(
              leading: CircleAvatar(
                backgroundColor: QsColors.creamDeep,
                child: Icon(icon, color: QsColors.maroon),
              ),
              title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(sheet);
                action();
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  Future<void> _whatsApp() async {
    final request = await showSheet<String>(
      context,
      (_) => _WhatsAppSheet(initial: _bill.customerPhone ?? ''),
    );
    if (request == null || !mounted) return;
    final separator = request.indexOf(':');
    if (separator < 0) return;
    final type = request.substring(0, separator);
    final phone = request.substring(separator + 1);
    if (type == 'text') {
      final uri = Uri.https('wa.me', '/$phone', {
        'text': invoiceText(_bill, _store.settings, language: _billLanguage),
      });
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (mounted && !opened) showMessage(context, 'Could not open WhatsApp.');
      return;
    }
    await _run('Preparing WhatsApp bill…', () async {
      final files = <XFile>[];
      if (type == 'pdf' || type == 'both') {
        final pdf = await _tempFile('$_fileBase.pdf', await _pdf());
        files.add(XFile(pdf.path, mimeType: 'application/pdf'));
      }
      if (type == 'image' || type == 'both') {
        files.addAll(await _invoiceImages());
      }
      await _share(
        files,
        text: invoiceText(_bill, _store.settings, language: _billLanguage),
      );
    });
  }

  /// Offers to also send the same bill to the configured owner numbers.
  /// Each number is opened one at a time; the user still sends it manually.
  Future<void> offerOwnerCopy() async {
    final settings = _store.settings;
    if (!settings.notifyOwnerOnShare || settings.ownerWhatsAppNumbers.isEmpty) {
      return;
    }
    await showSheet<void>(
      context,
      (_) => _OwnerCopySheet(bill: _bill, settings: settings),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppStore>().settings;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isDraft ? 'Bill Preview' : (_bill.name ?? 'Bill')),
        actions: [
          IconButton(
            tooltip: 'Share options',
            icon: const Icon(Icons.ios_share),
            onPressed: _shareOptions,
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (widget.isDraft)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'This bill is not saved yet. Save it to assign a bill number.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: QsColors.muted),
                  ),
                ),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'en', label: Text('English bill')),
                  ButtonSegment(value: 'ta', label: Text('தமிழ் பில்')),
                ],
                selected: {_billLanguage},
                onSelectionChanged: (selection) =>
                    setState(() => _billLanguage = selection.first),
              ),
              const SizedBox(height: 12),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: InvoiceView(
                    bill: _bill,
                    settings: settings,
                    language: _billLanguage,
                  ),
                ),
              ),
            ],
          ),
          if (_busy != null)
            ColoredBox(
              color: Colors.black38,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(width: 20),
                        Text(_busy!, style: const TextStyle(fontSize: 16)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: sharePdf,
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Share PDF'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: shareImage,
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('Share Image'),
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    _store.setPaymentDone(_bill, !_bill.paymentDone),
                icon: Icon(
                  _bill.paymentDone ? Icons.undo : Icons.check_circle_outline,
                ),
                label: Text(
                  _bill.paymentDone ? 'Undo payment done' : 'Mark payment done',
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: QsColors.green,
                  ),
                  onPressed: _whatsApp,
                  icon: const Icon(Icons.chat),
                  label: const Text('Share via WhatsApp'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// On-screen invoice that mirrors the PDF layout.
class InvoiceView extends StatelessWidget {
  const InvoiceView({
    super.key,
    required this.bill,
    required this.settings,
    this.language = 'en',
  });

  final Bill bill;
  final ShopSettings settings;
  final String language;

  @override
  Widget build(BuildContext context) {
    final tamil = language == 'ta';
    String tr(String english, String tamilText) => tamil ? tamilText : english;
    final shopName = tamil && settings.shopNameTamil.trim().isNotEmpty
        ? settings.shopNameTamil
        : settings.shopName;
    final tagline = tamil && settings.taglineTamil.trim().isNotEmpty
        ? settings.taglineTamil
        : settings.tagline;
    final address = tamil && settings.addressTamil.trim().isNotEmpty
        ? settings.addressTamil
        : settings.address;
    final footer = tamil && settings.footerTamil.trim().isNotEmpty
        ? settings.footerTamil
        : settings.footer;
    String summaryLabel(String label) => switch (label) {
      'Actual amount' => 'உண்மையான தொகை',
      'Item discounts' => 'பொருள் தள்ளுபடி',
      'Bill discount' => 'பில் தள்ளுபடி',
      'Total discount' => 'மொத்த தள்ளுபடி',
      'After discount' => 'தள்ளுபடிக்குப் பின்',
      _ => label,
    };
    const small = TextStyle(fontSize: 12, color: QsColors.muted);
    const head = TextStyle(fontSize: 12, fontWeight: FontWeight.w700);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const QsLogo(size: 52),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BrandTitle(shopName, size: 22),
                      if (tagline.isNotEmpty)
                        Text(
                          tagline,
                          style: const TextStyle(
                            fontSize: 12,
                            color: QsColors.gold,
                          ),
                        ),
                      if (address.trim().isNotEmpty)
                        Text(address.trim(), style: small),
                      if (bill.shopPhoneFor(settings).isNotEmpty)
                        Text(
                          '${tr('Phone', 'தொலைபேசி')}: ${bill.shopPhoneFor(settings)}',
                          style: small,
                        ),
                      if (settings.taxEnabled &&
                          settings.taxNumber.trim().isNotEmpty)
                        Text(
                          'Tax No: ${settings.taxNumber.trim()}',
                          style: small,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(height: 2, color: QsColors.maroon),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${tr('Bill No', 'ரசீது எண்')}: ${invoiceNumber(bill)}',
                        style: head,
                      ),
                      Text(
                        '${tr('Date', 'தேதி')}: ${fmt.dateTime(bill.createdAt)}',
                        style: small,
                      ),
                      if (bill.name?.isNotEmpty == true)
                        Text(bill.name!, style: small),
                    ],
                  ),
                ),
                if (bill.customerName?.isNotEmpty == true ||
                    bill.customerPhone?.isNotEmpty == true)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(tr('Customer', 'வாடிக்கையாளர்'), style: small),
                      if (bill.customerName?.isNotEmpty == true)
                        Text(bill.customerName!, style: head),
                      if (bill.customerPhone?.isNotEmpty == true)
                        Text(bill.customerPhone!, style: small),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              color: QsColors.cream,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(tamil ? 'பொருள்' : 'Item', style: head),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(tamil ? 'அளவு' : 'Qty', style: head),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      tamil ? 'தொகை' : 'Amount',
                      style: head,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
            for (final line in bill.lines)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: QsColors.border)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tamil && line.nameTamil.trim().isNotEmpty
                                ? line.nameTamil
                                : line.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (fmt.rateLabel(line) != '—')
                            Text(fmt.rateLabel(line), style: small),
                          if (line.note != null &&
                              line.mode != LineMode.amountOnly)
                            Text(line.note!, style: small),
                          if (line.discount > 0)
                            Text(
                              fmt.lineDiscountLabel(line),
                              style: const TextStyle(
                                fontSize: 12,
                                color: QsColors.green,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        fmt.quantityLabel(line),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (line.discount > 0) ...[
                            Text(fmt.money2(line.amount), style: small),
                            Text(
                              '- ${fmt.money2(line.discount)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: QsColors.green,
                              ),
                            ),
                          ],
                          Text(
                            fmt.money2(line.netAmount),
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            for (final row in fmt.billSummary(bill))
              TotalRow(
                tamil ? summaryLabel(row.label) : row.label,
                row.value,
                color: row.discount ? QsColors.green : null,
              ),
            const Divider(height: 16, color: QsColors.maroon),
            TotalRow(
              tr('Total', 'மொத்தம்'),
              fmt.money2(bill.grandTotal),
              big: true,
            ),
            if ((bill.advanceAmount ?? 0) > 0) ...[
              TotalRow(
                tr('Advance Paid', 'முன்பணம்'),
                fmt.money2(bill.advanceAmount!),
              ),
              TotalRow(
                tr('Total Due', 'செலுத்த வேண்டிய தொகை'),
                fmt.money2(bill.balanceDue),
                big: true,
              ),
            ],
            if (bill.paymentDone) _PaidBadge(language: language),
            if (bill.paymentMethod != null)
              TotalRow(tr('Payment', 'கட்டணம்'), bill.paymentMethod!),
            if (bill.gpayQrFor(settings) != null) ...[
              const SizedBox(height: 16),
              Text(
                tr('Pay online', 'ஆன்லைனில் செலுத்த'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: QsColors.maroon,
                ),
              ),
              Text(
                tr(
                  'Scan with GPay or any UPI app',
                  'GPay அல்லது UPI செயலியில் ஸ்கேன் செய்யவும்',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: QsColors.muted),
              ),
              const SizedBox(height: 8),
              Center(
                child: QsImage(
                  imageName: bill.gpayQrFor(settings),
                  label: 'GPay QR',
                  size: 160,
                  radius: 8,
                ),
              ),
            ],
            if (bill.notes?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Note: ${bill.notes}',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            if (footer.trim().isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                footer.trim(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: QsColors.maroon,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PaidBadge extends StatelessWidget {
  const _PaidBadge({required this.language});

  final String language;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: 8),
    child: Align(
      alignment: Alignment.centerRight,
      child: Chip(
        avatar: Icon(Icons.check_circle, color: QsColors.green),
        label: Text(
          language == 'ta' ? 'கட்டணம் செலுத்தப்பட்டது' : 'PAYMENT DONE',
        ),
      ),
    ),
  );
}

/// Selects a customer number and bill content for WhatsApp sharing.
class _WhatsAppSheet extends StatefulWidget {
  const _WhatsAppSheet({required this.initial});

  final String initial;

  @override
  State<_WhatsAppSheet> createState() => _WhatsAppSheetState();
}

class _WhatsAppSheetState extends State<_WhatsAppSheet> {
  late final _phone = TextEditingController(
    text: widget.initial.isEmpty ? '+91 ' : widget.initial,
  );
  bool _submitted = false;

  void _send(String type) {
    if (type != 'text') {
      Navigator.pop(context, type);
      return;
    }
    final phone = fmt.normalisePhone(_phone.text);
    if (phone == null) {
      setState(() => _submitted = true);
      return;
    }
    Navigator.pop(context, '$type:$phone');
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final recent = <String, String>{};
    for (final bill in store.savedBills.reversed) {
      final phone = bill.customerPhone?.trim();
      if (phone != null &&
          phone.isNotEmpty &&
          fmt.normalisePhone(phone) != null) {
        recent.putIfAbsent(
          fmt.normalisePhone(phone)!,
          () => bill.customerName?.trim().isNotEmpty == true
              ? bill.customerName!
              : phone,
        );
      }
      if (recent.length >= 6) break;
    }
    final error = _submitted && fmt.normalisePhone(_phone.text) == null
        ? 'Enter a valid number with country code, e.g. +91 98765 43210'
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Share on WhatsApp',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Bill text opens a chat with the number below. PDF and image sharing opens WhatsApp’s recipient picker; you do not need to enter a number for files.',
            style: TextStyle(color: QsColors.muted),
          ),
          if (recent.isNotEmpty) ...[
            const SectionTitle('Recent customers'),
            for (final entry in recent.entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: QsColors.creamDeep,
                  child: Text(
                    entry.value.characters.first.toUpperCase(),
                    style: const TextStyle(
                      color: QsColors.maroon,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                title: Text(entry.value),
                subtitle: Text('+${entry.key}'),
                onTap: () {
                  _phone.text = '+${entry.key}';
                  setState(() {});
                },
              ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            autofocus: recent.isEmpty,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Phone number for bill text',
              prefixIcon: const Icon(Icons.phone_outlined),
              errorText: error,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: QsColors.green),
            onPressed: () => _send('text'),
            icon: const Icon(Icons.short_text),
            label: const Text('Open chat with bill text'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _send('pdf'),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Share PDF'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _send('image'),
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Share Image'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _send('both'),
            icon: const Icon(Icons.attach_file),
            label: const Text('Share PDF + Image'),
          ),
        ],
      ),
    );
  }
}

/// Offers to forward the same bill to the shop's own WhatsApp numbers.
/// Each number is opened one at a time so the cashier confirms every send;
/// nothing here claims a message was actually delivered.
class _OwnerCopySheet extends StatefulWidget {
  const _OwnerCopySheet({required this.bill, required this.settings});

  final Bill bill;
  final ShopSettings settings;

  @override
  State<_OwnerCopySheet> createState() => _OwnerCopySheetState();
}

class _OwnerCopySheetState extends State<_OwnerCopySheet> {
  final _opened = <String>{};

  Future<void> _open(String number) async {
    final uri = Uri.https('wa.me', '/$number', {
      'text': invoiceText(widget.bill, widget.settings),
    });
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened && mounted) setState(() => _opened.add(number));
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Also send to shop owner?',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        const Text(
          'Sends the same bill to the owner numbers set in Admin. Open each one and tap send in WhatsApp.',
          style: TextStyle(color: QsColors.muted),
        ),
        const SizedBox(height: 12),
        for (final number in widget.settings.ownerWhatsAppNumbers)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: Icon(
                _opened.contains(number)
                    ? Icons.check_circle
                    : Icons.chat_outlined,
                color: _opened.contains(number)
                    ? QsColors.green
                    : QsColors.maroon,
              ),
              title: Text(fmt.displayPhone(number)),
              subtitle: Text(
                _opened.contains(number) ? 'WhatsApp opened' : 'Not sent yet',
              ),
              trailing: FilledButton(
                onPressed: () => _open(number),
                child: const Text('Open'),
              ),
            ),
          ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    ),
  );
}
