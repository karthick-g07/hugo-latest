import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show ChangeNotifier, visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import 'format.dart' as fmt;
import 'models.dart';
import 'seed.dart';

/// Persistence backend. Files live in the app's private documents folder.
abstract class Storage {
  Future<String?> read();
  Future<void> write(String contents);
  Future<String> saveImage(Uint8List bytes, String extension);
  Future<Uint8List?> readImage(String name);
  File? imageFile(String name);
}

class FileStorage implements Storage {
  late final Directory _root;
  late final Directory _images;

  Future<void> init() async {
    _root = await getApplicationDocumentsDirectory();
    _images = Directory('${_root.path}/images');
    await _images.create(recursive: true);
  }

  File get _dataFile => File('${_root.path}/quality_sweets_data.json');

  @override
  Future<String?> read() async =>
      await _dataFile.exists() ? _dataFile.readAsString() : null;

  @override
  Future<void> write(String contents) async {
    final temp = File('${_dataFile.path}.tmp');
    await temp.writeAsString(contents, flush: true);
    await temp.rename(_dataFile.path);
  }

  @override
  Future<String> saveImage(Uint8List bytes, String extension) async {
    final name = '${newId()}.$extension';
    await File('${_images.path}/$name').writeAsBytes(bytes, flush: true);
    return name;
  }

  @override
  Future<Uint8List?> readImage(String name) async {
    return imageFile(name)?.readAsBytes();
  }

  @override
  File? imageFile(String name) {
    final file = File('${_images.path}/$name');
    return file.existsSync() ? file : null;
  }
}

class MemoryStorage implements Storage {
  String? contents;
  final images = <String, Uint8List>{};

  @override
  Future<String?> read() async => contents;

  @override
  Future<void> write(String value) async => contents = value;

  @override
  Future<String> saveImage(Uint8List bytes, String extension) async {
    final name = '${newId()}.$extension';
    images[name] = bytes;
    return name;
  }

  @override
  Future<Uint8List?> readImage(String name) async => images[name];

  @override
  File? imageFile(String name) => null;
}

enum ProductSort { name, priceLow, priceHigh }

enum BackupKind { setup, bills, full }

class ImportPreview {
  ImportPreview(
    this.categories,
    this.products,
    this.bills,
    this.settings,
    this.images, {
    this.kind = BackupKind.full,
  });

  final List<Category> categories;
  final List<Product> products;
  final List<Bill> bills;
  final ShopSettings? settings;
  final Map<String, String> images;
  final BackupKind kind;
}

class AppStore extends ChangeNotifier {
  AppStore(this.storage);

  static const schemaVersion = 1;

  final Storage storage;
  List<Category> categories = [];
  List<Product> products = [];
  List<Bill> savedBills = [];
  late Bill draft;
  ShopSettings settings = ShopSettings();
  List<String> recentProductIds = [];

  /// True when the draft has changes that are not in a saved bill.
  bool draftDirty = false;
  bool loaded = false;
  Future<void> _pendingWrite = Future.value();

  Future<void> load() async {
    final raw = await storage.read();
    if (raw == null) {
      _resetToDefaults(withSamples: true);
    } else {
      _apply(jsonDecode(raw) as Map<String, dynamic>);
    }
    // Phones that already saved the starter catalog get the new photos
    // without replacing a picture the shop owner chose.
    final catalogImagesChanged = _fillCatalogImages();
    final shopProfileChanged = _fillShopProfile();
    final billTamilNamesChanged = _fillBillTamilNames();
    if (raw == null ||
        catalogImagesChanged ||
        shopProfileChanged ||
        billTamilNamesChanged) {
      await _persist();
    }
    fmt.currencySymbol = settings.currencySymbol;
    loaded = true;
    notifyListeners();
  }

  void _resetToDefaults({required bool withSamples}) {
    categories = defaultCategories();
    products = withSamples ? sampleProducts() : [];
    savedBills = [];
    settings = ShopSettings();
    recentProductIds = [];
    draft = Bill(id: newId());
    draftDirty = false;
  }

