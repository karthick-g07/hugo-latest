import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart' as fmt;
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'shell.dart';

/// New Bill: protects an unsaved draft before clearing it.
Future<void> startNewBill(BuildContext context) async {
  final store = context.read<AppStore>();
  if (!store.draftNeedsProtection) {
    store.startNewDraft();
    showMessage(context, 'New bill started');
    return;
  }
  final choice = await showDialog<String>(
    context: context,
    builder: (context) => _ChoiceDialog(
      icon: Icons.warning_amber_rounded,
      title: 'Start a New Bill?',
      message:
          'Your current bill has ${store.draft.lines.length} unsaved '
          '${store.draft.lines.length == 1 ? 'item' : 'items'}. What would you like to do?',
      choices: const [
        ('save', 'Save & Start New Bill', Icons.save_outlined, false),
        ('delete', 'Delete & Start New Bill', Icons.delete_outline, true),
      ],
    ),
  );
  if (!context.mounted) return;
  if (choice == 'save') {
    await saveBill(context);
  } else if (choice == 'delete') {
    final sure = await confirm(
      context,
      title: 'Delete this draft?',
      message: 'Only the current unsaved bill is deleted. Saved bills are not affected.',
      confirmLabel: 'Delete draft',
      destructive: true,
      icon: Icons.delete_outline,
    );
    if (sure && context.mounted) {
      store.startNewDraft();
      showMessage(context, 'Draft deleted. New bill started.');
    }
  }
}

/// Before loading another bill into the billing area (edit/duplicate), asks
/// to save the current one with a name or delete it. Returns true when it is
/// safe to continue.
Future<bool> protectDraft(BuildContext context) async {
  final store = context.read<AppStore>();
  if (!store.draftNeedsProtection) return true;
  final count = store.draft.lines.length;
  final choice = await showDialog<String>(
    context: context,
    builder: (context) => _ChoiceDialog(
      icon: Icons.warning_amber_rounded,
      title: 'A bill is already open',
      message:
          'The billing area has $count unsaved ${count == 1 ? 'item' : 'items'}. '
          'Save it with a name, or delete it, before opening this bill.',
      choices: const [
        ('save', 'Save with a name', Icons.save_outlined, false),
        ('delete', 'Delete current bill', Icons.delete_outline, true),
      ],
    ),
  );
  if (!context.mounted || choice == null) return false;
  if (choice == 'save') return await saveBill(context, showSuccess: false) != null;
  return true;
}

/// Saves the current draft after asking for a name and clears the billing
/// area. Returns the saved bill.
Future<Bill?> saveBill(BuildContext context, {bool showSuccess = true}) async {
  final store = context.read<AppStore>();
  if (store.draft.isEmpty) {
    showMessage(context, 'Add at least one item before saving');
    return null;
  }
  var overwrite = false;
  final source = store.draftSource;
  if (source != null) {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => _ChoiceDialog(
        icon: Icons.save_as_outlined,
        title: 'Save changes?',
        message: 'This bill was opened from "${source.name}" (${source.displayNumber}).',
        choices: const [
          ('overwrite', 'Save Changes', Icons.save_outlined, false),
          ('copy', 'Save as a Copy', Icons.copy_outlined, false),
        ],
      ),
    );
    if (choice == null || !context.mounted) return null;
    overwrite = choice == 'overwrite';
  }

  final initial = overwrite ? (source!.name ?? '') : (source == null ? store.draft.name : null);
  final name = await showDialog<String>(
    context: context,
    builder: (_) => _BillNameDialog(initial: initial ?? store.suggestedBillName()),
  );
  if (name == null || !context.mounted) return null;

  final saved = store.saveDraft(name: name, overwrite: overwrite);
  if (showSuccess && context.mounted) {
    await showDialog<void>(
      context: context,
      builder: (_) => _SavedDialog(bill: saved),
    );
  }
  return saved;
}

class _ChoiceDialog extends StatelessWidget {
  const _ChoiceDialog({
    required this.icon,
    required this.title,
    required this.message,
    required this.choices,
  });

  final IconData icon;
  final String title;
  final String message;
  final List<(String, String, IconData, bool)> choices;

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: Icon(icon, size: 44, color: QsColors.gold),
    title: Text(title, textAlign: TextAlign.center),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 20),
        for (final (value, label, icon, destructive) in choices) ...[
          FilledButton.icon(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFBE9E7),
                    foregroundColor: QsColors.danger,
                  )
                : null,
            onPressed: () => Navigator.pop(context, value),
            icon: Icon(icon),
            label: Text(label),
          ),
          const SizedBox(height: 10),
        ],
        OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ],
    ),
  );
}

class _BillNameDialog extends StatefulWidget {
  const _BillNameDialog({required this.initial});

  final String initial;

  @override
  State<_BillNameDialog> createState() => _BillNameDialogState();
}

class _BillNameDialogState extends State<_BillNameDialog> {
  late final _name = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    if (_name.text.trim().isEmpty) {
      setState(() {});
      return;
    }
    Navigator.pop(context, _name.text.trim());
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: const Icon(Icons.save_outlined, size: 40, color: QsColors.maroon),
    title: const Text('Save Current Bill', textAlign: TextAlign.center),
    content: TextField(
      controller: _name,
      autofocus: true,
      textCapitalization: TextCapitalization.sentences,
      onSubmitted: (_) => _save(),
      decoration: InputDecoration(
        labelText: 'Bill name',
        errorText: _name.text.trim().isEmpty ? 'Enter a name for this bill' : null,
        suffixIcon: IconButton(
          tooltip: 'Clear name',
          icon: const Icon(Icons.close),
          onPressed: () => setState(_name.clear),
        ),
      ),
      onChanged: (_) => setState(() {}),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size(48, 44)),
        onPressed: _save,
        child: const Text('Save'),
      ),
    ],
  );
}

class _SavedDialog extends StatelessWidget {
  const _SavedDialog({required this.bill});

  final Bill bill;

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: const CircleAvatar(
      radius: 34,
      backgroundColor: QsColors.green,
      child: Icon(Icons.check, size: 40, color: Colors.white),
    ),
    title: const Text('Bill Saved Successfully!', textAlign: TextAlign.center),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          bill.name ?? '',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        Text(
          '${bill.displayNumber} · ${fmt.money2(bill.grandTotal)}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: QsColors.muted),
        ),
        const SizedBox(height: 8),
        const Text(
          'The billing area is now clear. Find this bill in Saved Bills.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: QsColors.muted),
        ),
        const SizedBox(height: 20),
        OutlinedButton(
          onPressed: () {
            Navigator.pop(context);
            Shell.go(Shell.saved);
          },
          child: const Text('View Saved Bills'),
        ),
        const SizedBox(height: 10),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Start New Bill')),
      ],
    ),
  );
}
