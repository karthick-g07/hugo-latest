import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../format.dart' as fmt;
import '../../models.dart';
import '../../store.dart';
import '../../theme.dart';
import '../../widgets.dart';
import 'image_picker_field.dart';

/// Add or edit a catalog product. Rate changes only affect new bill lines.
class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.product, this.categoryId});

  final Product? product;
  final String? categoryId;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  late final AppStore _store = context.read<AppStore>();
  late final Product? _original = widget.product;
  late final _name = TextEditingController(text: _original?.name);
  late final _nameTamil = TextEditingController(text: _original?.nameTamil);
  late final _rate = TextEditingController(
    text: (_original?.ratePerKg ?? 0) > 0
        ? fmt.editable(_original!.ratePerKg, maxDecimals: 2)
        : '',
  );
  late final _unitPrice = TextEditingController(
    text: (_original?.unitPrice ?? 0) > 0
        ? fmt.editable(_original!.unitPrice, maxDecimals: 2)
        : '',
  );
  late final _unitLabel = TextEditingController(
    text: _original?.unitLabel ?? 'piece',
  );

  late String? _imageName = _original?.imageName;
  late String _categoryId = _initialCategory();
  late ProductMode _mode = _original?.mode ?? ProductMode.weight;
  late bool _preferKg = _original?.preferKg ?? false;
  late bool _allowOverride = _original?.allowRateOverride ?? true;
  late bool _popular = _original?.isPopular ?? false;
  late bool _active = _original?.isActive ?? true;
  bool _submitted = false;

  static const _unitOptions = ['piece', 'packet', 'box', 'bottle', 'plate'];

  String _initialCategory() {
    final candidates = [_original?.categoryId, widget.categoryId];
    for (final id in candidates) {
      final category = _store.categoryById(id);
      if (category != null && category.kind != CategoryKind.topRated)
        return category.id;
    }
    return _store.otherCategory.id;
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _nameTamil,
      _rate,
      _unitPrice,
      _unitLabel,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? get _nameError =>
      _name.text.trim().isEmpty ? 'Enter the product name' : null;

  String? _moneyError(
    TextEditingController controller, {
    required bool required,
  }) {
    if (controller.text.isEmpty) return required ? 'Enter a price' : null;
    final value = fmt.parseNumber(controller.text);
    if (value == null || value < 0) return 'Enter a valid amount';
    if (value > fmt.maxMoney) return 'Amount is too large';
    return null;
  }

  String? get _rateError =>
      _mode == ProductMode.weight ? _moneyError(_rate, required: false) : null;
  String? get _unitPriceError => _mode == ProductMode.unit
      ? _moneyError(_unitPrice, required: true)
      : null;
  String? get _unitLabelError =>
      _mode == ProductMode.unit && _unitLabel.text.trim().isEmpty
      ? 'Enter a unit, e.g. piece'
      : null;

  void _save() {
    setState(() => _submitted = true);
    if (_nameError != null ||
        _rateError != null ||
        _unitPriceError != null ||
        _unitLabelError != null) {
      return;
    }
    final product =
        (_original ?? Product(id: newId(), name: '', categoryId: _categoryId))
          ..name = _name.text.trim()
          ..nameTamil = _nameTamil.text.trim()
          ..categoryId = _categoryId
          ..imageName = _imageName
          ..mode = _mode
          ..ratePerKg = fmt.parseNumber(_rate.text) ?? 0
          ..unitPrice = fmt.parseNumber(_unitPrice.text) ?? 0
          ..unitLabel = _unitLabel.text.trim().isEmpty
              ? 'piece'
              : _unitLabel.text.trim()
          ..preferKg = _preferKg
          ..allowRateOverride = _allowOverride
          ..isPopular = _popular
          ..isActive = _active;
    _store.upsertProduct(product);
    Navigator.pop(context);
    showMessage(context, _original == null ? 'Product added' : 'Product saved');
  }

  Future<void> _delete() async {
    final sure = await confirm(
      context,
      title: 'Delete ${_original!.name}?',
      message: 'The product is removed from the catalog. Saved bills keep their copy of this item.',
      confirmLabel: 'Delete',
      destructive: true,
      icon: Icons.delete_outline,
    );
    if (!sure || !mounted) return;
    _store.deleteProduct(_original);
    Navigator.pop(context);
    showMessage(context, 'Product deleted');
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Scaffold(
      appBar: AppBar(
        title: Text(_original == null ? 'Add Product' : 'Edit Product'),
        actions: [
          if (_original != null)
            IconButton(
              tooltip: 'Delete product',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: ImagePickerField(
                  imageName: _imageName,
                  label: _name.text,
                  onChanged: (name) => setState(() => _imageName = name),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Product name',
                  hintText: 'e.g. Ghee Mysore Pak',
                  errorText: _submitted ? _nameError : null,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _nameTamil,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Product name in Tamil (தமிழ்)',
                  hintText: 'தமிழில் பெயர்',
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _categoryId,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final category in store.assignableCategories)
                    DropdownMenuItem(
                      value: category.id,
                      child: Text(category.name),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _categoryId = value ?? _categoryId),
              ),
              const SizedBox(height: 18),
              const Text(
                'Billing mode',
                style: TextStyle(color: QsColors.muted),
              ),
              const SizedBox(height: 6),
              SegmentedButton<ProductMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: ProductMode.weight,
                    label: Text('Weight'),
                  ),
                  ButtonSegment(
                    value: ProductMode.unit,
                    label: Text('Per unit'),
                  ),
                  ButtonSegment(
                    value: ProductMode.amountOnly,
                    label: Text('Amount'),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (selection) =>
                    setState(() => _mode = selection.first),
              ),
              const SizedBox(height: 6),
              Text(switch (_mode) {
                ProductMode.weight =>
                  'Billed by grams/kg or by rupee amount, using a rate per kg.',
                ProductMode.unit =>
                  'Billed by count at a fixed price per piece, packet, box…',
                ProductMode.amountOnly =>
                  'Cashier enters the amount directly; no rate needed.',
              }, style: const TextStyle(fontSize: 12, color: QsColors.muted)),
              const SizedBox(height: 16),
              if (_mode == ProductMode.weight) ...[
                NumberField(
                  controller: _rate,
                  label: 'Default rate per kg (₹)',
                  prefix: '${fmt.currencySymbol} ',
                  errorText: _rateError,
                  helperText: _rate.text.isEmpty
                      ? 'Leave empty to enter the rate at billing time'
                      : null,
                  onChanged: (_) => setState(() {}),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enter weight in kg by default'),
                  subtitle: const Text('Otherwise grams'),
                  value: _preferKg,
                  onChanged: (value) => setState(() => _preferKg = value),
                ),
              ],
              if (_mode == ProductMode.unit) ...[
                TextField(
                  controller: _unitLabel,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Unit',
                    errorText: _submitted ? _unitLabelError : null,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final unit in _unitOptions)
                      ChoiceChip(
                        label: Text(unit),
                        selected: _unitLabel.text.trim() == unit,
                        onSelected: (_) =>
                            setState(() => _unitLabel.text = unit),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                NumberField(
                  controller: _unitPrice,
                  label:
                      'Price per ${_unitLabel.text.trim().isEmpty ? 'unit' : _unitLabel.text.trim()} (₹)',
                  prefix: '${fmt.currencySymbol} ',
                  errorText: _submitted || _unitPrice.text.isNotEmpty
                      ? _unitPriceError
                      : null,
                  onChanged: (_) => setState(() {}),
                ),
              ],
              if (_mode != ProductMode.amountOnly)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Allow price change at billing'),
                  subtitle: const Text(
                    'Cashier can change the rate for one bill line',
                  ),
                  value: _allowOverride,
                  onChanged: (value) => setState(() => _allowOverride = value),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Top rated / popular'),
                subtitle: const Text('Show in Top Rated Specials'),
                value: _popular,
                onChanged: (value) => setState(() => _popular = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                subtitle: const Text(
                  'Inactive products are hidden from billing',
                ),
                value: _active,
                onChanged: (value) => setState(() => _active = value),
              ),
              if (_original != null)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Changing a rate affects new bill lines only. Saved bills keep their original rates.',
                    style: TextStyle(fontSize: 12, color: QsColors.muted),
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
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('Save Product'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