  void _apply(Map<String, dynamic> json) {
    List<Map<String, dynamic>> list(String key) => (json[key] as List? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    categories = list('categories').map(Category.fromJson).toList();
    products = list('products').map(Product.fromJson).toList();
    savedBills = list('bills').map(Bill.fromJson).toList();
    settings = json['settings'] is Map
        ? ShopSettings.fromJson(
            Map<String, dynamic>.from(json['settings'] as Map),
          )
        : ShopSettings();
    recentProductIds = (json['recentProductIds'] as List? ?? [])
        .whereType<String>()
        .toList();
    draft = json['draft'] is Map
        ? Bill.fromJson(Map<String, dynamic>.from(json['draft'] as Map))
        : Bill(id: newId());
    draftDirty = json['draftDirty'] as bool? ?? draft.lines.isNotEmpty;
    _ensureSystemCategories();
  }

  bool _fillCatalogImages() {
    var changed = false;
    for (final product in products) {
      final asset = catalogProductImages[product.name];
      if (product.imageName == null && asset != null) {
        product.imageName = asset;
        changed = true;
      }
      final tamilName = catalogProductNamesTamil[product.name];
      if (product.nameTamil.isEmpty && tamilName != null) {
        product.nameTamil = tamilName;
        changed = true;
      }
    }
    for (final category in categories) {
      final asset = catalogCategoryImages[category.id];
      if (category.imageName == null && asset != null) {
        category.imageName = asset;
        changed = true;
      }
      final tamilName = defaultCategories()
          .where((candidate) => candidate.id == category.id)
          .firstOrNull
          ?.nameTamil;
      if (category.nameTamil.isEmpty && tamilName != null) {
        category.nameTamil = tamilName;
        changed = true;
      }
    }
    return changed;
  }

  bool _fillBillTamilNames() {
    var changed = false;
    for (final bill in [...savedBills, draft]) {
      for (var index = 0; index < bill.lines.length; index++) {
        final line = bill.lines[index];
        final tamilName = products
            .where((product) => product.id == line.productId)
            .firstOrNull
            ?.nameTamil;
        if (line.nameTamil.isEmpty &&
            tamilName != null &&
            tamilName.isNotEmpty) {
          bill.lines[index] = BillLine.fromJson({
            ...line.toJson(),
            'nameTamil': tamilName,
          });
          changed = true;
        }
      }
    }
    return changed;
  }

  /// Public listing for Quality Sweets, Valangaiman (Main Road, Kadai Street).
  bool _fillShopProfile() {
    var changed = false;
    if (settings.address.isEmpty ||
        settings.address == 'Valangaiman' ||
        settings.address == 'Main Road, Kadai Street, Valangaiman - 612804') {
      settings.address = 'Kadai Street Main Road, Kadai Street, Valangaiman, Tiruvarur - 612804';
      changed = true;
    }
    if (settings.phone.isEmpty || settings.phone == '94798860055') {
      settings.phone = '9489860055';
      changed = true;
    }
    if (settings.tagline == 'Pure Taste, Sweet Moments') {
      settings.tagline = 'Made with love';
      changed = true;
    }
    if (settings.shopNameTamil.isEmpty) {
      settings.shopNameTamil = 'குவாலிட்டி ஸ்வீட்ஸ்';
      changed = true;
    }
    if (settings.addressTamil.isEmpty) {
      settings.addressTamil = 'கடை வீதி, வலங்கைமான், திருவாரூர் - 612804';
      changed = true;
    }
    if (settings.footerTamil.isEmpty) {
      settings.footerTamil = 'குவாலிட்டி ஸ்வீட்ஸில் வாங்கியதற்கு நன்றி!';
      changed = true;
    }
    return changed;
  }

  void _ensureSystemCategories() {
    for (final kind in [CategoryKind.topRated, CategoryKind.other]) {
      if (!categories.any((category) => category.kind == kind)) {
        categories.add(
          defaultCategories().firstWhere((category) => category.kind == kind)
            ..order = categories.length,
        );
      }
    }
  }

  Map<String, dynamic> _toJson() => {
    'app': 'quality_sweets',
    'schemaVersion': schemaVersion,
    'categories': categories.map((c) => c.toJson()).toList(),
    'products': products.map((p) => p.toJson()).toList(),
    'bills': savedBills.map((b) => b.toJson()).toList(),
    'settings': settings.toJson(),
    'recentProductIds': recentProductIds,
    'draft': draft.toJson(),
    'draftDirty': draftDirty,
  };

  /// Writes are chained so a slow write never overtakes a newer one.
  Future<void> _persist() {
    final contents = jsonEncode(_toJson());
    return _pendingWrite = _pendingWrite.then((_) => storage.write(contents));
  }

  void _changed() {
    notifyListeners();
    _persist();
  }

  // ---------------------------------------------------------------- Catalog

  List<Category> get sortedCategories =>
      [...categories]..sort((a, b) => a.order.compareTo(b.order));

  List<Category> get activeCategories =>
      sortedCategories.where((category) => category.isActive).toList();

  /// Categories a product can belong to (Top Rated is a virtual list).
  List<Category> get assignableCategories => sortedCategories
      .where((category) => category.kind != CategoryKind.topRated)
      .toList();

  Category get otherCategory =>
      categories.firstWhere((c) => c.kind == CategoryKind.other);

  Category? categoryById(String? id) {
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  Product? productById(String? id) {
    for (final product in products) {
      if (product.id == id) return product;
    }
    return null;
  }

  List<Product> productsIn(Category category, {bool activeOnly = true}) =>
      products
          .where(
            (product) =>
                (category.kind == CategoryKind.topRated
                    ? product.isPopular
                    : product.categoryId == category.id) &&
                (!activeOnly ||
                    (product.isActive && _categoryActive(product.categoryId))),
          )
          .toList();

  bool _categoryActive(String id) => categoryById(id)?.isActive ?? true;

  List<Product> get sellableProducts => products
      .where(
        (product) => product.isActive && _categoryActive(product.categoryId),
      )
      .toList();

  /// Sellable products matching the name and every given filter.
  List<Product> search(
    String query, {
    String? categoryId,
    ProductMode? mode,
    bool popularOnly = false,
    ProductSort sort = ProductSort.name,
  }) {
    final needle = query.trim().toLowerCase();
    return sellableProducts
        .where(
          (p) =>
              p.name.toLowerCase().contains(needle) &&
              (categoryId == null || p.categoryId == categoryId) &&
              (mode == null || p.mode == mode) &&
              (!popularOnly || p.isPopular),
        )
        .toList()
      ..sort(switch (sort) {
        ProductSort.name => (a, b) => a.name.compareTo(b.name),
        ProductSort.priceLow => (a, b) => a.defaultRate.compareTo(
          b.defaultRate,
        ),
        ProductSort.priceHigh => (a, b) => b.defaultRate.compareTo(
          a.defaultRate,
        ),
      });
  }

  List<Product> get popularProducts =>
      sellableProducts.where((p) => p.isPopular).toList();

  List<Product> get recentProducts => recentProductIds
      .map(productById)
      .whereType<Product>()
      .where((product) => product.isActive)
      .toList();

  void upsertProduct(Product product) {
    product.updatedAt = DateTime.now();
    final index = products.indexWhere((p) => p.id == product.id);
    index < 0 ? products.add(product) : products[index] = product;
    _changed();
  }

  void deleteProduct(Product product) {
    products.removeWhere((p) => p.id == product.id);
    recentProductIds.remove(product.id);
    _changed();
  }

  void setProductActive(Product product, bool active) {
    product
      ..isActive = active
      ..updatedAt = DateTime.now();
    _changed();
  }

  void upsertCategory(Category category) {
    final index = categories.indexWhere((c) => c.id == category.id);
    if (index < 0) {
      category.order = categories.length;
      categories.add(category);
    } else {
      categories[index] = category;
    }
    _changed();
  }

  void setCategoryActive(Category category, bool active) {
    category.isActive = active;
    _changed();
  }

  /// [newIndex] is the final position after the item is removed.
  void reorderCategories(int oldIndex, int newIndex) {
    final ordered = sortedCategories;
    ordered.insert(newIndex, ordered.removeAt(oldIndex));
    for (var i = 0; i < ordered.length; i++) {
      ordered[i].order = i;
    }
    _changed();
  }

  /// Deletes a category after moving its products to [moveTo].
  void deleteCategory(Category category, Category moveTo) {
    if (category.isSystem) return;
    for (final product in products.where((p) => p.categoryId == category.id)) {
      product.categoryId = moveTo.id;
    }
    categories.remove(category);
    _changed();
  }

  // ---------------------------------------------------------------- Images

  Future<String> saveImage(Uint8List bytes, String extension) =>
      storage.saveImage(bytes, extension);

  File? imageFile(String? name) =>
      name == null ? null : storage.imageFile(name);

  // ---------------------------------------------------------------- Draft

  void addLine(BillLine line) {
    draft.lines.add(line);
    if (line.productId != null) {
      recentProductIds
        ..remove(line.productId)
        ..insert(0, line.productId!);
      if (recentProductIds.length > 8) recentProductIds.removeLast();
    }
    _draftChanged();
  }

  void updateLine(BillLine line) {
    final index = draft.lines.indexWhere((l) => l.id == line.id);
    if (index < 0) return;
    draft.lines[index] = line;
    _draftChanged();
  }

  int removeLine(BillLine line) {
    final index = draft.lines.indexWhere((l) => l.id == line.id);
    if (index >= 0) draft.lines.removeAt(index);
    _draftChanged();
    return index;
  }

  void restoreLine(BillLine line, int index) {
    draft.lines.insert(index.clamp(0, draft.lines.length), line);
    _draftChanged();
  }

  void updateDraft(void Function(Bill bill) change) {
    change(draft);
    _draftChanged();
  }

  void _draftChanged() {
    draft.updatedAt = DateTime.now();
    draftDirty = true;
    _changed();
  }

  /// Anything already in the billing area must be saved or deleted first.
  bool get draftNeedsProtection => draft.lines.isNotEmpty;

  Bill? get draftSource =>
      draft.sourceBillId == null ? null : billById(draft.sourceBillId!);

  void startNewDraft() {
    draft = Bill(id: newId());
    draftDirty = false;
    _syncDraftWithSettings();
    _changed();
  }

  /// Applies the configured tax and turns off disabled bill options.
  void _syncDraftWithSettings() {
    draft
      ..taxName = settings.hasTax ? settings.taxName.trim() : null
      ..taxPercent = settings.hasTax ? settings.taxPercent : 0;
    if (!settings.paymentEnabled) draft.paymentMethod = null;
    draft.shopPhone ??= settings.phone;
    draft.gpayQrName ??= settings.gpayQrName;
  }

  String suggestedBillName([DateTime? when]) {
    final day = when ?? DateTime.now();
    final sameDay = savedBills.where(
      (bill) =>
          bill.createdAt.year == day.year &&
          bill.createdAt.month == day.month &&
          bill.createdAt.day == day.day,
    );
    return 'Bill - ${fmt.date(day)} - ${(sameDay.length + 1).toString().padLeft(2, '0')}';
  }

  /// Saves the draft. With [overwrite], replaces the saved bill it was
  /// resumed from; otherwise creates a new saved bill with a new number.
  Bill saveDraft({required String name, bool overwrite = false}) {
    final source = overwrite ? draftSource : null;
    final saved = draft.copy(id: source?.id ?? newId(), isSaved: true)
      ..name = name.trim().isEmpty ? suggestedBillName() : name.trim()
      ..sourceBillId = null
      ..updatedAt = DateTime.now();
    if (source != null) {
      saved
        ..number = source.number
        ..displayNumber = source.displayNumber
        ..createdAt = source.createdAt;
      savedBills[savedBills.indexOf(source)] = saved;
    } else {
      saved
        ..number = settings.nextBillNumber
        ..displayNumber =
            '${settings.invoicePrefix}${settings.nextBillNumber.toString().padLeft(4, '0')}'
        ..createdAt = DateTime.now();
      settings.nextBillNumber++;
      savedBills.add(saved);
    }
    // A saved bill lives only in Saved Bills; billing starts fresh.
    draft = Bill(id: newId());
    draftDirty = false;
    _syncDraftWithSettings();
    _changed();
    return saved;
  }

  void setPaymentDone(Bill bill, bool done) {
    bill.paymentDone = done;
    bill.updatedAt = DateTime.now();
    final index = savedBills.indexWhere((saved) => saved.id == bill.id);
    if (index >= 0) savedBills[index] = bill;
    if (draft.id == bill.id) draft = bill;
    _changed();
  }

  Bill? billById(String id) {
    for (final bill in savedBills) {
      if (bill.id == id) return bill;
    }
    return null;
  }

  /// Loads a saved bill into the draft for editing; the saved copy is untouched.
  void resumeBill(Bill bill) {
    draft = bill.copy(id: newId(), isSaved: false)..sourceBillId = bill.id;
    draftDirty = false;
    _changed();
  }

  /// Starts a new draft with the same items as a saved bill.
  void duplicateBill(Bill bill) {
    draft = bill.copy(id: newId(), isSaved: false)
      ..name = null
      ..number = null
      ..displayNumber = null
      ..sourceBillId = null
      ..createdAt = DateTime.now();
    draftDirty = true;
    _changed();
  }

  void deleteBill(Bill bill) {
    savedBills.removeWhere((b) => b.id == bill.id);
    if (draft.sourceBillId == bill.id) draft.sourceBillId = null;
    _changed();
  }

  // ---------------------------------------------------------------- Settings

  void updateSettings(void Function(ShopSettings settings) change) {
    change(settings);
    fmt.currencySymbol = settings.currencySymbol;
    _syncDraftWithSettings();
    _changed();
  }

  // ---------------------------------------------------------------- Summary

  List<Bill> billsOn(DateTime day) => savedBills
      .where(
        (bill) =>
            bill.createdAt.year == day.year &&
            bill.createdAt.month == day.month &&
            bill.createdAt.day == day.day,
      )
      .toList();

  /// Saved bills matching the search text and every given filter.
  /// [from] is inclusive and [to] is exclusive.
  List<Bill> findBills({
    String query = '',
    DateTime? from,
    DateTime? to,
    String? paymentMethod,
    bool discountedOnly = false,
    bool withCustomerOnly = false,
  }) {
    final needle = query.trim().toLowerCase();
    return savedBills
        .where(
          (bill) =>
              (needle.isEmpty ||
                  (bill.name ?? '').toLowerCase().contains(needle) ||
                  (bill.displayNumber ?? '').toLowerCase().contains(needle) ||
                  (bill.customerName ?? '').toLowerCase().contains(needle) ||
                  (bill.customerPhone ?? '').contains(needle) ||
                  bill.lines.any(
                    (line) => line.name.toLowerCase().contains(needle),
                  )) &&
              (from == null || !bill.createdAt.isBefore(from)) &&
              (to == null || bill.createdAt.isBefore(to)) &&
              (paymentMethod == null || bill.paymentMethod == paymentMethod) &&
              (!discountedOnly || bill.totalDiscount > 0) &&
              (!withCustomerOnly ||
                  bill.customerName?.trim().isNotEmpty == true ||
                  bill.customerPhone?.trim().isNotEmpty == true),
        )
        .toList();
  }

  /// Products ordered by how many saved bill lines reference them.
  List<MapEntry<String, int>> frequentlyBilled({int limit = 5}) {
    final counts = <String, int>{};
    for (final bill in savedBills) {
      for (final line in bill.lines) {
        counts[line.name] = (counts[line.name] ?? 0) + 1;
      }
    }
    return (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
        .take(limit)
        .toList();
  }

  // ---------------------------------------------------------------- Backup

  Future<String> exportBackup({BackupKind kind = BackupKind.full}) async {
    settings.lastBackupAt = DateTime.now();
    _changed();
    final common = {
      'app': 'quality_sweets',
      'schemaVersion': schemaVersion,
      'backupType': kind.name,
      'exportedAt': DateTime.now().toIso8601String(),
      'images': <String, String>{},
    };
    final payload = switch (kind) {
      BackupKind.setup => {
        ..._toJson(),
        ...common,
        'bills': <dynamic>[],
        'draft': Bill(id: newId()).toJson(),
        'draftDirty': false,
      },
      BackupKind.bills => {
        ...common,
        'bills': savedBills.map((bill) => bill.toJson()).toList(),
      },
      BackupKind.full => {..._toJson(), ...common},
    };
    return const JsonEncoder.withIndent(' ').convert(payload);
  }

  Future<Uint8List> exportImageArchive({
    BackupKind kind = BackupKind.full,
  }) async {
    final names =
        {
          if (kind != BackupKind.bills) ...categories.map((c) => c.imageName),
          if (kind != BackupKind.bills) ...products.map((p) => p.imageName),
          if (kind != BackupKind.bills) settings.logoName,
          if (kind != BackupKind.bills) settings.gpayQrName,
          if (kind != BackupKind.bills) draft.gpayQrName,
          if (kind != BackupKind.setup)
            ...savedBills.map((bill) => bill.gpayQrName),
        }.whereType<String>().where(
          (name) => name.isNotEmpty && !name.startsWith('asset:'),
        );
    final archive = Archive();
    for (final name in names) {
      final bytes = name.startsWith('asset:')
          ? await _loadBundledImage(name.substring('asset:'.length))
          : await storage.readImage(name);
      if (bytes != null) {
        final archiveName = name.startsWith('asset:')
            ? name.substring('asset:'.length)
            : name;
        archive.addFile(ArchiveFile(archiveName, bytes.length, bytes));
      }
    }
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  Future<Uint8List> _loadBundledImage(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  Map<String, String> decodeImageArchive(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    return {
      for (final file in archive.files)
        if (file.isFile &&
            (file.name.split('/').length == 1 ||
                file.name.startsWith('assets/')))
          (file.name.startsWith('assets/') ? 'asset:${file.name}' : file.name):
              base64Encode(file.content as List<int>),
    };
  }

  /// Validates a backup file. Throws [FormatException] when it is not one.
  ImportPreview previewImport(String raw) {
    final Object? parsed;
    try {
      parsed = jsonDecode(raw);
    } on FormatException {
      throw const FormatException('This file is not valid JSON.');
    }
    if (parsed is! Map || parsed['app'] != 'quality_sweets') {
      throw const FormatException('This is not a Quality Sweets backup file.');
    }
    final decoded = parsed;
    try {
      List<Map<String, dynamic>> list(String key) =>
          (decoded[key] as List? ?? [])
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
      return ImportPreview(
        list('categories').map(Category.fromJson).toList(),
        list('products').map(Product.fromJson).toList(),
        list('bills').map(Bill.fromJson).toList(),
        decoded['settings'] is Map
            ? ShopSettings.fromJson(
                Map<String, dynamic>.from(decoded['settings'] as Map),
              )
            : null,
        Map<String, String>.from(decoded['images'] as Map? ?? {}),
        kind: BackupKind.values.firstWhere(
          (kind) => kind.name == decoded['backupType'],
          orElse: () => BackupKind.full,
        ),
      );
    } catch (_) {
      throw const FormatException('The backup file is damaged or incomplete.');
    }
  }

  /// Replace swaps all data; merge only adds records whose IDs are new.
  Future<void> applyImport(
    ImportPreview preview, {
    required bool replace,
  }) async {
    for (final entry in preview.images.entries) {
      final extension = entry.key.split('.').last;
      final saved = await storage.saveImage(
        base64Decode(entry.value),
        extension,
      );
      _renameImage(preview, entry.key, saved);
    }
    if (preview.kind == BackupKind.setup) {
      if (replace) {
        categories = preview.categories;
        products = preview.products;
        recentProductIds = [];
      } else {
        bool isNew(String id, Iterable<String> ids) => !ids.contains(id);
        categories.addAll(
          preview.categories.where(
            (c) => !c.isSystem && isNew(c.id, categories.map((e) => e.id)),
          ),
        );
        products.addAll(
          preview.products.where((p) => isNew(p.id, products.map((e) => e.id))),
        );
      }
      if (preview.settings != null) settings = preview.settings!;
      for (final product in products) {
        if (categoryById(product.categoryId) == null) {
          product.categoryId = otherCategory.id;
        }
      }
      if (draft.lines.isEmpty) _syncDraftWithSettings();
    } else if (preview.kind == BackupKind.bills) {
      if (replace) {
        savedBills = preview.bills;
      } else {
        savedBills.addAll(
          preview.bills.where(
            (bill) => !savedBills.any((saved) => saved.id == bill.id),
          ),
        );
      }
    } else if (replace) {
      categories = preview.categories;
      products = preview.products;
      savedBills = preview.bills;
      settings = preview.settings ?? ShopSettings();
      recentProductIds = [];
      draft = Bill(id: newId());
      draftDirty = false;
    } else {
      bool isNew(String id, Iterable<String> ids) => !ids.contains(id);
      categories.addAll(
        preview.categories.where(
          (c) => !c.isSystem && isNew(c.id, categories.map((e) => e.id)),
        ),
      );
      products.addAll(
        preview.products.where((p) => isNew(p.id, products.map((e) => e.id))),
      );
      savedBills.addAll(
        preview.bills.where((b) => isNew(b.id, savedBills.map((e) => e.id))),
      );
      for (final product in products) {
        if (categoryById(product.categoryId) == null) {
          product.categoryId = otherCategory.id;
        }
      }
      final highest = savedBills.fold<int>(
        0,
        (max, b) => (b.number ?? 0) > max ? b.number! : max,
      );
      if (settings.nextBillNumber <= highest) {
        settings.nextBillNumber = highest + 1;
      }
    }
    final highestBillNumber = savedBills.fold<int>(
      0,
      (max, bill) => (bill.number ?? 0) > max ? bill.number! : max,
    );
    if (settings.nextBillNumber <= highestBillNumber) {
      settings.nextBillNumber = highestBillNumber + 1;
    }
    _ensureSystemCategories();
    fmt.currencySymbol = settings.currencySymbol;
    _changed();
  }

  void _renameImage(ImportPreview preview, String from, String to) {
    for (final category in preview.categories.where(
      (c) => c.imageName == from,
    )) {
      category.imageName = to;
    }
    for (final product in preview.products.where((p) => p.imageName == from)) {
      product.imageName = to;
    }
    if (preview.settings?.logoName == from) preview.settings!.logoName = to;
    if (preview.settings?.gpayQrName == from) preview.settings!.gpayQrName = to;
    for (final bill in preview.bills.where((bill) => bill.gpayQrName == from)) {
      bill.gpayQrName = to;
    }
  }

  /// Removes every product, bill and setting, keeping the default categories.
  void clearAllData() {
    _resetToDefaults(withSamples: false);
    fmt.currencySymbol = settings.currencySymbol;
    _changed();
  }

  @visibleForTesting
  Future<void> flush() => _pendingWrite;
}
