import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart' as fmt;
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'shell.dart';

typedef _SheetResult = ({BillLine line, Product? newProduct});

/// Opens the billing dialog for a catalog product and adds the result.
Future<void> openProduct(BuildContext context, Product product) async {
  final result = await showSheet<_SheetResult>(
    context,
    (_) => ItemSheet(product: product),
  );
  if (result != null && context.mounted) _add(context, result);
}

/// Opens Quick Add for an item that is not (yet) in the catalog.
Future<void> openCustomItem(
  BuildContext context, {
  String? name,
  String? categoryId,
}) async {
  final result = await showSheet<_SheetResult>(
    context,
    (_) => ItemSheet(customName: name, customCategoryId: categoryId),
  );
  if (result != null && context.mounted) _add(context, result);
}

/// Opens the dialog prefilled with an existing bill line.
Future<void> editLine(BuildContext context, BillLine line) async {
  final store = context.read<AppStore>();
  final result = await showSheet<_SheetResult>(
    context,
    (_) => ItemSheet(line: line, product: store.productById(line.productId)),
  );
  if (result == null || !context.mounted) return;
  store.updateLine(result.line);
  showMessage(context, 'Updated ${result.line.name}');
}

void _add(BuildContext context, _SheetResult result) {
  final store = context.read<AppStore>();
  if (result.newProduct != null) store.upsertProduct(result.newProduct!);
  store.addLine(result.line);
  final onBillTab = Shell.tab.value == Shell.bill;
  showMessage(
    context,
    'Added ${result.line.name} · ${fmt.money2(result.line.netAmount)}',
    action: onBillTab
        ? null
        : SnackBarAction(
            label: 'View bill',
            onPressed: () => Shell.go(Shell.bill),
          ),
  );
}

class ItemSheet extends StatefulWidget {
  const ItemSheet({
    super.key,
    this.product,
    this.line,
    this.customName,
    this.customCategoryId,
  });

  final Product? product;
  final BillLine? line;
  final String? customName;
  final String? customCategoryId;

