import 'dart:math';

/// How a catalog product is sold.
enum ProductMode { weight, unit, amountOnly }

/// How a single bill line was entered. `amount` is a weight product billed
/// by rupee amount, where the entered amount is the source of truth.
enum LineMode { weight, amount, unit, amountOnly }

enum CategoryKind { normal, other, topRated }

enum DiscountType { none, fixed, percent }

/// Per-item discount: a percentage, a rupee amount, or free quantity
/// (grams for weight items, units for fixed-price items).
enum LineDiscountType { none, percent, fixed, quantity }

final _random = Random();

String newId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_random.nextInt(1 << 32).toRadixString(36)}';

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) =>
    values.firstWhere((v) => v.name == name, orElse: () => fallback);

double? _toDouble(Object? value) => value is num ? value.toDouble() : null;

DateTime _toDate(Object? value) =>
    DateTime.tryParse(value as String? ?? '') ?? DateTime.now();

/// Rounds a currency value to paise.
double roundMoney(double value) => (value * 100).roundToDouble() / 100;

class Category {
  Category({
    required this.id,
    required this.name,
    this.nameTamil = '',
    this.imageName,
    this.order = 0,
    this.isActive = true,
    this.kind = CategoryKind.normal,
  });

  final String id;
  String name;
  String nameTamil;
  String? imageName;
  int order;
  bool isActive;
  CategoryKind kind;

  bool get isSystem => kind != CategoryKind.normal;
  String displayName(String language) =>
      language == 'ta' && nameTamil.trim().isNotEmpty ? nameTamil : name;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'nameTamil': nameTamil,
    'imageName': imageName,
    'order': order,
    'isActive': isActive,
    'kind': kind.name,
  };

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: json['id'] as String,
    name: json['name'] as String? ?? 'Category',
    nameTamil: json['nameTamil'] as String? ?? '',
    imageName: json['imageName'] as String?,
    order: (json['order'] as num?)?.toInt() ?? 0,
    isActive: json['isActive'] as bool? ?? true,
    kind: _enumByName(CategoryKind.values, json['kind'], CategoryKind.normal),
  );
}

class Product {
  Product({
    required this.id,
    required this.name,
    this.nameTamil = '',
    required this.categoryId,
    this.imageName,
    this.mode = ProductMode.weight,
    this.ratePerKg = 0,
    this.unitLabel = 'piece',
    this.unitPrice = 0,
    this.preferKg = false,
    this.allowRateOverride = true,
    this.isPopular = false,
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String name;
  String nameTamil;
  String categoryId;
  String? imageName;
  ProductMode mode;
  double ratePerKg;
  String unitLabel;
  double unitPrice;
  bool preferKg;
  bool allowRateOverride;
  bool isPopular;
  bool isActive;
  final DateTime createdAt;
  DateTime updatedAt;

  /// Default price for the product's unit (per kg or per unit).
  double get defaultRate => mode == ProductMode.unit ? unitPrice : ratePerKg;
  String displayName(String language) =>
      language == 'ta' && nameTamil.trim().isNotEmpty ? nameTamil : name;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'nameTamil': nameTamil,
    'categoryId': categoryId,
    'imageName': imageName,
    'mode': mode.name,
    'ratePerKg': ratePerKg,
    'unitLabel': unitLabel,
    'unitPrice': unitPrice,
    'preferKg': preferKg,
    'allowRateOverride': allowRateOverride,
    'isPopular': isPopular,
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'] as String,
    name: json['name'] as String? ?? 'Item',
    nameTamil: json['nameTamil'] as String? ?? '',
    categoryId: json['categoryId'] as String? ?? '',
    imageName: json['imageName'] as String?,
    mode: _enumByName(ProductMode.values, json['mode'], ProductMode.weight),
    ratePerKg: _toDouble(json['ratePerKg']) ?? 0,
    unitLabel: json['unitLabel'] as String? ?? 'piece',
    unitPrice: _toDouble(json['unitPrice']) ?? 0,
    preferKg: json['preferKg'] as bool? ?? false,
    allowRateOverride: json['allowRateOverride'] as bool? ?? true,
    isPopular: json['isPopular'] as bool? ?? false,
    isActive: json['isActive'] as bool? ?? true,
    createdAt: _toDate(json['createdAt']),
    updatedAt: _toDate(json['updatedAt']),
  );
}

/// Immutable snapshot of an item on a bill. Later catalog edits never change it.
class BillLine {
  const BillLine({
    required this.id,
    required this.name,
    this.nameTamil = '',
    required this.mode,
    required this.amount,
    this.productId,
    this.categoryId,
    this.grams,
    this.units,
    this.unitLabel,
    this.enteredAmount,
    this.defaultRate,
    this.appliedRate,
    this.note,
    this.discountType = LineDiscountType.none,
    this.discountValue = 0,
  });

