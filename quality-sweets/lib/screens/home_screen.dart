import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart' as fmt;
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'category_screen.dart';
import 'item_sheet.dart';
import 'shell.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _search = TextEditingController();
  bool _showFilters = false;
  String? _categoryId;
  ProductMode? _mode;
  bool _popularOnly = false;
  ProductSort _sort = ProductSort.name;

  bool get _filtered =>
      _categoryId != null ||
      _mode != null ||
      _popularOnly ||
      _sort != ProductSort.name;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clearSearch() => setState(() {
    _search.clear();
    _showFilters = false;
    _categoryId = null;
    _mode = null;
    _popularOnly = false;
    _sort = ProductSort.name;
  });

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    ),
  );

  Widget _filterBar(AppStore store) {
    final categories = store.activeCategories.where(
      (c) => c.kind != CategoryKind.topRated,
    );
    Widget row(List<Widget> chips) => SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: chips,
      ),
    );
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            row([
              _chip(
                'All categories',
                _categoryId == null,
                () => setState(() => _categoryId = null),
              ),
              for (final category in categories)
                _chip(
                  category.displayName(
                    context.watch<AppStore>().settings.language,
                  ),
                  _categoryId == category.id,
                  () => setState(
                    () => _categoryId = _categoryId == category.id
                        ? null
                        : category.id,
                  ),
                ),
            ]),
            row([
              for (final (mode, label) in [
                (ProductMode.weight, 'By weight'),
                (ProductMode.unit, 'Fixed price'),
                (ProductMode.amountOnly, 'Amount only'),
              ])
                _chip(
                  label,
                  _mode == mode,
                  () => setState(() => _mode = _mode == mode ? null : mode),
                ),
              _chip(
                'Top rated',
                _popularOnly,
                () => setState(() => _popularOnly = !_popularOnly),
              ),
              for (final (sort, label) in [
                (ProductSort.priceLow, 'Price: low to high'),
                (ProductSort.priceHigh, 'Price: high to low'),
              ])
                _chip(
                  label,
                  _sort == sort,
                  () => setState(
                    () => _sort = _sort == sort ? ProductSort.name : sort,
                  ),
                ),
            ]),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final query = _search.text.trim();
    final searching = query.isNotEmpty || _showFilters || _filtered;
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= tabletBreakpoint;
    final columns = ((wide ? width - 400 : width) / 190).floor().clamp(2, 5);
    final bannerVisible = !wide && store.draft.lines.isNotEmpty;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 150,
            toolbarHeight: 72,
            titleSpacing: 16,
            centerTitle: false,
            title: Row(
              children: [
                const QsLogo(size: 40, onDark: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BrandTitle(
                        store.settings.shopName,
                        color: Colors.white,
                        size: 22,
                      ),
                      if (store.settings.tagline.isNotEmpty)
                        Text(
                          store.settings.tagline,
                          style: const TextStyle(
                            fontSize: 12,
                            color: QsColors.gold,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Quick add custom item',
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => openCustomItem(context),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(68),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search sweets and snacks…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Search filters',
                          icon: Badge(
                            isLabelVisible: _filtered,
                            backgroundColor: QsColors.gold,
                            child: Icon(
                              Icons.tune,
                              color: _showFilters ? QsColors.maroon : null,
                            ),
                          ),
                          onPressed: () =>
                              setState(() => _showFilters = !_showFilters),
                        ),
                        if (searching)
                          IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close),
                            onPressed: _clearSearch,
                          ),
                      ],
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: const BorderSide(
                        color: QsColors.gold,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (searching) ...[
            if (_showFilters || _filtered) _filterBar(store),
            ..._searchResults(
              context,
              store.search(
                query,
                categoryId: _categoryId,
                mode: _mode,
                popularOnly: _popularOnly,
                sort: _sort,
              ),
              query,
            ),
          ] else ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (bannerVisible) const _CurrentBillBanner(),
                    const SectionTitle('Categories'),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.15,
                ),
                itemCount: store.activeCategories.length + 1,
                itemBuilder: (context, i) => i < store.activeCategories.length
                    ? _CategoryCard(category: store.activeCategories[i])
                    : const _QuickAddCard(),
              ),
            ),
            if (store.recentProducts.isNotEmpty)
              _productStrip(context, 'Recently billed', store.recentProducts),
            if (store.popularProducts.isNotEmpty)
              _productStrip(
                context,
                'Top rated specials',
                store.popularProducts,
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ],
      ),
    );
  }

  List<Widget> _searchResults(
    BuildContext context,
    List<Product> results,
    String query,
  ) => [
    if (results.isEmpty)
      SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyState(
          icon: Icons.search_off,
          title: 'No products found',
          message: query.isEmpty
              ? 'No products match these filters.'
              : 'Nothing matches "$query". Add it as a custom item for this bill.',
          action: FilledButton.icon(
            onPressed: () =>
                openCustomItem(context, name: query.isEmpty ? null : query),
            icon: const Icon(Icons.add),
            label: const Text('Quick add item'),
          ),
        ),
      )
    else
      SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverList.separated(
          itemCount: results.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) => ProductListTile(product: results[i]),
        ),
      ),
  ];

  Widget _productStrip(
    BuildContext context,
    String title,
    List<Product> items,
  ) => SliverToBoxAdapter(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SectionTitle(title),
        ),
        SizedBox(
          height: 168,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) =>
                SizedBox(width: 132, child: ProductCard(product: items[i])),
          ),
        ),
      ],
    ),
  );
}

class _CurrentBillBanner extends StatelessWidget {
  const _CurrentBillBanner();

  @override
  Widget build(BuildContext context) {
    final bill = context.watch<AppStore>().draft;
    final count = bill.lines.length;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: QsColors.maroon,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Shell.go(Shell.bill),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.receipt_long, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Current bill · $count ${count == 1 ? 'item' : 'items'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  fmt.money2(bill.grandTotal),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category});

  final Category category;

  @override
  Widget build(BuildContext context) {
    final count = context.watch<AppStore>().productsIn(category).length;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CategoryScreen(categoryId: category.id),
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            QsImage(
              imageName: category.imageName,
              label: category.displayName(
                context.watch<AppStore>().settings.language,
              ),
              radius: 0,
              icon: categoryIcon(category),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.35, 1],
                  colors: [Colors.transparent, Color(0xE68B0000)],
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.displayName(
                      context.watch<AppStore>().settings.language,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    '$count ${count == 1 ? 'item' : 'items'}',
                    style: const TextStyle(color: QsColors.gold, fontSize: 12),
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

class _QuickAddCard extends StatelessWidget {
  const _QuickAddCard();

  @override
  Widget build(BuildContext context) => Card(
    color: QsColors.creamDeep,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => openCustomItem(context),
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle, color: QsColors.maroon, size: 40),
              SizedBox(height: 8),
              Text(
                'Quick Add',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: QsColors.maroon,
                ),
              ),
              Text(
                'Custom item or amount',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: QsColors.muted),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
