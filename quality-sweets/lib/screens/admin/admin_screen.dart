import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../format.dart' as fmt;
import '../../store.dart';
import '../../theme.dart';
import '../../widgets.dart';
import 'backup_screen.dart';
import 'billing_options_screen.dart';
import 'categories_screen.dart';
import 'products_screen.dart';
import 'shop_settings_screen.dart';
import 'whatsapp_settings_screen.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final today = store.billsOn(DateTime.now());
    final todayTotal = today.fold<double>(0, (sum, bill) => sum + bill.grandTotal);
    final frequent = store.frequentlyBilled();
    final lastBackup = store.settings.lastBackupAt;
    final backupOverdue =
        store.savedBills.isNotEmpty &&
        (lastBackup == null || DateTime.now().difference(lastBackup).inDays >= 7);
    final width = MediaQuery.sizeOf(context).width;
    final statWidth = ((width - 44) / (width >= 700 ? 4 : 2)).floorToDouble();

    void open(Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text('Admin Dashboard')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final (icon, value, label, onTap) in [
                (
                  Icons.inventory_2_outlined,
                  store.products.where((p) => p.isActive).length,
                  'Active products',
                  () => open(const ProductsScreen()),
                ),
                (
                  Icons.category_outlined,
                  store.categories.length,
                  'Categories',
                  () => open(const CategoriesScreen()),
                ),
                (Icons.bookmark_border, store.savedBills.length, 'Saved bills', null),
                (
                  Icons.workspace_premium_outlined,
                  store.products.where((p) => p.isPopular).length,
                  'Top rated',
                  () => open(const ProductsScreen(popularOnly: true)),
                ),
              ])
                SizedBox(
                  width: statWidth,
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: onTap,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: QsColors.creamDeep,
                              child: Icon(icon, color: QsColors.maroon),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$value',
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                                  ),
                                  Text(
                                    label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, color: QsColors.muted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SectionTitle('Today on this device'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TotalRow('Saved bills today', '${today.length}'),
                  TotalRow('Total of saved bills', fmt.money2(todayTotal), big: true),
                  const SizedBox(height: 6),
                  const Text(
                    'Counts only bills saved in this app on this device. It is not a complete accounting record.',
                    style: TextStyle(fontSize: 12, color: QsColors.muted),
                  ),
                ],
              ),
            ),
          ),
          if (frequent.isNotEmpty) ...[
            const SectionTitle('Frequently billed'),
            Card(
              child: Column(
                children: [
                  for (final entry in frequent)
                    ListTile(
                      dense: true,
                      title: Text(
                        entry.key,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      trailing: Text('${entry.value} ${entry.value == 1 ? 'bill line' : 'bill lines'}'),
                    ),
                ],
              ),
            ),
          ],
          const SectionTitle('Manage'),
          Card(
            child: Column(
              children: [
                for (final (icon, title, subtitle, screen) in [
                  (
                    Icons.inventory_2_outlined,
                    'Products',
                    'Add, edit, rates and images',
                    const ProductsScreen(),
                  ),
                  (
                    Icons.category_outlined,
                    'Categories',
                    'Add, rename, reorder, images',
                    const CategoriesScreen(),
                  ),
                  (
                    Icons.workspace_premium_outlined,
                    'Top Rated Specials',
                    'Choose featured products',
                    const ProductsScreen(popularOnly: true),
                  ),
                  (
                    Icons.storefront_outlined,
                    'Shop Settings',
                    'Name, logo, phone, GPay QR, invoice',
                    const ShopSettingsScreen(),
                  ),
                  (
                    Icons.tune,
                    'Billing Options',
                    'Discount, payment, tax, presets',
                    const BillingOptionsScreen(),
                  ),
                  (
                    Icons.chat_outlined,
                    'WhatsApp Settings',
                    'Owner numbers & auto-forward',
                    const WhatsAppSettingsScreen(),
                  ),
                  (Icons.backup_outlined, 'Data Backup', 'Export, import, clear data', const BackupScreen()),
                ]) ...[
                  ListTile(
                    leading: Icon(icon, color: QsColors.maroon),
                    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(subtitle),
                    trailing: title == 'Data Backup' && backupOverdue
                        ? const Badge(label: Text('Backup due'), backgroundColor: QsColors.gold)
                        : const Icon(Icons.chevron_right),
                    onTap: () => open(screen),
                  ),
                  if (title != 'Data Backup') const Divider(indent: 56),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: const Color(0xFFFFF3DC),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: QsColors.gold),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'All data is stored only on this device and does not sync. '
                      'Export a backup regularly — data is lost if the app is uninstalled or the phone is lost.'
                      '${lastBackup == null ? '' : '\nLast backup: ${fmt.dateTime(lastBackup)}'}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