  final String id;
  final String? productId;
  final String? categoryId;
  final String name;
  final String nameTamil;
  final LineMode mode;

  /// Weight in grams; for `amount` lines this is a derived estimate.
  final double? grams;
  final double? units;
  final String? unitLabel;
  final double? enteredAmount;
  final double? defaultRate;

  /// Rate per kg for weight lines, price per unit for unit lines.
  final double? appliedRate;

  /// Actual amount before this item's discount.
  final double amount;
  final String? note;
  final LineDiscountType discountType;

  /// Percent, rupees, or free grams/units depending on [discountType].
  final double discountValue;

  bool get rateOverridden =>
      appliedRate != null && defaultRate != null && appliedRate != defaultRate;

  String displayName(String language) =>
      language == 'ta' && nameTamil.trim().isNotEmpty ? nameTamil : name;

  /// Free quantity is only possible when the line has a usable rate.
  bool get allowsQuantityDiscount =>
      mode != LineMode.amountOnly && (appliedRate ?? 0) > 0;

  double get discount {
    final rate = appliedRate ?? 0;
    final value = switch (discountType) {
      LineDiscountType.none => 0.0,
      LineDiscountType.percent => amount * discountValue / 100,
      LineDiscountType.fixed => discountValue,
      LineDiscountType.quantity =>
        !allowsQuantityDiscount
            ? 0.0
            : mode == LineMode.unit
            ? discountValue * rate
            : discountValue / 1000 * rate,
    };
    return roundMoney(value.clamp(0, amount).toDouble());
  }

  /// Amount after this item's discount.
  double get netAmount => roundMoney(amount - discount);

  Map<String, dynamic> toJson() => {
    'id': id,
    'productId': productId,
    'categoryId': categoryId,
    'name': name,
    'nameTamil': nameTamil,
    'mode': mode.name,
    'grams': grams,
    'units': units,
    'unitLabel': unitLabel,
    'enteredAmount': enteredAmount,
    'defaultRate': defaultRate,
    'appliedRate': appliedRate,
    'amount': amount,
    'note': note,
    'discountType': discountType.name,
    'discountValue': discountValue,
  };

  factory BillLine.fromJson(Map<String, dynamic> json) => BillLine(
    id: json['id'] as String? ?? newId(),
    productId: json['productId'] as String?,
    categoryId: json['categoryId'] as String?,
    name: json['name'] as String? ?? 'Item',
    nameTamil: json['nameTamil'] as String? ?? '',
    mode: _enumByName(LineMode.values, json['mode'], LineMode.amountOnly),
    grams: _toDouble(json['grams']),
    units: _toDouble(json['units']),
    unitLabel: json['unitLabel'] as String?,
    enteredAmount: _toDouble(json['enteredAmount']),
    defaultRate: _toDouble(json['defaultRate']),
    appliedRate: _toDouble(json['appliedRate']),
    amount: _toDouble(json['amount']) ?? 0,
    note: json['note'] as String?,
    discountType: _enumByName(
      LineDiscountType.values,
      json['discountType'],
      LineDiscountType.none,
    ),
    discountValue: _toDouble(json['discountValue']) ?? 0,
  );
}

class Bill {
  Bill({
    required this.id,
    this.number,
    this.displayNumber,
    this.name,
    this.isSaved = false,
    this.sourceBillId,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.customerName,
    this.customerPhone,
    this.notes,
    List<BillLine>? lines,
    this.discountType = DiscountType.none,
    this.discountValue = 0,
    this.taxName,
    this.taxPercent = 0,
    this.paymentMethod,
    this.advanceAmount,
    this.paymentDone = false,
    this.payOnlineEnabled = false,
    this.shopPhone,
    this.gpayQrName,
  }) : lines = lines ?? [],
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  final String id;
  int? number;
  String? displayNumber;
  String? name;
  bool isSaved;

