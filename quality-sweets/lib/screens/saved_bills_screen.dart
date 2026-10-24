import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart' as fmt;
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'bill_flows.dart';
import 'invoice_screen.dart';
import 'shell.dart';

enum _Sort { newest, oldest, amountHigh, amountLow }

enum _DateFilter { all, today, yesterday, last7Days, thisMonth, custom }

class SavedBillsScreen extends StatefulWidget {
  const SavedBillsScreen({super.key});

  @override
  State<SavedBillsScreen> createState() => _SavedBillsScreenState();
}

class _SavedBillsScreenState extends State<SavedBillsScreen> {
  final _search = TextEditingController();
  _Sort _sort = _Sort.newest;
  _DateFilter _date = _DateFilter.all;
  DateTimeRange? _customRange;
  String? _payment;
  bool _discountedOnly = false;
  bool _withCustomerOnly = false;

  bool get _filtered => _date != _DateFilter.all || _payment != null || _discountedOnly || _withCustomerOnly;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Start (inclusive) and end (exclusive) of the selected date filter.
  (DateTime?, DateTime?) get _dateBounds {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    return switch (_date) {
      _DateFilter.all => (null, null),
      _DateFilter.today => (today, tomorrow),
      _DateFilter.yesterday => (today.subtract(const Duration(days: 1)), today),
      _DateFilter.last7Days => (today.subtract(const Duration(days: 6)), tomorrow),
      _DateFilter.thisMonth => (DateTime(now.year, now.month), tomorrow),
      _DateFilter.custom => (_customRange?.start, _customRange?.end.add(const Duration(days: 1))),
    };
  }

  String _dateLabel(_DateFilter filter) => switch (filter) {
    _DateFilter.all => 'All dates',
    _DateFilter.today => 'Today',
    _DateFilter.yesterday => 'Yesterday',
    _DateFilter.last7Days => 'Last 7 days',
    _DateFilter.thisMonth => 'This month',
    _DateFilter.custom =>
      _customRange == null
          ? 'Pick dates…'
          : '${fmt.date(_customRange!.start)} – ${fmt.date(_customRange!.end)}',
  };

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: _customRange,
    );
    if (range != null) {
      setState(() {
        _customRange = range;
        _date = _DateFilter.custom;
      });
    }
  }

  void _clearFilters() => setState(() {
    _date = _DateFilter.all;
    _customRange = null;
    _payment = null;
    _discountedOnly = false;
    _withCustomerOnly = false;
  });

  Widget _filterBar(List<String> paymentMethods) => SizedBox(
    height: 52,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      children: [
        for (final filter in _DateFilter.values.where((f) => f != _DateFilter.all))
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(_dateLabel(filter)),
              selected: _date == filter,
              onSelected: (selected) => filter == _DateFilter.custom
                  ? _pickRange()
                  : setState(() => _date = selected ? filter : _DateFilter.all),
            ),
          ),
        for (final method in paymentMethods)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(method),
              selected: _payment == method,
              onSelected: (selected) => setState(() => _payment = selected ? method : null),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilterChip(
            label: const Text('Discounted'),
            selected: _discountedOnly,
            onSelected: (v) => setState(() => _discountedOnly = v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilterChip(
            label: const Text('With customer'),
            selected: _withCustomerOnly,
            onSelected: (v) => setState(() => _withCustomerOnly = v),
          ),
        ),
        if (_filtered)
          ActionChip(
            avatar: const Icon(Icons.close, size: 18),
            label: const Text('Clear'),
            onPressed: _clearFilters,
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final (from, to) = _dateBounds;
    final paymentMethods = store.savedBills.map((b) => b.paymentMethod).whereType<String>().toSet().toList()
      ..sort();
    final bills =
        store.findBills(
          query: _search.text,
          from: from,
          to: to,
          paymentMethod: _payment,
          discountedOnly: _discountedOnly,
          withCustomerOnly: _withCustomerOnly,
        )..sort(switch (_sort) {
          _Sort.newest => (a, b) => b.createdAt.compareTo(a.createdAt),
          _Sort.oldest => (a, b) => a.createdAt.compareTo(b.createdAt),
          _Sort.amountHigh => (a, b) => b.grandTotal.compareTo(a.grandTotal),
          _Sort.amountLow => (a, b) => a.grandTotal.compareTo(b.grandTotal),
        });

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Saved Bills'),
        actions: [
          PopupMenuButton<_Sort>(
            tooltip: 'Sort bills',
            icon: const Icon(Icons.sort),
            initialValue: _sort,
            onSelected: (value) => setState(() => _sort = value),
            itemBuilder: (_) => const [
              PopupMenuItem(value: _Sort.newest, child: Text('Newest first')),
              PopupMenuItem(value: _Sort.oldest, child: Text('Oldest first')),
              PopupMenuItem(value: _Sort.amountHigh, child: Text('Amount: high to low')),
              PopupMenuItem(value: _Sort.amountLow, child: Text('Amount: low to high')),
            ],
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
                hintText: 'Search name, bill no., customer or item',
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
      body: store.savedBills.isEmpty
          ? const EmptyState(
              icon: Icons.bookmark_border,
              title: 'No saved bills yet',
              message: 'Bills you save from the Current Bill screen appear here.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _filterBar(paymentMethods),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Text(
                    '${bills.length} ${bills.length == 1 ? 'bill' : 'bills'} · '
                    '${fmt.money2(bills.fold<double>(0, (sum, bill) => sum + bill.grandTotal))}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: QsColors.muted),
                  ),
                ),
                Expanded(
                  child: bills.isEmpty
                      ? EmptyState(
                          icon: Icons.search_off,
                          title: 'No matching bills',
                          message: 'Try a different search or change the filters.',
                          action: _filtered
                              ? OutlinedButton(onPressed: _clearFilters, child: const Text('Clear filters'))
                              : null,
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: bills.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, i) => _BillTile(bill: bills[i]),
                        ),
                ),
              ],
            ),
    );
  }
}

