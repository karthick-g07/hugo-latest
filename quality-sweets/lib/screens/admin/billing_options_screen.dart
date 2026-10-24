import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../format.dart' as fmt;
import '../../store.dart';
import '../../theme.dart';
import '../../widgets.dart';

/// Optional billing features. All are off by default except customer details.
class BillingOptionsScreen extends StatefulWidget {
  const BillingOptionsScreen({super.key});

  @override
  State<BillingOptionsScreen> createState() => _BillingOptionsScreenState();
}

class _BillingOptionsScreenState extends State<BillingOptionsScreen> {
  late final AppStore _store = context.read<AppStore>();
  late bool _customer = _store.settings.customerDetailsEnabled;
  late bool _discount = _store.settings.discountEnabled;
  late bool _payment = _store.settings.paymentEnabled;
  late bool _tax = _store.settings.taxEnabled;
  late final List<String> _methods = [..._store.settings.paymentMethods];
  late final _method = TextEditingController();
  late final _taxName = TextEditingController(text: _store.settings.taxName);
  late final _taxPercent = TextEditingController(
    text: _store.settings.taxPercent > 0 ? fmt.editable(_store.settings.taxPercent, maxDecimals: 2) : '',
  );
  late final _taxNumber = TextEditingController(text: _store.settings.taxNumber);
  late final _presets = TextEditingController(
    text: _store.settings.presetGrams.map((g) => fmt.editable(g)).join(', '),
  );
  late final _amounts = TextEditingController(
    text: _store.settings.quickAmounts.map((a) => fmt.editable(a, maxDecimals: 2)).join(', '),
  );
  bool _submitted = false;

  @override
  void dispose() {
    for (final c in [_method, _taxName, _taxPercent, _taxNumber, _presets, _amounts]) {
      c.dispose();
    }
    super.dispose();
  }

  List<double>? _numbers(String text) {
    final parts = text.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    final values = parts.map(fmt.parseNumber).toList();
    if (values.any((v) => v == null || v <= 0) || values.length > 8) return null;
    return values.cast<double>();
  }

  String? get _taxError {
    if (!_tax) return null;
    final value = fmt.parseNumber(_taxPercent.text);
    if (_taxName.text.trim().isEmpty) return 'Enter the tax name, e.g. GST';
    if (value == null || value <= 0 || value > 100) return 'Enter a percentage between 0 and 100';
    return null;
  }

  void _addMethod() {
    final method = _method.text.trim();
    if (method.isEmpty || _methods.contains(method)) return;
    setState(() {
      _methods.add(method);
      _method.clear();
    });
  }

  void _save() {
    setState(() => _submitted = true);
    final presets = _numbers(_presets.text);
    final amounts = _numbers(_amounts.text);
    if (_taxError != null || presets == null || amounts == null) return;
    _store.updateSettings(
      (s) => s
        ..customerDetailsEnabled = _customer
        ..discountEnabled = _discount
        ..paymentEnabled = _payment
        ..paymentMethods = _methods
        ..taxEnabled = _tax
        ..taxName = _taxName.text.trim()
        ..taxPercent = fmt.parseNumber(_taxPercent.text) ?? 0
        ..taxNumber = _taxNumber.text.trim()
        ..presetGrams = presets
        ..quickAmounts = amounts,
    );
    Navigator.pop(context);
    showMessage(context, 'Billing options saved');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Billing Options')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Customer name & phone'),
              subtitle: const Text('Optional on each bill; never required'),
              value: _customer,
              onChanged: (v) => setState(() => _customer = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Discounts'),
              subtitle: const Text('Per item (%, ₹ or minus grams/qty) and on the whole bill (%, ₹)'),
              value: _discount,
              onChanged: (v) => setState(() => _discount = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Payment method'),
              subtitle: const Text('Record Cash, UPI, Card…'),
              value: _payment,
              onChanged: (v) => setState(() => _payment = v),
            ),
            if (_payment) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final method in _methods)
                    InputChip(label: Text(method), onDeleted: () => setState(() => _methods.remove(method))),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _method,
                onSubmitted: (_) => _addMethod(),
                decoration: InputDecoration(
                  labelText: 'Add payment method',
                  suffixIcon: IconButton(tooltip: 'Add', icon: const Icon(Icons.add), onPressed: _addMethod),
                ),
              ),
              const SizedBox(height: 8),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tax'),
              subtitle: const Text('Off by default. Only enable if the shop charges tax on bills.'),
              value: _tax,
              onChanged: (v) => setState(() => _tax = v),
            ),
            if (_tax) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _taxName,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(labelText: 'Tax name', hintText: 'GST'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: NumberField(
                      controller: _taxPercent,
                      label: 'Rate (%)',
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              if (_submitted && _taxError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_taxError!, style: const TextStyle(color: QsColors.danger, fontSize: 12)),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _taxNumber,
                decoration: const InputDecoration(
                  labelText: 'Tax registration no. (optional)',
                  hintText: 'Printed on invoices only if entered',
                ),
              ),
            ],
            const SectionTitle('Quick buttons'),
            TextField(
              controller: _presets,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Preset weights in grams',
                hintText: '100, 250, 500, 1000, 2000',
                errorText: _numbers(_presets.text) == null
                    ? 'Enter up to 8 numbers separated by commas'
                    : null,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _amounts,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Quick amounts (₹)',
                hintText: '50, 100, 200, 500',
                errorText: _numbers(_amounts.text) == null
                    ? 'Enter up to 8 numbers separated by commas'
                    : null,
              ),
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
              child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(onPressed: _save, child: const Text('Save')),
            ),
          ],
        ),
      ),
    ),
  );
}