  /// For a draft resumed from a saved bill: the saved bill it came from.
  String? sourceBillId;
  DateTime createdAt;
  DateTime updatedAt;
  String? customerName;
  String? customerPhone;
  String? notes;
  final List<BillLine> lines;
  DiscountType discountType;
  double discountValue;

  /// Tax is only stored when the shop owner has configured it.
  String? taxName;
  double taxPercent;
  String? paymentMethod;
  double? advanceAmount;
  bool paymentDone;
  bool payOnlineEnabled;
  double get balanceDue => roundMoney(
    (grandTotal - (advanceAmount ?? 0)).clamp(0, grandTotal).toDouble(),
  );

  /// Shop phone printed on this bill. Null inherits the current shop setting.
  String? shopPhone;

  /// GPay / UPI QR for this bill. Null inherits the shop QR; empty means none.
  String? gpayQrName;

  bool get isEmpty => lines.isEmpty;

  /// Phone shown on this invoice.
  String shopPhoneFor(ShopSettings shop) => (shopPhone ?? shop.phone).trim();

  /// QR image to print, or null when Pay online is off for this bill.
  String? gpayQrFor(ShopSettings shop) {
    if (!payOnlineEnabled) return null;
    final name = gpayQrName ?? shop.gpayQrName;
    return name == null || name.isEmpty ? null : name;
  }

  static double _sum(Iterable<double> values) =>
      values.fold<int>(0, (sum, value) => sum + (value * 100).round()) / 100;

  /// Actual amount of all items before any discount.
  double get itemsTotal => _sum(lines.map((line) => line.amount));

  double get itemDiscount => _sum(lines.map((line) => line.discount));

  /// Items total after per-item discounts; the whole-bill discount applies to this.
  double get subtotal => _sum(lines.map((line) => line.netAmount));

  /// Whole-bill discount.
  double get discountAmount {
    final value = switch (discountType) {
      DiscountType.none => 0.0,
      DiscountType.fixed => discountValue,
      DiscountType.percent => subtotal * discountValue / 100,
    };
    return roundMoney(value.clamp(0, subtotal).toDouble());
  }

  double get totalDiscount => roundMoney(itemDiscount + discountAmount);

  double get afterDiscount => roundMoney(subtotal - discountAmount);

  double get taxAmount =>
      taxName == null ? 0 : roundMoney(afterDiscount * taxPercent / 100);

  double get grandTotal => roundMoney(afterDiscount + taxAmount);

