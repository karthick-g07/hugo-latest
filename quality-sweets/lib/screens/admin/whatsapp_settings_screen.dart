import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../format.dart' as fmt;
import '../../store.dart';
import '../../theme.dart';
import '../../widgets.dart';

/// Owner WhatsApp numbers that a saved bill can also be forwarded to.
/// WhatsApp never sends automatically here — the cashier still opens each
/// chat and taps send, the same manual-confirm flow as the customer send.
class WhatsAppSettingsScreen extends StatefulWidget {
  const WhatsAppSettingsScreen({super.key});

  @override
  State<WhatsAppSettingsScreen> createState() => _WhatsAppSettingsScreenState();
}

class _WhatsAppSettingsScreenState extends State<WhatsAppSettingsScreen> {
  late final AppStore _store = context.read<AppStore>();
  late bool _notify = _store.settings.notifyOwnerOnShare;
  late final List<String> _numbers = [..._store.settings.ownerWhatsAppNumbers];
  late final _number = TextEditingController();
  bool _submitted = false;

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  void _addNumber() {
    final normalised = fmt.normalisePhone(_number.text);
    setState(() => _submitted = true);
    if (normalised == null || _numbers.contains(normalised)) return;
    setState(() {
      _numbers.add(normalised);
      _number.clear();
      _submitted = false;
    });
  }

  void _save() {
    _store.updateSettings(
      (s) => s
        ..notifyOwnerOnShare = _notify
        ..ownerWhatsAppNumbers = _numbers,
    );
    Navigator.pop(context);
    showMessage(context, 'WhatsApp settings saved');
  }

  @override
  Widget build(BuildContext context) {
    final error = _submitted && fmt.normalisePhone(_number.text) == null
        ? 'Enter a valid number with country code, e.g. +91 98765 43210'
        : null;
    return Scaffold(
      appBar: AppBar(title: const Text('WhatsApp Settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Also send bills to shop owner'),
                subtitle: const Text(
                  'After sharing a bill on WhatsApp, offer to open it for the owner numbers below too.',
                ),
                value: _notify,
                onChanged: (v) => setState(() => _notify = v),
              ),
              const SectionTitle('Owner WhatsApp numbers'),
              if (_numbers.isEmpty)
                const Text('No owner numbers added yet.', style: TextStyle(color: QsColors.muted))
              else
                for (final number in _numbers)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: const Icon(Icons.chat_outlined, color: QsColors.maroon),
                      title: Text(fmt.displayPhone(number)),
                      trailing: IconButton(
                        tooltip: 'Remove',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => setState(() => _numbers.remove(number)),
                      ),
                    ),
                  ),
              const SizedBox(height: 10),
              TextField(
                controller: _number,
                keyboardType: TextInputType.phone,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _addNumber(),
                decoration: InputDecoration(
                  labelText: 'Add owner number',
                  hintText: '+91 98765 43210',
                  errorText: error,
                  suffixIcon: IconButton(tooltip: 'Add', icon: const Icon(Icons.add), onPressed: _addNumber),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'You can add more than one owner number. WhatsApp still requires a manual tap to send — '
                'this app never sends a message by itself.',
                style: TextStyle(fontSize: 12, color: QsColors.muted),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(onPressed: _save, child: const Text('Save')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
