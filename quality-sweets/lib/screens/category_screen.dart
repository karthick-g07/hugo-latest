import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart' as fmt;
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'item_sheet.dart';

enum _Sort { name, priceLow, priceHigh }

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key, required this.categoryId});

  final String categoryId;

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final _search = TextEditingController();
  _Sort _sort = _Sort.name;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final category = store.categoryById(widget.categoryId);
    if (category == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.category_outlined,
          title: 'Category removed',
          message: 'This category no longer exists.',
        ),
      );
    }
    final needle = _search.text.trim().toLowerCase();
    final products =
        store
            .productsIn(category)
            .where(
              (p) =>
                  p.name.toLowerCase().contains(needle) ||
                  p.nameTamil.toLowerCase().contains(needle),
            )
            .toList()
          ..sort(switch (_sort) {
            _Sort.name => (a, b) => a.name.compareTo(b.name),
            _Sort.priceLow => (a, b) => a.defaultRate.compareTo(b.defaultRate),
            _Sort.priceHigh => (a, b) => b.defaultRate.compareTo(a.defaultRate),
          });
    final width = MediaQuery.sizeOf(context).width;
    final available = width >= tabletBreakpoint ? width - 400 : width;
    final columns = (available / 170).floor().clamp(2, 6);

    return Scaffold(
      appBar: AppBar(
        title: Text(category.displayName(store.settings.language)),
        actions: [
          PopupMenuButton<_Sort>(
            tooltip: 'Sort products',
            icon: const Icon(Icons.sort),
            initialValue: _sort,
            onSelected: (value) => setState(() => _sort = value),
            itemBuilder: (_) => const [
              PopupMenuItem(value: _Sort.name, child: Text('Name (A–Z)')),
              PopupMenuItem(
                value: _Sort.priceLow,
                child: Text('Price: low to high'),
              ),
              PopupMenuItem(
                value: _Sort.priceHigh,
                child: Text('Price: high to low'),
              ),
            ],
          ),
          IconButton(
            tooltip: 'Quick add custom item',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => openCustomItem(
              context,
              categoryId: category.kind == CategoryKind.topRated
                  ? null
                  : category.id,
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              decoration: InputDecoration(
                hintText:
                    'Search in ${category.displayName(store.settings.language)}',
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: products.isEmpty
          ? EmptyState(
              icon: Icons.inventory_2_outlined,
              title: needle.isEmpty ? 'No products yet' : 'No matches',
              message: needle.isEmpty
                  ? category.kind == CategoryKind.topRated
                        ? 'Mark products as Top Rated in Admin → Products.'
                        : 'Add products to this category from Admin → Products.'
                  : 'Try a different name, or add a custom item.',
              action: OutlinedButton.icon(
                onPressed: () =>
                    openCustomItem(context, name: _search.text.trim()),
                icon: const Icon(Icons.add),
                label: const Text('Quick add item'),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.8,
              ),
              itemCount: products.length,
              itemBuilder: (context, i) => ProductCard(product: products[i]),
            ),
    );
  }
}

/// Grid card for a product; tapping opens the matching billing dialog.
class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final language = context.watch<AppStore>().settings.language;
    final name = product.displayName(language);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openProduct(context, product),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  QsImage(imageName: product.imageName, label: name, radius: 0),
                  if (product.isPopular)
                    const Positioned(top: 8, left: 8, child: _PopularBadge()),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          fmt.productRateLabel(product),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: QsColors.maroon,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.add_circle,
                    color: QsColors.maroon,
                    size: 28,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductListTile extends StatelessWidget {
  const ProductListTile({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final category = store.categoryById(product.categoryId);
    final name = product.displayName(store.settings.language);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: QsImage(imageName: product.imageName, label: name, size: 48),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          '${category?.displayName(store.settings.language) ?? ''} · ${fmt.productRateLabel(product)}',
        ),
        trailing: const Icon(
          Icons.add_circle,
          color: QsColors.maroon,
          size: 30,
        ),
        onTap: () => openProduct(context, product),
      ),
    );
  }
}

class _PopularBadge extends StatelessWidget {
  const _PopularBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: QsColors.gold,
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Text(
      'Popular',
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
  );
}