  Bill copy({String? id, bool? isSaved}) => Bill.fromJson({
    ...toJson(),
    'id': id ?? this.id,
    'isSaved': isSaved ?? this.isSaved,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'number': number,
    'displayNumber': displayNumber,
    'name': name,
    'status': isSaved ? 'saved' : 'draft',
    'isSaved': isSaved,
    'sourceBillId': sourceBillId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'customerName': customerName,
    'customerPhone': customerPhone,
    'notes': notes,
    'lines': lines.map((line) => line.toJson()).toList(),
    'discountType': discountType.name,
    'discountValue': discountValue,
    'taxName': taxName,
    'taxPercent': taxPercent,
    'paymentMethod': paymentMethod,
    'advanceAmount': advanceAmount,
    'paymentDone': paymentDone,
    'payOnlineEnabled': payOnlineEnabled,
    'shopPhone': shopPhone,
    'gpayQrName': gpayQrName,
    'itemsTotal': itemsTotal,
    'itemDiscount': itemDiscount,
    'subtotal': subtotal,
    'discount': discountAmount,
    'tax': taxAmount,
    'grandTotal': grandTotal,
  };

  factory Bill.fromJson(Map<String, dynamic> json) => Bill(
    id: json['id'] as String? ?? newId(),
    number: (json['number'] as num?)?.toInt(),
    displayNumber: json['displayNumber'] as String?,
    name: json['name'] as String?,
    isSaved: json['isSaved'] as bool? ?? json['status'] == 'saved',
    sourceBillId: json['sourceBillId'] as String?,
    createdAt: _toDate(json['createdAt']),
    updatedAt: _toDate(json['updatedAt']),
    customerName: json['customerName'] as String?,
    customerPhone: json['customerPhone'] as String?,
    notes: json['notes'] as String?,
    lines: (json['lines'] as List? ?? [])
        .map(
          (line) => BillLine.fromJson(Map<String, dynamic>.from(line as Map)),
        )
        .toList(),
    discountType: _enumByName(
      DiscountType.values,
      json['discountType'],
      DiscountType.none,
    ),
    discountValue: _toDouble(json['discountValue']) ?? 0,
    taxName: json['taxName'] as String?,
    taxPercent: _toDouble(json['taxPercent']) ?? 0,
    paymentMethod: json['paymentMethod'] as String?,
    advanceAmount: _toDouble(json['advanceAmount']),
    paymentDone: json['paymentDone'] as bool? ?? false,
    payOnlineEnabled: json['payOnlineEnabled'] as bool? ?? false,
    shopPhone: json['shopPhone'] as String?,
    gpayQrName: json['gpayQrName'] as String?,
  );
}

class ShopSettings {
  ShopSettings({
    this.shopName = 'Quality Sweets',
    this.shopNameTamil = '',
    this.tagline = 'Made with love',
    this.taglineTamil = '',
    this.logoName,
    this.gpayQrName,
    this.address =
        'Kadai Street Main Road, Kadai Street, Valangaiman, Tiruvarur - 612804',
    this.addressTamil = '',
    this.phone = '9489860055',
    this.footer = 'Thank you for shopping with Quality Sweets!',
    this.footerTamil = '',
    this.language = 'en',
    this.currencySymbol = '₹',
    this.invoicePrefix = 'QS',
    this.nextBillNumber = 1,
    this.discountEnabled = true,
    this.customerDetailsEnabled = true,
    this.paymentEnabled = false,
    List<String>? paymentMethods,
    this.taxEnabled = false,
    this.taxName = '',
    this.taxPercent = 0,
    this.taxNumber = '',
    List<double>? presetGrams,
    List<double>? quickAmounts,
    this.lastBackupAt,
    List<String>? ownerWhatsAppNumbers,
    this.notifyOwnerOnShare = true,
  }) : paymentMethods = paymentMethods ?? ['Cash', 'UPI', 'Card', 'Unpaid'],
       presetGrams = presetGrams ?? [100, 250, 500, 1000, 2000],
       quickAmounts = quickAmounts ?? [50, 100, 200, 500],
       ownerWhatsAppNumbers = ownerWhatsAppNumbers ?? [];

  String shopName;
  String shopNameTamil;
  String tagline;
  String taglineTamil;
  String? logoName;
  String? gpayQrName;
  String address;
  String addressTamil;
  String phone;
  String footer;
  String footerTamil;

  /// App-wide UI language: `en` or `ta`.
  String language;
  String currencySymbol;
  String invoicePrefix;
  int nextBillNumber;
  bool discountEnabled;
  bool customerDetailsEnabled;
  bool paymentEnabled;
  List<String> paymentMethods;
  bool taxEnabled;
  String taxName;
  double taxPercent;
  String taxNumber;
  List<double> presetGrams;
  List<double> quickAmounts;
  DateTime? lastBackupAt;

