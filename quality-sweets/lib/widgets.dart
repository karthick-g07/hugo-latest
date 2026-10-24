import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'models.dart';
import 'store.dart';
import 'theme.dart';

/// Product or category photo, with a warm placeholder when none is set.
class QsImage extends StatelessWidget {
  const QsImage({
    super.key,
    required this.imageName,
    required this.label,
    this.size,
    this.radius = 12,
    this.icon = Icons.cake_outlined,
  });

  final String? imageName;
  final String label;
  final double? size;
  final double radius;
  final IconData icon;

  static const _assetPrefix = 'asset:';

  @override
  Widget build(BuildContext context) {
    final child =
        _photo(context) ??
        DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF7D9A8), Color(0xFFE7A65A)],
            ),
          ),
          child: SizedBox(
            width: size,
            height: size,
            child: LayoutBuilder(
              builder: (context, box) {
                final side = box.biggest.shortestSide;
                return Center(
                  child: side < 72
                      ? Text(
                          _initials(label),
                          style: TextStyle(
                            fontFamily: brandFont,
                            fontSize: (side * 0.36).roundToDouble(),
                            fontWeight: FontWeight.w700,
                            color: QsColors.maroonDark,
                          ),
                        )
                      : Icon(icon, size: side * 0.36, color: QsColors.maroonDark),
                );
              },
            ),
          ),
        );
    return Semantics(
      label: label,
      image: true,
      child: ClipRRect(borderRadius: BorderRadius.circular(radius), child: child),
    );
  }

  /// A bundled `asset:` photo, a picture saved on the device, or null.
  Widget? _photo(BuildContext context) {
    final name = imageName;
    if (name == null) return null;
    final ImageProvider provider;
    if (name.startsWith(_assetPrefix)) {
      provider = AssetImage(name.substring(_assetPrefix.length));
    } else {
      final file = context.read<AppStore>().imageFile(name);
      if (file == null) return null;
      provider = FileImage(file);
    }
    final image = Image(
      image: ResizeImage(provider, width: 800),
      fit: BoxFit.cover,
      width: size,
      height: size,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
    return size == null ? SizedBox.expand(child: image) : image;
  }

  static String _initials(String text) {
    final words = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }
}

IconData categoryIcon(Category category) => switch (category.kind) {
  CategoryKind.topRated => Icons.workspace_premium_outlined,
  CategoryKind.other => Icons.shopping_basket_outlined,
  CategoryKind.normal =>
    category.name.toLowerCase().contains('karam') ||
            category.name.toLowerCase().contains('savour') ||
            category.name.toLowerCase().contains('savor')
        ? Icons.bakery_dining_outlined
        : Icons.cake_outlined,
};

/// Round shop emblem used on the splash screen, app bars and invoices.
class QsLogo extends StatelessWidget {
  const QsLogo({super.key, this.size = 64, this.onDark = false});

  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final file = store.imageFile(store.settings.logoName);
    if (file != null) {
      return ClipOval(
        child: Image.file(file, width: size, height: size, fit: BoxFit.cover),
      );
    }
    return ClipOval(
      child: ColoredBox(
        color: Colors.white,
        child: Padding(
          padding: EdgeInsets.all(size * 0.08),
          child: Image.asset(
            'assets/brand/ganesha.png',
            width: size,
            height: size,
            fit: BoxFit.contain,
            alignment: Alignment.center,
          ),
        ),
      ),
    );
  }
}

/// Bold brand heading in the serif display face.
class BrandTitle extends StatelessWidget {
  const BrandTitle(this.text, {super.key, this.size = 22, this.color = QsColors.maroon});

  final String text;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(fontFamily: brandFont, fontSize: size, fontWeight: FontWeight.w700, color: color),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: QsColors.charcoal),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.action});

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: QsColors.creamDeep,
            child: Icon(icon, size: 40, color: QsColors.maroon),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: QsColors.muted),
          ),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    ),
  );
}

/// Asks the user to confirm an action. Resolves to true only on confirm.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
  IconData icon = Icons.help_outline,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(icon, size: 40, color: destructive ? QsColors.danger : QsColors.maroon),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(message, textAlign: TextAlign.center),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: QsColors.danger, minimumSize: const Size(48, 44))
              : FilledButton.styleFrom(minimumSize: const Size(48, 44)),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

void showMessage(BuildContext context, String message, {SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), action: action));
}

/// Opens a bottom sheet above the navigation bar that resizes for the keyboard.
Future<T?> showSheet<T>(BuildContext context, WidgetBuilder builder) => showModalBottomSheet<T>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  backgroundColor: QsColors.cream,
  constraints: const BoxConstraints(maxWidth: 640),
  builder: (context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: builder(context),
  ),
);

final decimalInput = [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}'))];

/// Labelled numeric text field with consistent keyboard behaviour.
class NumberField extends StatelessWidget {
  const NumberField({
    super.key,
    required this.controller,
    required this.label,
    this.prefix,
    this.suffix,
    this.errorText,
    this.helperText,
    this.enabled = true,
    this.autofocus = false,
    this.onChanged,
    this.large = false,
  });

  final TextEditingController controller;
  final String label;
  final String? prefix;
  final Widget? suffix;
  final String? errorText;
  final String? helperText;
  final bool enabled;
  final bool autofocus;
  final bool large;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    enabled: enabled,
    autofocus: autofocus,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: decimalInput,
    onChanged: onChanged,
    onTapOutside: (_) => FocusScope.of(context).unfocus(),
    style: TextStyle(fontSize: large ? 22 : 16, fontWeight: FontWeight.w600),
    decoration: InputDecoration(
      labelText: label,
      prefixText: prefix,
      suffixIcon: suffix,
      errorText: errorText,
      helperText: helperText,
    ),
  );
}

class TotalRow extends StatelessWidget {
  const TotalRow(this.label, this.value, {super.key, this.big = false, this.color});

  final String label;
  final String value;
  final bool big;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: big ? 20 : 14,
      fontWeight: big ? FontWeight.w800 : FontWeight.w500,
      color: color ?? (big ? QsColors.maroon : QsColors.charcoal),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