class _BillTile extends StatelessWidget {
  const _BillTile({required this.bill});

  final Bill bill;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      title: Text(bill.name ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        '${bill.displayNumber} · ${fmt.dateTime(bill.createdAt)}\n'
        '${bill.lines.length} ${bill.lines.length == 1 ? 'item' : 'items'}'
        '${bill.customerName?.isNotEmpty == true ? ' · ${bill.customerName}' : ''}',
      ),
      isThreeLine: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            fmt.money2(bill.grandTotal),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: QsColors.maroon),
          ),
          const Icon(Icons.more_vert, color: QsColors.muted),
        ],
      ),
      onTap: () => _actions(context, bill),
    ),
  );
}

void _openInvoice(BuildContext context, Bill bill) => Navigator.of(
  context,
  rootNavigator: true,
).push(MaterialPageRoute(builder: (_) => InvoiceScreen(bill: bill)));

Future<void> _actions(BuildContext context, Bill bill) async {
  final store = context.read<AppStore>();
  final action = await showSheet<String>(
    context,
    (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(bill.name ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          Text(
            '${bill.displayNumber} · ${fmt.money2(bill.grandTotal)}',
            style: const TextStyle(color: QsColors.muted),
          ),
          const SizedBox(height: 8),
          for (final (value, icon, label) in [
            ('view', Icons.visibility_outlined, 'View Bill'),
            ('edit', Icons.edit_outlined, 'Edit / Resume Bill'),
            ('duplicate', Icons.copy_outlined, 'Duplicate as New Bill'),
            ('share', Icons.share_outlined, 'Share Bill'),
          ])
            ListTile(
              leading: Icon(icon, color: QsColors.maroon),
              title: Text(label),
              onTap: () => Navigator.pop(sheet, value),
            ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: QsColors.danger),
            title: const Text('Delete Bill', style: TextStyle(color: QsColors.danger)),
            onTap: () => Navigator.pop(sheet, 'delete'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return;
  switch (action) {
    case 'view' || 'share':
      _openInvoice(context, bill);
    case 'edit':
      if (store.draft.sourceBillId == bill.id && store.draftDirty) {
        Shell.go(Shell.bill);
        return;
      }
      if (!await protectDraft(context) || !context.mounted) return;
      store.resumeBill(bill);
      Shell.go(Shell.bill);
      showMessage(context, 'Editing ${bill.name}. Save to keep your changes.');
    case 'duplicate':
      if (!await protectDraft(context) || !context.mounted) return;
      store.duplicateBill(bill);
      Shell.go(Shell.bill);
      showMessage(context, 'Copied into a new bill. The original is unchanged.');
    case 'delete':
      final sure = await confirm(
        context,
        title: 'Delete this bill?',
        message: '"${bill.name}" (${bill.displayNumber}) will be permanently deleted from this device.',
        confirmLabel: 'Delete',
        destructive: true,
        icon: Icons.delete_outline,
      );
      if (sure && context.mounted) {
        store.deleteBill(bill);
        showMessage(context, 'Bill deleted');
      }
  }
}
