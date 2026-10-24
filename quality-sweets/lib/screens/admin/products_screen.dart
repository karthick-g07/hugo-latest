import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../format.dart' as fmt;
import '../../models.dart';
import '../../store.dart';
import '../../theme.dart';
import '../../widgets.dart';
import 'product_form_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key, this.popularOnly = false});

  final bool popularOnly;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _search = TextEditingController();
  String? _categoryId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openForm([Product? product]) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) =>
          ProductFormScreen(product: product, categoryId: _categoryId),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final needle = _search.text.trim().toLowerCase();
    final products =
        store.products
            .where(
              (p) =>
                  (!widget.popularOnly || p.isPopular || needle.isNotEmpty) &&
                  (_categoryId == null || p.categoryId == _categoryId) &&
                  p.name.toLowerCase().contains(needle),
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.popularOnly ? 'Top Rated Specials' : 'Products'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              decoration: InputDecoration(
                hintText: widget.popularOnly
                    ? 'Search to add more top rated products'
                    : 'Search products',
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
      body: Column(
        children: [
          if (!widget.popularOnly)
            SizedBox(
              height: 56,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                scrollDirection: Axis.horizontal,
                children: [
                  for (final category in [
                    null,
                    ...store.assignableCategories,
                  ]) ...[
                    ChoiceChip(
                      label: Text(
                        category?.displayName(store.settings.language) ?? 'All',
                      ),
                      selected: _categoryId == category?.id,
                      onSelected: (_) =>
                          setState(() => _categoryId = category?.id),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          if (widget.popularOnly)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Text(
                'Turn on the star to feature a product in Top Rated Specials on the home screen.',
                style: TextStyle(color: QsColors.muted),
              ),
            ),
          Expanded(
            child: products.isEmpty
                ? EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: widget.popularOnly
                        ? 'No top rated products'
                        : 'No products',
                    message: widget.popularOnly
                        ? 'Search above to find products and star them.'
                        : 'Add your first product with the button below.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: products.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final product = products[i];
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          contentPadding: const EdgeInsets.fromLTRB(
                            12,
                            4,
                            4,
                            4,
                          ),
                          leading: Opacity(
                            opacity: product.isActive ? 1 : 0.4,
                            child: QsImage(
                              imageName: product.imageName,
                              label: product.displayName(
                                store.settings.language,
                              ),
                              size: 48,
                            ),
                          ),
                          title: Text(
                            product.displayName(store.settings.language),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: product.isActive
                                  ? QsColors.charcoal
                                  : QsColors.muted,
                            ),
                          ),
                          subtitle: Text(
                            '${store.categoryById(product.categoryId)?.displayName(store.settings.language) ?? 'No category'} · '
                            '${fmt.productRateLabel(product)}${product.isActive ? '' : ' · inactive'}',
                          ),
                          trailing: widget.popularOnly
                              ? IconButton(
                                  tooltip: product.isPopular
                                      ? 'Remove from top rated'
                                      : 'Add to top rated',
                                  icon: Icon(
                                    product.isPopular
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: QsColors.gold,
                                    size: 30,
                                  ),
                                  onPressed: () => store.upsertProduct(
                                    product..isPopular = !product.isPopular,
                                  ),
                                )
                              : Switch(
                                  value: product.isActive,
                                  onChanged: (value) =>
                                      store.setProductActive(product, value),
                                ),
                          onTap: () => _openForm(product),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: widget.popularOnly
          ? null
          : FloatingActionButton.extended(
              backgroundColor: QsColors.maroon,
              foregroundColor: Colors.white,
              onPressed: _openForm,
              icon: const Icon(Icons.add),
              label: const Text('Add Product'),
            ),
    );
  }
}
