import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart' as fmt;
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'admin/image_picker_field.dart';
import 'bill_flows.dart';
import 'invoice_screen.dart';
import 'item_sheet.dart';
import 'shell.dart';

/// The current draft bill. [embedded] is the persistent tablet side panel.
class BillScreen extends StatelessWidget {
  const BillScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final bill = store.draft;
    final source = store.draftSource;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Column(
          children: [
            const Text('Current Bill'),
            if (source != null)
              Text(
                'Editing ${source.displayNumber}${store.draftDirty ? ' · unsaved changes' : ''}',
                style: const TextStyle(fontSize: 12, color: QsColors.gold),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Quick add custom item',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => openCustomItem(context),
          ),
          if (!bill.isEmpty)
            PopupMenuButton<String>(
              tooltip: 'More bill actions',
              onSelected: (value) => switch (value) {
                'preview' => Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(
                    builder: (_) => InvoiceScreen(bill: bill, isDraft: true),
                  ),
                ),
                'clear' => _clear(context, store),
                _ => null,
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'preview',
                  child: ListTile(
                    leading: Icon(Icons.visibility_outlined),
                    title: Text('Preview & share'),
                  ),
                ),
                PopupMenuItem(
                  value: 'clear',
                  child: ListTile(
                    leading: Icon(Icons.delete_sweep_outlined),
                    title: Text('Clear bill'),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: bill.isEmpty
          ? EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No items in this bill',
              message: embedded
                  ? 'Tap a product on the left to add it.'
                  : 'Pick products from Home, or quick add a custom item.',
              action: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  if (!embedded)
                    FilledButton.icon(
                      onPressed: () => Shell.go(Shell.home),
                      icon: const Icon(Icons.storefront_outlined),
                      label: const Text('Browse products'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => openCustomItem(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Quick add'),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              children: [
                for (final line in bill.lines) ...[
                  _LineTile(line: line),
                  const SizedBox(height: 8),
                ],
                TextButton.icon(
                  onPressed: () =>
                      embedded ? openCustomItem(context) : Shell.go(Shell.home),
                  icon: const Icon(Icons.add),
                  label: Text(embedded ? 'Quick add item' : 'Add more items'),
                ),
                const SizedBox(height: 4),
                _BillDetailsCard(bill: bill, settings: store.settings),
              ],
            ),
      bottomNavigationBar: _TotalsBar(bill: bill),
    );
  }

  Future<void> _clear(BuildContext context, AppStore store) async {
    final sure = await confirm(
      context,
      title: 'Clear current bill?',
      message:
          'All ${store.draft.lines.length} items will be removed from this bill.',
      confirmLabel: 'Clear bill',
      destructive: true,
      icon: Icons.delete_sweep_outlined,
    );
    if (sure) store.updateDraft((bill) => bill.lines.clear());
  }
}

class _LineTile extends StatelessWidget {
  const _LineTile({required this.line});

  final BillLine line;

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final product = store.productById(line.productId);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => editLine(context, line),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
          child: Row(
            children: [
              QsImage(
                imageName: product?.imageName,
                label: line.name,
                size: 52,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      fmt.quantityLabel(line),
                      style: const TextStyle(fontSize: 14),
                    ),
                    Text(
                      [
                        if (fmt.modeLabel(line.mode) != fmt.quantityLabel(line))
                          fmt.modeLabel(line.mode),
                        if (fmt.rateLabel(line) != '—') fmt.rateLabel(line),
                        if (line.rateOverridden) 'rate changed',
                        if (line.note != null &&
                            line.mode != LineMode.amountOnly)
                          line.note!,
                      ].join(' · '),
                      style: TextStyle(
                        fontSize: 12,
                        color: line.rateOverridden
                            ? QsColors.gold
                            : QsColors.muted,
                      ),
                    ),
                    if (line.discount > 0)
                      Text(
                        '${fmt.lineDiscountLabel(line)} · - ${fmt.money2(line.discount)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: QsColors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (line.discount > 0)
                    Text(
                      fmt.money2(line.amount),
                      style: const TextStyle(
                        fontSize: 12,
                        color: QsColors.muted,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  Text(
                    fmt.money2(line.netAmount),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: QsColors.maroon,
                    ),
                  ),
                ],
              ),
              IconButton(
                tooltip: 'Remove ${line.name}',
                icon: const Icon(Icons.close, color: QsColors.muted),
                onPressed: () {
                  final index = store.removeLine(line);
                  showMessage(
                    context,
                    'Removed ${line.name}',
                    action: SnackBarAction(
                      label: 'Undo',
                      onPressed: () => store.restoreLine(line, index),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BillDetailsCard extends StatelessWidget {
  const _BillDetailsCard({required this.bill, required this.settings});

  final Bill bill;
  final ShopSettings settings;

  @override
  Widget build(BuildContext context) {
    final shopPhone = bill.shopPhoneFor(settings);
    final details = [
      fmt.dateTime(bill.createdAt),
      if (settings.address.trim().isNotEmpty) settings.address.trim(),
      if (shopPhone.isNotEmpty) 'Shop phone: $shopPhone',
      if (bill.gpayQrFor(settings) != null) 'Pay online: GPay QR',
      if (bill.customerName?.isNotEmpty == true ||
          bill.customerPhone?.isNotEmpty == true)
        [
          bill.customerName,
          bill.customerPhone,
        ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
      if (bill.discountAmount > 0)
        'Bill discount ${bill.discountType == DiscountType.percent ? '${fmt.editable(bill.discountValue)}%' : fmt.money(bill.discountValue)}',
      if (bill.paymentMethod != null) 'Payment: ${bill.paymentMethod}',
      if (bill.notes?.isNotEmpty == true) 'Note: ${bill.notes}',
    ];
    final options = [
      if (settings.customerDetailsEnabled) 'customer',
      'discount',
      if (settings.paymentEnabled) 'payment',
      'notes',
    ];
    return Card(
      child: ListTile(
        leading: const Icon(Icons.tune, color: QsColors.maroon),
        title: const Text(
          'Bill details',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          details.isEmpty ? 'Add ${options.join(', ')}' : details.join('\n'),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => showSheet<void>(context, (_) => const _BillDetailsSheet()),
      ),
    );
  }
}

class _TotalsBar extends StatelessWidget {
  const _TotalsBar({required this.bill});

  final Bill bill;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    elevation: 8,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final row in fmt.billSummary(bill))
              TotalRow(
                row.label,
                row.value,
                color: row.discount ? QsColors.green : null,
              ),
            const Divider(height: 14),
            TotalRow('Grand Total', fmt.money2(bill.grandTotal), big: true),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: bill.isEmpty ? null : () => saveBill(context),
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save Bill'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => startNewBill(context),
                    icon: const Icon(Icons.note_add_outlined),
                    label: const Text('New Bill'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _BillDetailsSheet extends StatefulWidget {
  const _BillDetailsSheet();

  @override
  State<_BillDetailsSheet> createState() => _BillDetailsSheetState();
}

class _BillDetailsSheetState extends State<_BillDetailsSheet> {
  late final AppStore _store = context.read<AppStore>();
  late final _name = TextEditingController(text: _store.draft.customerName);
  late final _phone = TextEditingController(text: _store.draft.customerPhone);
  late final _shopPhone = TextEditingController(
    text: _store.draft.shopPhoneFor(_store.settings),
  );
  late String? _gpayQrName =
      _store.draft.gpayQrName ?? _store.settings.gpayQrName;
  late bool _payOnline = _store.draft.payOnlineEnabled;
  late final _notes = TextEditingController(text: _store.draft.notes);
  late final _discount = TextEditingController(
    text: _store.draft.discountValue > 0
        ? fmt.editable(_store.draft.discountValue, maxDecimals: 2)
        : '',
  );
  late DiscountType _discountType = _store.draft.discountType;
  late String? _payment = _store.draft.paymentMethod;
  late final _advance = TextEditingController(
    text: (_store.draft.advanceAmount ?? 0) > 0
        ? fmt.editable(_store.draft.advanceAmount!, maxDecimals: 2)
        : '',
  );
  late DateTime _when = _store.draft.createdAt;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _phone,
      _shopPhone,
      _notes,
      _discount,
      _advance,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? get _discountError {
    if (_discountType == DiscountType.none || _discount.text.isEmpty) {
      return null;
    }
    final value = fmt.parseNumber(_discount.text);
    if (value == null || value < 0) return 'Enter a valid discount';
    if (_discountType == DiscountType.percent && value > 100) {
      return 'Percentage cannot exceed 100';
    }
    if (_discountType == DiscountType.fixed && value > _store.draft.subtotal) {
      return 'Discount cannot exceed the bill amount';
    }
    return null;
  }

  String? get _advanceError {
    if (_advance.text.trim().isEmpty) return null;
    final value = fmt.parseNumber(_advance.text);
    if (value == null || value < 0) return 'Enter a valid advance amount';
    if (value > _store.draft.grandTotal) {
      return 'Advance cannot exceed the bill total';
    }
    return null;
  }

  void _save() {
    if (_discountError != null || _advanceError != null) return;
    String? clean(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    final discount = fmt.parseNumber(_discount.text) ?? 0;
    _store.updateDraft(
      (bill) => bill
        ..customerName = clean(_name)
        ..customerPhone = clean(_phone)
        ..shopPhone = _shopPhone.text.trim()
        ..gpayQrName = _gpayQrName ?? ''
        ..notes = clean(_notes)
        ..discountType = discount > 0 ? _discountType : DiscountType.none
        ..discountValue = discount > 0 ? discount : 0
        ..paymentMethod = _payment
        ..payOnlineEnabled = _payOnline
        ..advanceAmount = (fmt.parseNumber(_advance.text) ?? 0) > 0
            ? fmt.parseNumber(_advance.text)
            : null
        ..createdAt = _when,
    );
    Navigator.pop(context);
  }

  Future<void> _pickWhen() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when),
    );
    if (time == null || !mounted) return;
    setState(
      () => _when = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = _store.settings;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Bill details',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            settings.shopName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: QsColors.maroon,
            ),
          ),
          if (settings.tagline.trim().isNotEmpty)
            Text(
              settings.tagline.trim(),
              style: const TextStyle(fontSize: 12, color: QsColors.muted),
            ),
          if (settings.address.trim().isNotEmpty)
            Text(settings.address.trim(), style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event, color: QsColors.maroon),
            title: const Text('Bill date & time'),
            subtitle: Text(fmt.dateTime(_when)),
            trailing: const Icon(Icons.edit_outlined),
            onTap: _pickWhen,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _shopPhone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Shop phone on this bill',
              hintText: '+91 98765 43210',
            ),
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _payOnline,
            title: const Text('Add online payment to this bill'),
            subtitle: const Text('Print the GPay / UPI QR code on the bill.'),
            onChanged: (enabled) =>
                setState(() => _payOnline = enabled ?? false),
          ),
          if (_payOnline) ...[
            const SizedBox(height: 8),
            ImagePickerField(
              imageName: _gpayQrName == null || _gpayQrName!.isEmpty
                  ? null
                  : _gpayQrName,
              label: 'GPay QR code',
              size: 140,
              onChanged: (name) => setState(() => _gpayQrName = name ?? ''),
            ),
          ],
          const SizedBox(height: 16),
          if (settings.customerDetailsEnabled) ...[
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Customer name (optional)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Customer phone (optional)',
                hintText: '+91 98765 43210',
              ),
            ),
            const SizedBox(height: 12),
          ],
          const Text(
            'Whole-bill discount',
            style: TextStyle(color: QsColors.muted),
          ),
          const Text(
            'Applied after item discounts. Set item discounts by tapping an item.',
            style: TextStyle(fontSize: 12, color: QsColors.muted),
          ),
          const SizedBox(height: 6),
          SegmentedButton<DiscountType>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: DiscountType.none, label: Text('None')),
              ButtonSegment(value: DiscountType.fixed, label: Text('₹ Amount')),
              ButtonSegment(
                value: DiscountType.percent,
                label: Text('% Percent'),
              ),
            ],
            selected: {_discountType},
            onSelectionChanged: (s) => setState(() => _discountType = s.first),
          ),
          if (_discountType != DiscountType.none) ...[
            const SizedBox(height: 12),
            NumberField(
              controller: _discount,
              label: _discountType == DiscountType.percent
                  ? 'Discount (%)'
                  : 'Discount (₹)',
              errorText: _discountError,
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 12),
          if (settings.paymentEnabled &&
              settings.paymentMethods.isNotEmpty) ...[
            const Text(
              'Payment method',
              style: TextStyle(color: QsColors.muted),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final method in settings.paymentMethods)
                  ChoiceChip(
                    label: Text(method),
                    selected: _payment == method,
                    onSelected: (selected) =>
                        setState(() => _payment = selected ? method : null),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          NumberField(
            controller: _advance,
            label: 'Advance payment (₹)',
            errorText: _advanceError,
            helperText: 'Leave blank if no advance was paid.',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Bill note (optional)',
              hintText: 'e.g. Gift packing',
            ),
          ),
          const SizedBox(height: 20),
          Row(
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
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