  @override
  State<ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<ItemSheet> {
  final _name = TextEditingController();
  final _nameTamil = TextEditingController();
  final _weight = TextEditingController();
  final _rate = TextEditingController();
  final _amount = TextEditingController();
  final _units = TextEditingController();
  final _unitPrice = TextEditingController();
  final _unitLabel = TextEditingController();
  final _note = TextEditingController();
  final _discount = TextEditingController();

  LineDiscountType _discountType = LineDiscountType.none;
  late LineMode _mode;
  late List<LineMode> _modes;
  late String _categoryId;
  bool _useKg = false;
  bool _saveToCatalog = false;
  bool _submitted = false;
  bool _closing = false;

  Product? get _product => widget.product;
  BillLine? get _line => widget.line;

  /// Custom items (Quick Add, or editing a one-off line) can change name/type.
  bool get _isCustom => _product == null;
  bool get _isNew => _line == null;

  double? get _defaultRate => _product != null
      ? (_product!.defaultRate > 0 ? _product!.defaultRate : null)
      : _line?.defaultRate;

  bool get _rateEditable =>
      _isCustom || _product!.allowRateOverride || (_product!.defaultRate <= 0);

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    final product = _product;
    final line = _line;

    _modes = switch (product?.mode) {
      ProductMode.weight => [LineMode.weight, LineMode.amount],
      ProductMode.unit => [LineMode.unit],
      ProductMode.amountOnly => [LineMode.amountOnly],
      null =>
        line == null
            ? LineMode.values
            : switch (line.mode) {
                LineMode.weight ||
                LineMode.amount => [LineMode.weight, LineMode.amount],
                LineMode.unit => [LineMode.unit],
                LineMode.amountOnly => [LineMode.amountOnly],
              },
    };
    _mode =
        line?.mode ?? (product == null ? LineMode.amountOnly : _modes.first);
    _categoryId =
        widget.customCategoryId ?? line?.categoryId ?? store.otherCategory.id;
    if (store.categoryById(_categoryId) == null)
      _categoryId = store.otherCategory.id;
    _name.text = line?.name ?? widget.customName ?? '';
    _nameTamil.text = line?.nameTamil ?? '';
    _useKg = product?.preferKg ?? false;
    _unitLabel.text = line?.unitLabel ?? product?.unitLabel ?? 'piece';
    _note.text = line?.note ?? '';

    final rate = line?.appliedRate ?? _defaultRate;
    if (_modes.contains(LineMode.unit)) {
      _unitPrice.text = rate == null ? '' : fmt.editable(rate, maxDecimals: 2);
      _units.text = fmt.editable(line?.units ?? 1);
    } else {
      _rate.text = rate == null ? '' : fmt.editable(rate, maxDecimals: 2);
    }

    if (line != null) {
      final grams = line.grams;
      if (line.mode == LineMode.weight && grams != null) {
        _useKg = grams >= 1000;
        _weight.text = fmt.editable(_useKg ? grams / 1000 : grams);
      }
      if (line.mode == LineMode.amount || line.mode == LineMode.amountOnly) {
        _amount.text = fmt.editable(
          line.enteredAmount ?? line.amount,
          maxDecimals: 2,
        );
      }
      if (line.discountType != LineDiscountType.none) {
        _discountType = line.discountType;
        _discount.text = fmt.editable(line.discountValue, maxDecimals: 2);
      }
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _nameTamil,
      _weight,
      _rate,
      _amount,
      _units,
      _unitPrice,
      _unitLabel,
      _note,
      _discount,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  // ------------------------------------------------------------ Parsing

  double? get _grams {
    final value = fmt.parseNumber(_weight.text);
    return value == null ? null : (_useKg ? value * 1000 : value);
  }

  double? get _rateValue => fmt.parseNumber(_rate.text);
  double? get _amountValue => fmt.parseNumber(_amount.text);
  double? get _unitsValue => fmt.parseNumber(_units.text);
  double? get _unitPriceValue => fmt.parseNumber(_unitPrice.text);

  String? get _nameError =>
      _isCustom && _name.text.trim().isEmpty && _saveToCatalog
      ? 'Enter a name to save this product'
      : null;

  String? get _weightError {
    final grams = _grams;
    if (_weight.text.isEmpty) return _submitted ? 'Enter the weight' : null;
    if (grams == null || grams <= 0) return 'Weight must be greater than zero';
    if (grams > fmt.maxGrams) return 'Weight is too large';
    return null;
  }

  String? get _rateError {
    final rate = _rateValue;
    final required = _mode == LineMode.weight;
    if (_rate.text.isEmpty)
      return required && _submitted ? 'Enter the rate per kg' : null;
    if (rate == null || rate < 0) return 'Enter a valid rate';
    if (rate > fmt.maxMoney) return 'Rate is too large';
    if (required && rate == 0) return 'Rate must be greater than zero';
    return null;
  }

  String? get _amountError {
    final amount = _amountValue;
    if (_amount.text.isEmpty) return _submitted ? 'Enter the amount' : null;
    if (amount == null || amount <= 0)
      return 'Amount must be greater than zero';
    if (amount > fmt.maxMoney) return 'Amount is too large';
    return null;
  }

  String? get _unitsError {
    final count = _unitsValue;
    if (_units.text.isEmpty) return _submitted ? 'Enter the quantity' : null;
    if (count == null || count <= 0)
      return 'Quantity must be greater than zero';
    if (count > fmt.maxUnits) return 'Quantity is too large';
    return null;
  }

  String? get _unitPriceError {
    final price = _unitPriceValue;
    if (_unitPrice.text.isEmpty)
      return _submitted ? 'Enter the price per unit' : null;
    if (price == null || price < 0) return 'Enter a valid price';
    if (price > fmt.maxMoney) return 'Price is too large';
    return null;
  }

  /// Line amount, or null while the inputs are incomplete or invalid.
  double? get _lineAmount => switch (_mode) {
    LineMode.weight =>
      _weightError == null &&
              _rateError == null &&
              _grams != null &&
              (_rateValue ?? 0) > 0
          ? fmt.Calc.weightAmount(_grams!, _rateValue!)
          : null,
    LineMode.amount || LineMode.amountOnly =>
      _amountError == null && _amountValue != null
          ? roundMoney(_amountValue!)
          : null,
    LineMode.unit =>
      _unitsError == null &&
              _unitPriceError == null &&
              _unitsValue != null &&
              _unitPriceValue != null
          ? fmt.Calc.unitAmount(_unitsValue!, _unitPriceValue!)
          : null,
  };

  double? get _estimatedGrams {
    final amount = _amountValue;
    final rate = _rateValue;
    if (amount == null || amount <= 0 || rate == null || _rateError != null)
      return null;
    return fmt.Calc.gramsForAmount(amount, rate);
  }

  double? get _discountValue => fmt.parseNumber(_discount.text);

  String? _discountErrorFor(BillLine base) {
    if (_discountType == LineDiscountType.none || _discount.text.isEmpty)
      return null;
    final value = _discountValue;
    if (value == null || value <= 0) return 'Enter a valid discount';
    final billedQuantity =
        (base.mode == LineMode.unit ? base.units : base.grams) ?? 0;
    return switch (_discountType) {
      LineDiscountType.none => null,
      LineDiscountType.percent =>
        value > 100 ? 'Percentage cannot exceed 100' : null,
      LineDiscountType.fixed =>
        value > base.amount ? 'Discount cannot exceed the item amount' : null,
      LineDiscountType.quantity =>
        !base.allowsQuantityDiscount
            ? 'Free quantity needs a rate'
            : value > billedQuantity
            ? 'Free quantity cannot exceed the billed quantity'
            : null,
    };
  }

  String? get _discountError {
    final base = _buildLine(withDiscount: false);
    return base == null ? null : _discountErrorFor(base);
  }

  /// Bill line from the current inputs, or null while they are incomplete.
  BillLine? _buildLine({String? productId, bool withDiscount = true}) {
    final amount = _lineAmount;
    if (amount == null) return null;
    final rate = _rateValue;
    final base = BillLine(
      id: _line?.id ?? newId(),
      productId: productId ?? _product?.id ?? _line?.productId,
      categoryId: _product?.categoryId ?? _categoryId,
      name: _isCustom
          ? (_name.text.trim().isEmpty ? 'Other Item' : _name.text.trim())
          : _product!.name,
      nameTamil: _isCustom
          ? _nameTamil.text.trim()
          : (_product?.nameTamil ?? _line?.nameTamil ?? ''),
      mode: _mode,
      grams: switch (_mode) {
        LineMode.weight => _grams,
        LineMode.amount => _estimatedGrams,
        _ => null,
      },
      units: _mode == LineMode.unit ? _unitsValue : null,
      unitLabel: _mode == LineMode.unit
          ? (_product?.unitLabel ??
                (_unitLabel.text.trim().isEmpty
                    ? 'piece'
                    : _unitLabel.text.trim()))
          : null,
      enteredAmount: _mode == LineMode.amount || _mode == LineMode.amountOnly
          ? amount
          : null,
      defaultRate: _defaultRate,
      appliedRate: switch (_mode) {
        LineMode.weight => rate,
        LineMode.amount => (rate ?? 0) > 0 ? rate : null,
        LineMode.unit => _unitPriceValue,
        LineMode.amountOnly => null,
      },
      amount: amount,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    );
    final discount = _discountValue ?? 0;
    if (!withDiscount ||
        _discountType == LineDiscountType.none ||
        discount <= 0 ||
        _discountErrorFor(base) != null) {
      return base;
    }
    return BillLine.fromJson({
      ...base.toJson(),
      'discountType': _discountType.name,
      'discountValue': discount,
    });
  }

  // ------------------------------------------------------------ Actions

  void _switchUnit(bool useKg) {
    if (useKg == _useKg) return;
    final grams = _weightError == null ? _grams : null;
    setState(() {
      _useKg = useKg;
      if (grams != null) {
        _weight.text = fmt.editable(useKg ? grams / 1000 : grams);
      }
    });
  }

  void _setPreset(double grams) => setState(() {
    _useKg = grams >= 1000;
    _weight.text = fmt.editable(_useKg ? grams / 1000 : grams);
  });

  /// Reads the live value so fast repeated taps are all counted.
  void _stepUnits(int delta) => setState(() {
    final next = ((_unitsValue ?? 0) + delta).clamp(1, fmt.maxUnits).toDouble();
    _units.text = fmt.editable(next);
  });

  void _submit() {
    if (_closing) return;
    setState(() => _submitted = true);
    final base = _buildLine(withDiscount: false);
    if (base == null || _nameError != null || _discountErrorFor(base) != null)
      return;
    if (_mode == LineMode.amount && _rate.text.isNotEmpty && _rateError != null)
      return;
    final rate = _rateValue;

    Product? newProduct;
    if (_isCustom && _isNew && _saveToCatalog) {
      newProduct = Product(
        id: newId(),
        name: base.name,
        nameTamil: base.nameTamil,
        categoryId: _categoryId,
        mode: switch (_mode) {
          LineMode.weight || LineMode.amount => ProductMode.weight,
          LineMode.unit => ProductMode.unit,
          LineMode.amountOnly => ProductMode.amountOnly,
        },
        ratePerKg: _mode == LineMode.unit ? 0 : (rate ?? 0),
        unitLabel: _unitLabel.text.trim().isEmpty
            ? 'piece'
            : _unitLabel.text.trim(),
        unitPrice: _mode == LineMode.unit ? _unitPriceValue ?? 0 : 0,
      );
    }

    final line = _buildLine(productId: _product?.id ?? newProduct?.id)!;
    _closing = true;
    Navigator.pop(context, (line: line, newProduct: newProduct));
  }

  // ------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final preview = _buildLine();
    final title = _isCustom
        ? (_isNew ? 'Add Custom Item' : 'Edit Item')
        : (_isNew
              ? _product!.displayName(store.settings.language)
              : 'Edit ${_product!.displayName(store.settings.language)}');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _fields(store, title),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: const BoxDecoration(
            color: QsColors.cream,
            border: Border(top: BorderSide(color: QsColors.border)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AmountPanel(line: preview),
                const SizedBox(height: 12),
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
                        onPressed: _submit,
                        child: Text(_isNew ? 'Add to Bill' : 'Update'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _fields(AppStore store, String title) => [
    _header(title),
    const SizedBox(height: 16),
    if (_isCustom) ..._customFields(store),
    if (_modes.length > 1 && !_isCustom) ...[
      SegmentedButton<LineMode>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: LineMode.weight,
            label: Text('By Weight'),
            icon: Icon(Icons.scale_outlined),
          ),
          ButtonSegment(
            value: LineMode.amount,
            label: Text('By Amount'),
            icon: Icon(Icons.currency_rupee),
          ),
        ],
        selected: {_mode},
        onSelectionChanged: (selection) =>
            setState(() => _mode = selection.first),
      ),
      const SizedBox(height: 16),
    ],
    ...switch (_mode) {
      LineMode.weight => _weightFields(store),
      LineMode.amount => _amountFields(store),
      LineMode.unit => _unitFields(),
      LineMode.amountOnly => _amountOnlyFields(store),
    },
    const SizedBox(height: 12),
    TextField(
      controller: _note,
      textCapitalization: TextCapitalization.sentences,
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
      decoration: InputDecoration(
        labelText: _mode == LineMode.amountOnly
            ? 'Quantity / note (optional)'
            : 'Note (optional)',
        hintText: _mode == LineMode.amountOnly
            ? 'e.g. 2 packets, gift packing'
            : 'e.g. gift packing',
      ),
    ),
    ..._discountFields(),
    if (_isCustom && _isNew)
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        title: const Text('Also save as a product'),
        subtitle: const Text('Adds it to the catalog for future bills'),
        value: _saveToCatalog,
        onChanged: (value) => setState(() => _saveToCatalog = value ?? false),
      ),
  ];

  Widget _header(String title) {
    final product = _product;
    final defaultRate = _defaultRate;
    final rateText = switch (_modes.first) {
      LineMode.unit =>
        defaultRate == null
            ? null
            : '${fmt.money(defaultRate)}/${product?.unitLabel ?? _unitLabel.text}',
      LineMode.amountOnly => null,
      _ => defaultRate == null ? null : '${fmt.money(defaultRate)}/kg',
    };
    return Row(
      children: [
        if (product != null) ...[
          QsImage(
            imageName: product.imageName,
            label: product.displayName(
              context.watch<AppStore>().settings.language,
            ),
            size: 64,
          ),
          const SizedBox(width: 14),
        ] else
          const Padding(
            padding: EdgeInsets.only(right: 14),
            child: CircleAvatar(
              radius: 28,
              backgroundColor: QsColors.creamDeep,
              child: Icon(Icons.edit_note, color: QsColors.maroon, size: 32),
            ),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (rateText != null)
                Text(
                  'Default rate: $rateText',
                  style: const TextStyle(color: QsColors.muted, fontSize: 14),
                ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _customFields(AppStore store) => [
    TextField(
      controller: _name,
      autofocus: _isNew && _name.text.isEmpty,
      textCapitalization: TextCapitalization.words,
      onChanged: (_) => setState(() {}),
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
      decoration: InputDecoration(
        labelText: 'Item name',
        hintText: 'e.g. Mixture Special',
        errorText: _submitted ? _nameError : null,
      ),
    ),
    const SizedBox(height: 12),
    TextField(
      controller: _nameTamil,
      textCapitalization: TextCapitalization.words,
      decoration: const InputDecoration(
        labelText: 'Item name in Tamil (தமிழ்)',
        hintText: 'தமிழில் பெயர்',
      ),
    ),
    const SizedBox(height: 12),
    if (_isNew) ...[
      DropdownButtonFormField<String>(
        initialValue: _categoryId,
        decoration: const InputDecoration(labelText: 'Category'),
        items: [
          for (final category in store.assignableCategories)
            DropdownMenuItem(
              value: category.id,
              child: Text(category.displayName(store.settings.language)),
            ),
        ],
        onChanged: (value) =>
            setState(() => _categoryId = value ?? _categoryId),
      ),
      const SizedBox(height: 12),
    ],
    if (_modes.length > 1) ...[
      const Text(
        'Billing type',
        style: TextStyle(fontSize: 14, color: QsColors.muted),
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final mode in _modes)
            ChoiceChip(
              label: Text(switch (mode) {
                LineMode.weight => 'By weight',
                LineMode.amount => 'By amount',
                LineMode.unit => 'Fixed price',
                LineMode.amountOnly => 'Amount only',
              }),
              selected: _mode == mode,
              selectedColor: QsColors.maroon,
              labelStyle: TextStyle(
                color: _mode == mode ? Colors.white : QsColors.charcoal,
              ),
              checkmarkColor: Colors.white,
              onSelected: (_) => setState(() {
                if (mode == LineMode.unit && _units.text.isEmpty)
                  _units.text = '1';
                if (mode == LineMode.amountOnly &&
                    _discountType == LineDiscountType.quantity) {
                  _discountType = LineDiscountType.none;
                }
                _mode = mode;
              }),
            ),
        ],
      ),
      const SizedBox(height: 16),
    ],
  ];

  Widget _rateField({required bool optional}) => NumberField(
    controller: _rate,
    label: optional ? 'Rate per kg (₹, optional)' : 'Rate per kg (₹)',
    prefix: '${fmt.currencySymbol} ',
    enabled: _rateEditable,
    errorText: _rateError,
    helperText: _rateHint(optional),
    onChanged: (_) => setState(() {}),
  );

  String? _rateHint(bool optional) {
    final rate = _rateValue;
    final defaultRate = _defaultRate;
    if (!_rateEditable) return 'Rate changes are disabled for this product';
    if (defaultRate != null && rate != null && rate != defaultRate) {
      return 'Changed for this bill only · default ${fmt.money(defaultRate)}/kg';
    }
    if (optional && _rate.text.isEmpty)
      return 'Without a rate the line is billed as amount only';
    return null;
  }

  List<Widget> _weightFields(AppStore store) {
    final grams = _grams;
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: NumberField(
              controller: _weight,
              label: 'Weight',
              large: true,
              autofocus: _isNew && !_isCustom,
              errorText: _weightError,
              suffix: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  _useKg ? 'kg' : 'g',
                  style: const TextStyle(fontSize: 16, color: QsColors.muted),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 10),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            style: const ButtonStyle(
              minimumSize: WidgetStatePropertyAll(Size(52, 58)),
            ),
            segments: const [
              ButtonSegment(value: false, label: Text('g')),
              ButtonSegment(value: true, label: Text('kg')),
            ],
            selected: {_useKg},
            onSelectionChanged: (selection) => _switchUnit(selection.first),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final preset in store.settings.presetGrams)
            ActionChip(
              label: Text(preset >= 1000 ? fmt.kg(preset) : fmt.grams(preset)),
              onPressed: () => _setPreset(preset),
            ),
        ],
      ),
      if (grams != null && _weightError == null)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            'Equivalent: ${fmt.kg(grams)}  ·  ${fmt.grams(grams)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: QsColors.maroon,
            ),
          ),
        ),
      const SizedBox(height: 16),
      _rateField(optional: false),
    ];
  }

  List<Widget> _amountFields(AppStore store) {
    final estimate = _estimatedGrams;
    return [
      NumberField(
        controller: _amount,
        label: 'Enter amount (₹)',
        prefix: '${fmt.currencySymbol} ',
        large: true,
        autofocus: _isNew && !_isCustom,
        errorText: _amountError,
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 10),
      _quickAmounts(store),
      const SizedBox(height: 16),
      _rateField(optional: true),
      const SizedBox(height: 10),
      Text(
        estimate != null
            ? 'Estimated weight: approx. ${fmt.grams(estimate)}  ·  ${fmt.kg(estimate)}'
            : 'Quantity not specified',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: QsColors.maroon,
        ),
      ),
      const Text(
        'The entered amount is billed exactly; weight is an estimate.',
        style: TextStyle(fontSize: 12, color: QsColors.muted),
      ),
    ];
  }

  Widget _quickAmounts(AppStore store) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final value in store.settings.quickAmounts)
        ActionChip(
          label: Text(fmt.money(value)),
          onPressed: () => setState(
            () => _amount.text = fmt.editable(value, maxDecimals: 2),
          ),
        ),
    ],
  );

  List<Widget> _unitFields() {
    final count = _unitsValue ?? 0;
    return [
      if (_isCustom) ...[
        TextField(
          controller: _unitLabel,
          onChanged: (_) => setState(() {}),
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          decoration: const InputDecoration(
            labelText: 'Unit',
            hintText: 'piece, packet, box, bottle…',
          ),
        ),
        const SizedBox(height: 12),
      ],
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton.filledTonal(
            tooltip: 'Decrease quantity',
            iconSize: 28,
            onPressed: count > 1 ? () => _stepUnits(-1) : null,
            icon: const Icon(Icons.remove),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: NumberField(
              controller: _units,
              label: 'Quantity',
              large: true,
              errorText: _unitsError,
              suffix: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  _product?.unitLabel ?? _unitLabel.text,
                  style: const TextStyle(fontSize: 14, color: QsColors.muted),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filledTonal(
            tooltip: 'Increase quantity',
            iconSize: 28,
            onPressed: () => _stepUnits(1),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      const SizedBox(height: 16),
      NumberField(
        controller: _unitPrice,
        label:
            'Price per ${_product?.unitLabel ?? (_unitLabel.text.isEmpty ? 'unit' : _unitLabel.text)} (₹)',
        prefix: '${fmt.currencySymbol} ',
        enabled: _rateEditable,
        errorText: _unitPriceError,
        helperText:
            _defaultRate != null &&
                _unitPriceValue != null &&
                _unitPriceValue != _defaultRate
            ? 'Changed for this bill only · default ${fmt.money(_defaultRate!)}'
            : (_rateEditable
                  ? null
                  : 'Price changes are disabled for this product'),
        onChanged: (_) => setState(() {}),
      ),
    ];
  }

  List<Widget> _discountFields() {
    final unitLabel =
        _product?.unitLabel ??
        (_unitLabel.text.trim().isEmpty ? 'unit' : _unitLabel.text.trim());
    return [
      const SizedBox(height: 16),
      const Text(
        'Item discount',
        style: TextStyle(fontSize: 14, color: QsColors.muted),
      ),
      const SizedBox(height: 6),
      SegmentedButton<LineDiscountType>(
        showSelectedIcon: false,
        segments: [
          const ButtonSegment(
            value: LineDiscountType.none,
            label: Text('None'),
          ),
          const ButtonSegment(
            value: LineDiscountType.percent,
            label: Text('%'),
          ),
          const ButtonSegment(value: LineDiscountType.fixed, label: Text('₹')),
          if (_mode != LineMode.amountOnly)
            ButtonSegment(
              value: LineDiscountType.quantity,
              label: Text(_mode == LineMode.unit ? 'Minus qty' : 'Minus g'),
            ),
        ],
        selected: {_discountType},
        onSelectionChanged: (selection) =>
            setState(() => _discountType = selection.first),
      ),
      if (_discountType != LineDiscountType.none) ...[
        const SizedBox(height: 12),
        NumberField(
          controller: _discount,
          label: switch (_discountType) {
            LineDiscountType.percent => 'Discount (%)',
            LineDiscountType.fixed => 'Discount (₹)',
            _ =>
              _mode == LineMode.unit
                  ? 'Minus quantity ($unitLabel)'
                  : 'Minus weight (g)',
          },
          errorText: _discountError,
          helperText: _discountType == LineDiscountType.quantity
              ? 'Subtracts this much from the billed amount, at the item rate'
              : null,
          onChanged: (_) => setState(() {}),
        ),
      ],
    ];
  }

  List<Widget> _amountOnlyFields(AppStore store) => [
    NumberField(
      controller: _amount,
      label: 'Amount (₹)',
      prefix: '${fmt.currencySymbol} ',
      large: true,
      autofocus: _isNew && !_isCustom,
      errorText: _amountError,
      onChanged: (_) => setState(() {}),
    ),
    const SizedBox(height: 10),
    _quickAmounts(store),
  ];
}

class _AmountPanel extends StatelessWidget {
  const _AmountPanel({required this.line});

  final BillLine? line;

  @override
  Widget build(BuildContext context) {
    final line = this.line;
    final discounted = line != null && line.discount > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: QsColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (discounted)
            Text(
              'Actual ${fmt.money2(line.amount)} · Discount - ${fmt.money2(line.discount)}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                color: QsColors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
          Row(
            children: [
              Text(
                discounted ? 'After discount' : 'Amount',
                style: const TextStyle(fontSize: 16, color: QsColors.muted),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FittedBox(
                  alignment: Alignment.centerRight,
                  fit: BoxFit.scaleDown,
                  child: Text(
                    line == null ? '—' : fmt.money2(line.netAmount),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: QsColors.maroon,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
