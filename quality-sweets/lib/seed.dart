import 'models.dart';

/// Bundled catalog photos. The `asset:` prefix tells the UI to load a
/// Flutter asset instead of a photo saved on the device.
const catalogProductImages = {
  'Mysore Pak': 'asset:assets/products/mysore_pak.jpg',
  'Jangiri': 'asset:assets/products/jangiri.jpg',
  'Boondi Laddu': 'asset:assets/products/boondi_laddu.jpg',
  'Milk Peda': 'asset:assets/products/milk_peda.jpg',
  'Gulab Jamun': 'asset:assets/products/gulab_jamun.jpg',
  'Ghee Mysore Pak': 'asset:assets/products/ghee_mysore_pak.jpg',
  'Kaju Katli': 'asset:assets/products/kaju_katli.jpg',
  'Badam Halwa': 'asset:assets/products/badam_halwa.jpg',
  'Dry Fruit Laddu': 'asset:assets/products/dry_fruit_laddu.jpg',
  'Soan Papdi': 'asset:assets/products/soan_papdi.jpg',
};

const catalogCategoryImages = {
  'cat_normal': 'asset:assets/products/normal_sweets.jpg',
  'cat_special': 'asset:assets/products/special_sweets.jpg',
};

const catalogProductNamesTamil = {
  'Mysore Pak': 'மைசூர் பாக்',
  'Jangiri': 'ஜாங்கிரி',
  'Boondi Laddu': 'பூந்தி லட்டு',
  'Milk Peda': 'பால் பேடா',
  'Gulab Jamun': 'குலாப் ஜாமுன்',
  'Ghee Mysore Pak': 'நெய் மைசூர் பாக்',
  'Kaju Katli': 'முந்திரி கத்லி',
  'Badam Halwa': 'பாதாம் அல்வா',
  'Dry Fruit Laddu': 'உலர் பழ லட்டு',
  'Soan Papdi': 'சோன்பப்டி',
  'Mixture': 'மிக்சர்',
  'Murukku': 'முறுக்கு',
  'Ribbon Pakoda': 'ரிப்பன் பகோடா',
  'Kara Boondi': 'கார பூந்தி',
  'Snack Packet': 'சிற்றுண்டி பாக்கெட்',
  'Water Bottle': 'தண்ணீர் பாட்டில்',
  'Gift Box': 'பரிசுப் பெட்டி',
  'Other Item': 'மற்ற பொருள்',
};

/// Default categories. Top Rated and Other Items are system categories:
/// they can be renamed but not deleted.
List<Category> defaultCategories() => [
  Category(
    id: 'cat_normal',
    name: 'Normal Sweets',
    nameTamil: 'சாதாரண இனிப்புகள்',
    imageName: catalogCategoryImages['cat_normal'],
    order: 0,
  ),
  Category(
    id: 'cat_special',
    name: 'Special Sweets',
    nameTamil: 'சிறப்பு இனிப்புகள்',
    imageName: catalogCategoryImages['cat_special'],
    order: 1,
  ),
  Category(
    id: 'cat_karam',
    name: 'Karam & Savories',
    nameTamil: 'காரம் மற்றும் பலகாரங்கள்',
    order: 2,
  ),
  Category(
    id: 'cat_top',
    name: 'Top Rated Specials',
    nameTamil: 'மிகவும் விரும்பப்படும் சிறப்புகள்',
    order: 3,
    kind: CategoryKind.topRated,
  ),
  Category(
    id: 'cat_other',
    name: 'Other Items',
    nameTamil: 'மற்ற பொருட்கள்',
    order: 4,
    kind: CategoryKind.other,
  ),
];

/// Starter catalog so the counter can bill on day one. Every product and
/// rate is editable from Admin → Products.
List<Product> sampleProducts() {
  Product weight(
    String name,
    String category,
    double rate, {
    bool popular = false,
  }) => Product(
    id: newId(),
    name: name,
    nameTamil: catalogProductNamesTamil[name] ?? '',
    categoryId: category,
    imageName: catalogProductImages[name],
    ratePerKg: rate,
    isPopular: popular,
  );
  Product unit(String name, String category, double price, String label) =>
      Product(
        id: newId(),
        name: name,
        nameTamil: catalogProductNamesTamil[name] ?? '',
        categoryId: category,
        imageName: catalogProductImages[name],
        mode: ProductMode.unit,
        unitPrice: price,
        unitLabel: label,
      );

  return [
    weight('Mysore Pak', 'cat_normal', 360),
    weight('Jangiri', 'cat_normal', 320),
    weight('Boondi Laddu', 'cat_normal', 300),
    weight('Milk Peda', 'cat_normal', 490),
    unit('Gulab Jamun', 'cat_normal', 15, 'piece'),
    weight('Ghee Mysore Pak', 'cat_special', 280, popular: true),
    weight('Kaju Katli', 'cat_special', 900, popular: true),
    weight('Badam Halwa', 'cat_special', 650, popular: true),
    weight('Dry Fruit Laddu', 'cat_special', 720),
    weight('Soan Papdi', 'cat_special', 480),
    weight('Mixture', 'cat_karam', 240, popular: true),
    weight('Murukku', 'cat_karam', 280),
    weight('Ribbon Pakoda', 'cat_karam', 260),
    weight('Kara Boondi', 'cat_karam', 240),
    unit('Snack Packet', 'cat_other', 20, 'packet'),
    unit('Water Bottle', 'cat_other', 20, 'bottle'),
    unit('Gift Box', 'cat_other', 150, 'box'),
    Product(
      id: newId(),
      name: 'Other Item',
      nameTamil: catalogProductNamesTamil['Other Item']!,
      categoryId: 'cat_other',
      mode: ProductMode.amountOnly,
    ),
  ];
}