  /// Normalised digits-with-country-code, e.g. "919876543210".
  List<String> ownerWhatsAppNumbers;

  /// When sharing a bill via WhatsApp, also offer to send it to the owner numbers above.
  bool notifyOwnerOnShare;

  bool get hasTax => taxEnabled && taxName.trim().isNotEmpty && taxPercent > 0;

  Map<String, dynamic> toJson() => {
    'shopName': shopName,
    'shopNameTamil': shopNameTamil,
    'tagline': tagline,
    'taglineTamil': taglineTamil,
    'logoName': logoName,
    'gpayQrName': gpayQrName,
    'address': address,
    'addressTamil': addressTamil,
    'phone': phone,
    'footer': footer,
    'footerTamil': footerTamil,
    'language': language,
    'currencySymbol': currencySymbol,
    'invoicePrefix': invoicePrefix,
    'nextBillNumber': nextBillNumber,
    'discountEnabled': discountEnabled,
    'customerDetailsEnabled': customerDetailsEnabled,
    'paymentEnabled': paymentEnabled,
    'paymentMethods': paymentMethods,
    'taxEnabled': taxEnabled,
    'taxName': taxName,
    'taxPercent': taxPercent,
    'taxNumber': taxNumber,
    'presetGrams': presetGrams,
    'quickAmounts': quickAmounts,
    'lastBackupAt': lastBackupAt?.toIso8601String(),
    'ownerWhatsAppNumbers': ownerWhatsAppNumbers,
    'notifyOwnerOnShare': notifyOwnerOnShare,
  };

  factory ShopSettings.fromJson(Map<String, dynamic> json) {
    List<double>? numbers(Object? value) =>
        (value as List?)?.whereType<num>().map((n) => n.toDouble()).toList();
    return ShopSettings(
      shopName: json['shopName'] as String? ?? 'Quality Sweets',
      shopNameTamil: json['shopNameTamil'] as String? ?? '',
      tagline: json['tagline'] as String? ?? 'Made with love',
      taglineTamil: json['taglineTamil'] as String? ?? '',
      logoName: json['logoName'] as String?,
      gpayQrName: json['gpayQrName'] as String?,
      address: json['address'] as String? ?? 'Kadai Street Main Road, Kadai Street, Valangaiman, Tiruvarur - 612804',
      addressTamil: json['addressTamil'] as String? ?? '',
      phone: json['phone'] as String? ?? '9489860055',
      footer:
          json['footer'] as String? ??
          'Thank you for shopping with Quality Sweets!',
      footerTamil: json['footerTamil'] as String? ?? '',
      language: json['language'] as String? ?? 'en',
      currencySymbol: json['currencySymbol'] as String? ?? '₹',
      invoicePrefix: json['invoicePrefix'] as String? ?? 'QS',
      nextBillNumber: (json['nextBillNumber'] as num?)?.toInt() ?? 1,
      discountEnabled: json['discountEnabled'] as bool? ?? true,
      customerDetailsEnabled: json['customerDetailsEnabled'] as bool? ?? true,
      paymentEnabled: json['paymentEnabled'] as bool? ?? false,
      paymentMethods: (json['paymentMethods'] as List?)
          ?.whereType<String>()
          .toList(),
      taxEnabled: json['taxEnabled'] as bool? ?? false,
      taxName: json['taxName'] as String? ?? '',
      taxPercent: _toDouble(json['taxPercent']) ?? 0,
      taxNumber: json['taxNumber'] as String? ?? '',
      presetGrams: numbers(json['presetGrams']),
      quickAmounts: numbers(json['quickAmounts']),
      lastBackupAt: DateTime.tryParse(json['lastBackupAt'] as String? ?? ''),
      ownerWhatsAppNumbers: (json['ownerWhatsAppNumbers'] as List?)
          ?.whereType<String>()
          .toList(),
      notifyOwnerOnShare: json['notifyOwnerOnShare'] as bool? ?? true,
    );
  }
}
