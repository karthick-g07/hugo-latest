import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../format.dart' as fmt;
import '../../store.dart';
import '../../theme.dart';
import '../../widgets.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _busy = false;

  AppStore get _store => context.read<AppStore>();

  Rect? _origin() {
    final box = context.findRenderObject() as RenderBox?;
    return box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _guard(Future<void> Function() task) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await task();
    } catch (error) {
      if (mounted) showMessage(context, 'Something went wrong: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export(BackupKind kind) => _guard(() async {
    final json = await _store.exportBackup(kind: kind);
    final images = await _store.exportImageArchive(kind: kind);
    final dir = await getTemporaryDirectory();
    final stamp = DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());
    final suffix = kind == BackupKind.setup ? 'setup' : 'bills';
    final file = await File('${dir.path}/quality-sweets-$suffix-$stamp.json')
        .writeAsString(json, flush: true);
    final imageFile = await File(
      '${dir.path}/quality-sweets-$suffix-images-$stamp.zip',
    ).writeAsBytes(images, flush: true);
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(file.path, mimeType: 'application/json'),
          XFile(imageFile.path, mimeType: 'application/zip'),
        ],
        subject: 'Quality Sweets $suffix backup $stamp',
        sharePositionOrigin: _origin(),
      ),
    );
    if (!mounted) return;
    showMessage(
      context,
      result.status == ShareResultStatus.dismissed
          ? 'Backup not saved — choose Save to Files, Drive or similar'
          : 'Backup exported. Keep both the JSON and ZIP files together.',
    );
  });

  Future<void> _import() => _guard(() async {
    final picked = await FilePicker.pickFile(type: FileType.any);
    final path = picked?.path;
    if (path == null || !mounted) return;
    final ImportPreview preview;
    try {
      preview = _store.previewImport(await File(path).readAsString());
    } on FormatException catch (error) {
      if (mounted) showMessage(context, error.message);
      return;
    } on FileSystemException {
      if (mounted) showMessage(context, 'Could not read that file.');
      return;
    }
    if (path.toLowerCase().endsWith('.json')) {
      final imagePick = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        dialogTitle: 'Select the matching Quality Sweets images ZIP (optional)',
      );
      if (imagePick?.path != null) {
        try {
          preview.images.addAll(
            _store.decodeImageArchive(
              await File(imagePick!.path!).readAsBytes(),
            ),
          );
        } catch (_) {
          if (mounted) showMessage(context, 'Could not read the images ZIP.');
          return;
        }
      }
    }
    if (!mounted) return;
    final choice = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        icon: const Icon(
          Icons.file_download_outlined,
          size: 40,
          color: QsColors.maroon,
        ),
        title: Text('Import ${_backupLabel(preview.kind)}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TotalRow('Categories', '${preview.categories.length}'),
            TotalRow('Products', '${preview.products.length}'),
            TotalRow('Saved bills', '${preview.bills.length}'),
            TotalRow('Images', '${preview.images.length}'),
            const SizedBox(height: 12),
            Text(switch (preview.kind) {
              BackupKind.setup =>
                'Merge: add new products and categories, then apply the saved shop settings.\n'
                    'Replace: replace products, categories and settings; keep existing bills and the current bill.',
              BackupKind.bills =>
                'Merge: add bills that are not already on this device.\n'
                    'Replace: replace saved bill history only; keep products, settings and the current bill.',
              BackupKind.full =>
                'Merge: keeps your data and adds anything new from the file.\n'
                    'Replace: deletes all current data, including the current bill, and uses the file instead.',
            }, style: TextStyle(fontSize: 12, color: QsColors.muted)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: QsColors.danger),
            onPressed: () => Navigator.pop(dialog, 'replace'),
            child: const Text('Replace'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(48, 44)),
            onPressed: () => Navigator.pop(dialog, 'merge'),
            child: const Text('Merge'),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'replace') {
      final sure = await confirm(
        context,
        title: switch (preview.kind) {
          BackupKind.setup => 'Replace app setup?',
          BackupKind.bills => 'Replace bill history?',
          BackupKind.full => 'Replace all data?',
        },
        message: switch (preview.kind) {
          BackupKind.setup => 'Products, categories and shop settings will be replaced. Saved bills and the current bill will stay on this device.',
          BackupKind.bills => 'All saved bills on this device will be replaced. Products, settings and the current bill will stay unchanged.',
          BackupKind.full => 'Every product, category, saved bill and setting on this device will be replaced.',
        },
        confirmLabel: 'Replace',
        destructive: true,
        icon: Icons.warning_amber_rounded,
      );
      if (!sure) return;
    }
    await _store.applyImport(preview, replace: choice == 'replace');
    if (mounted) showMessage(context, 'Backup imported');
  });

  String _backupLabel(BackupKind kind) => switch (kind) {
    BackupKind.setup => 'app setup',
    BackupKind.bills => 'bill history',
    BackupKind.full => 'full backup',
  };

  Future<void> _clear() async {
    final typed = await showDialog<bool>(
      context: context,
      builder: (_) => const _ClearDialog(),
    );
    if (typed != true || !mounted) return;
    _store.clearAllData();
    showMessage(context, 'All local data cleared');
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final last = store.settings.lastBackupAt;
    return Scaffold(
      appBar: AppBar(title: const Text('Data Backup')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: const Color(0xFFFFF3DC),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'Data is stored only on this device and does not sync between devices. '
                  'It is lost if the app is deleted or the phone is lost or reset.\n\n'
                  'Last backup: ${last == null ? 'never' : fmt.dateTime(last)}',
                ),
              ),
            ),
            const SizedBox(height: 12),
            for (final (icon, title, subtitle, action) in [
              (
                Icons.upload_file_outlined,
                'Export App Setup',
                'Products, rates, categories, settings and images; no bill history',
                () => _export(BackupKind.setup),
              ),
              (
                Icons.receipt_long_outlined,
                'Export Bill History',
                'Saved bills only, with a separate images ZIP',
                () => _export(BackupKind.bills),
              ),
              (
                Icons.file_download_outlined,
                'Import Backup',
                'Import app setup or bill history with its matching ZIP',
                _import,
              ),
            ]) ...[
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: QsColors.creamDeep,
                    child: Icon(icon, color: QsColors.maroon),
                  ),
                  title: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(subtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: action,
                ),
              ),
              const SizedBox(height: 12),
            ],
            Card(
              color: const Color(0xFFFDECEA),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: QsColors.danger,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Clear All Data',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: QsColors.danger,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Permanently deletes all products, saved bills, the current bill and settings from this device. '
                      'Default categories are kept.',
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: QsColors.danger,
                      ),
                      onPressed: _clear,
                      child: const Text('Clear All Data'),
                    ),
                  ],
                ),
              ),
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}

/// Strong confirmation: the user must type DELETE.
class _ClearDialog extends StatefulWidget {
  const _ClearDialog();

  @override
  State<_ClearDialog> createState() => _ClearDialogState();
}

class _ClearDialogState extends State<_ClearDialog> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = _text.text.trim().toUpperCase() == 'DELETE';
    return AlertDialog(
      icon: const Icon(
        Icons.warning_amber_rounded,
        size: 40,
        color: QsColors.danger,
      ),
      title: const Text('Clear all data?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'This cannot be undone. Export a backup first if you may need this data.\n\nType DELETE to confirm.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Type DELETE'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: QsColors.danger,
            minimumSize: const Size(48, 44),
          ),
          onPressed: ok ? () => Navigator.pop(context, true) : null,
          child: const Text('Clear everything'),
        ),
      ],
    );
  }
}
