import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models.dart';
import '../../store.dart';
import '../../theme.dart';
import '../../widgets.dart';
import 'image_picker_field.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final categories = store.sortedCategories;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: () => _edit(context, null),
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
        ],
      ),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        header: const Padding(
          padding: EdgeInsets.only(bottom: 10, left: 4),
          child: Text(
            'Drag the handle to reorder. Order here is the order on the home screen.',
            style: TextStyle(color: QsColors.muted, fontSize: 12),
          ),
        ),
        itemCount: categories.length,
        onReorderItem: store.reorderCategories,
        buildDefaultDragHandles: false,
        itemBuilder: (context, i) {
          final category = categories[i];
          final count = store.productsIn(category, activeOnly: false).length;
          return Padding(
            key: ValueKey(category.id),
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                contentPadding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ReorderableDragStartListener(
                      index: i,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.drag_indicator,
                          color: QsColors.muted,
                        ),
                      ),
                    ),
                    QsImage(
                      imageName: category.imageName,
                      label: category.displayName(store.settings.language),
                      size: 44,
                      icon: categoryIcon(category),
                    ),
                  ],
                ),
                title: Text(
                  category.displayName(store.settings.language),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '$count ${count == 1 ? 'product' : 'products'}'
                  '${category.kind == CategoryKind.topRated ? ' · starred products' : ''}'
                  '${category.isSystem ? ' · default' : ''}',
                ),
                trailing: Switch(
                  value: category.isActive,
                  onChanged: (value) =>
                      store.setCategoryActive(category, value),
                ),
                onTap: () => _edit(context, category),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _edit(BuildContext context, Category? category) async {
    await showSheet<void>(context, (_) => _CategorySheet(category: category));
  }
}

class _CategorySheet extends StatefulWidget {
  const _CategorySheet({this.category});

  final Category? category;

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  late final AppStore _store = context.read<AppStore>();
  late final _name = TextEditingController(text: widget.category?.name);
  late final _nameTamil = TextEditingController(
    text: widget.category?.nameTamil,
  );
  late String? _imageName = widget.category?.imageName;
  bool _submitted = false;

  @override
  void dispose() {
    _name.dispose();
    _nameTamil.dispose();
    super.dispose();
  }

  String? get _error {
    final name = _name.text.trim();
    if (name.isEmpty) return 'Enter a category name';
    final duplicate = _store.categories.any(
      (c) =>
          c.id != widget.category?.id &&
          c.name.toLowerCase() == name.toLowerCase(),
    );
    return duplicate ? 'A category with this name already exists' : null;
  }

  void _save() {
    setState(() => _submitted = true);
    if (_error != null) return;
    final category = (widget.category ?? Category(id: newId(), name: ''))
      ..name = _name.text.trim()
      ..nameTamil = _nameTamil.text.trim()
      ..imageName = _imageName;
    _store.upsertCategory(category);
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final category = widget.category!;
    final products = _store.productsIn(category, activeOnly: false);
    final targets = _store.assignableCategories
        .where((c) => c.id != category.id)
        .toList();
    var moveTo = _store.otherCategory;
    if (products.isNotEmpty) {
      final target = await showDialog<Category>(
        context: context,
        builder: (dialog) => SimpleDialog(
          title: Text(
            'Move ${products.length} ${products.length == 1 ? 'product' : 'products'} to…',
          ),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                'Products are moved, not deleted.',
                style: TextStyle(color: QsColors.muted),
              ),
            ),
            for (final target in targets)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dialog, target),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    target.name,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
          ],
        ),
      );
      if (target == null || !mounted) return;
      moveTo = target;
    } else {
      final sure = await confirm(
        context,
        title: 'Delete ${category.name}?',
        message: 'This category has no products.',
        confirmLabel: 'Delete',
        destructive: true,
        icon: Icons.delete_outline,
      );
      if (!sure || !mounted) return;
    }
    _store.deleteCategory(category, moveTo);
    Navigator.pop(context);
    showMessage(
      context,
      products.isEmpty
          ? 'Category deleted'
          : 'Category deleted · products moved to ${moveTo.name}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.category;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            category == null ? 'Add Category' : 'Edit Category',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Center(
            child: ImagePickerField(
              imageName: _imageName,
              label: _name.text,
              size: 100,
              onChanged: (name) => setState(() => _imageName = name),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            autofocus: category == null,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: 'Category name',
              errorText: _submitted ? _error : null,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _nameTamil,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Category name in Tamil (தமிழ்)',
              hintText: 'தமிழில் பெயர்',
            ),
          ),
          if (category?.kind == CategoryKind.topRated)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Shows every product marked Top rated. Manage them in Admin → Top Rated Specials.',
                style: TextStyle(fontSize: 12, color: QsColors.muted),
              ),
            ),
          if (category?.kind == CategoryKind.other)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Default home for miscellaneous and quick-added items. It can be renamed but not deleted.',
                style: TextStyle(fontSize: 12, color: QsColors.muted),
              ),
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (category != null && !category.isSystem) ...[
                IconButton.outlined(
                  tooltip: 'Delete category',
                  color: QsColors.danger,
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline),
                ),
                const SizedBox(width: 12),
              ],
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
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
