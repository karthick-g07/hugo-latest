import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../store.dart';
import '../../theme.dart';
import '../../widgets.dart';
import 'image_picker_field.dart';

class ShopSettingsScreen extends StatefulWidget {
  const ShopSettingsScreen({super.key});

  @override
  State<ShopSettingsScreen> createState() => _ShopSettingsScreenState();
}

class _ShopSettingsScreenState extends State<ShopSettingsScreen> {
  late final AppStore _store = context.read<AppStore>();
  late final _name = TextEditingController(text: _store.settings.shopName);
  late final _nameTamil = TextEditingController(
    text: _store.settings.shopNameTamil,
  );
  late final _tagline = TextEditingController(text: _store.settings.tagline);
  late final _taglineTamil = TextEditingController(
    text: _store.settings.taglineTamil,
  );
  late final _address = TextEditingController(text: _store.settings.address);
  late final _addressTamil = TextEditingController(
    text: _store.settings.addressTamil,
  );
  late final _phone = TextEditingController(text: _store.settings.phone);
  late final _footer = TextEditingController(text: _store.settings.footer);
  late final _footerTamil = TextEditingController(
    text: _store.settings.footerTamil,
  );
  late final _prefix = TextEditingController(
    text: _store.settings.invoicePrefix,
  );
  late final _nextNumber = TextEditingController(
    text: '${_store.settings.nextBillNumber}',
  );
  late final _currency = TextEditingController(
    text: _store.settings.currencySymbol,
  );
  late String? _logoName = _store.settings.logoName;
  late String? _gpayQrName = _store.settings.gpayQrName;
  bool _submitted = false;

  @override
  void dispose() {
    for (final c in [
      _name,
      _nameTamil,
      _tagline,
      _taglineTamil,
      _address,
      _addressTamil,
      _phone,
      _footer,
      _footerTamil,
      _prefix,
      _nextNumber,
      _currency,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  int get _highestNumber => _store.savedBills.fold(
    0,
    (max, b) => (b.number ?? 0) > max ? b.number! : max,
  );

  String? get _numberError {
    final value = int.tryParse(_nextNumber.text.trim());
    if (value == null || value < 1) return 'Enter a number of 1 or more';
    if (value <= _highestNumber)
      return 'Must be above the last used number ($_highestNumber)';
    return null;
  }

  void _save() {
    setState(() => _submitted = true);
    if (_name.text.trim().isEmpty ||
        _numberError != null ||
        _currency.text.trim().isEmpty)
      return;
    _store.updateSettings(
      (s) => s
        ..shopName = _name.text.trim()
        ..shopNameTamil = _nameTamil.text.trim()
        ..tagline = _tagline.text.trim()
        ..taglineTamil = _taglineTamil.text.trim()
        ..address = _address.text.trim()
        ..addressTamil = _addressTamil.text.trim()
        ..phone = _phone.text.trim()
        ..footer = _footer.text.trim()
        ..footerTamil = _footerTamil.text.trim()
        ..invoicePrefix = _prefix.text.trim()
        ..nextBillNumber = int.parse(_nextNumber.text.trim())
        ..currencySymbol = _currency.text.trim()
        ..logoName = _logoName
        ..gpayQrName = _gpayQrName,
    );
    Navigator.pop(context);
    showMessage(context, 'Shop settings saved');
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    String? error,
    int lines = 1,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      controller: controller,
      maxLines: lines,
      keyboardType: keyboard,
      onChanged: (_) => setState(() {}),
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: error,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Shop Settings')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Column(
                children: [
                  ImagePickerField(
                    imageName: _logoName,
                    label: 'Shop logo',
                    size: 96,
                    circle: true,
                    onChanged: (name) => setState(() => _logoName = name),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Logo (optional)',
                    style: TextStyle(fontSize: 12, color: QsColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _field(
              _name,
              'Shop name',
              error: _submitted && _name.text.trim().isEmpty
                  ? 'Enter the shop name'
                  : null,
            ),
            _field(_nameTamil, 'Shop name in Tamil (தமிழ்)'),
            _field(_tagline, 'Tagline (optional)'),
            _field(_taglineTamil, 'Tagline in Tamil (தமிழ்)'),
            _field(
              _address,
              'Address (optional)',
              lines: 3,
              hint: 'Printed on invoices only if entered',
            ),
            _field(_addressTamil, 'Address in Tamil (தமிழ்)', lines: 3),
            _field(
              _phone,
              'Shop phone number',
              hint: 'Printed on every bill. You can still change it on a single bill.',
              keyboard: TextInputType.phone,
            ),
            const SectionTitle('Pay online'),
            const Text(
              'Default GPay / UPI QR printed on bills. You can replace it on any bill from the gallery.',
              style: TextStyle(fontSize: 12, color: QsColors.muted),
            ),
            const SizedBox(height: 10),
            ImagePickerField(
              imageName: _gpayQrName,
              label: 'GPay QR code',
              size: 140,
              onChanged: (name) => setState(() => _gpayQrName = name),
            ),
            const SizedBox(height: 16),
            _field(_footer, 'Invoice footer', lines: 2),
            _field(_footerTamil, 'Invoice footer in Tamil (தமிழ்)', lines: 2),
            const SectionTitle('App language'),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'en', label: Text('English')),
                ButtonSegment(value: 'ta', label: Text('தமிழ்')),
              ],
              selected: {_store.settings.language},
              onSelectionChanged: (selection) =>
                  _store.updateSettings((s) => s..language = selection.first),
            ),
            const SectionTitle('Invoice numbering'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _field(_prefix, 'Prefix', hint: 'QS')),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    _nextNumber,
                    'Next number',
                    keyboard: TextInputType.number,
                    error: _numberError,
                  ),
                ),
              ],
            ),
            Text(
              'Next bill: ${_prefix.text.trim()}${(int.tryParse(_nextNumber.text) ?? 1).toString().padLeft(4, '0')}',
              style: const TextStyle(color: QsColors.muted),
            ),
            const SectionTitle('Currency'),
            _field(
              _currency,
              'Currency symbol',
              error: _submitted && _currency.text.trim().isEmpty
                  ? 'Enter a symbol'
                  : null,
            ),
          ],
        ),
      ),
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _save,
                child: const Text('Save Settings'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
