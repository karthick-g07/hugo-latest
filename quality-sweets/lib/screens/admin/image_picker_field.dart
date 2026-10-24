import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../store.dart';
import '../../theme.dart';
import '../../widgets.dart';

/// Tappable image slot that picks a photo from the camera or gallery,
/// resized so local storage stays small.
class ImagePickerField extends StatelessWidget {
  const ImagePickerField({
    super.key,
    required this.imageName,
    required this.label,
    required this.onChanged,
    this.size = 120,
    this.circle = false,
  });

  final String? imageName;
  final String label;
  final ValueChanged<String?> onChanged;
  final double size;
  final bool circle;

  Future<void> _pick(BuildContext context) async {
    final store = context.read<AppStore>();
    final source = await showSheet<Object>(
      context,
      (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(sheet, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(sheet, ImageSource.gallery),
            ),
            if (imageName != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: QsColors.danger),
                title: const Text('Remove image', style: TextStyle(color: QsColors.danger)),
                onTap: () => Navigator.pop(sheet, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (source == null || !context.mounted) return;
    if (source == 'remove') {
      onChanged(null);
      return;
    }
    try {
      final file = await ImagePicker().pickImage(
        source: source as ImageSource,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );
      if (file == null) return;
      final extension = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : 'jpg';
      onChanged(await store.saveImage(await file.readAsBytes(), extension));
    } catch (error) {
      if (context.mounted) showMessage(context, 'Could not use that image. Check photo permissions.');
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: imageName == null ? 'Add image' : 'Change image',
    child: InkWell(
      borderRadius: BorderRadius.circular(circle ? size : 16),
      onTap: () => _pick(context),
      child: Stack(
        children: [
          imageName == null
              ? Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: circle ? BoxShape.circle : BoxShape.rectangle,
                    borderRadius: circle ? null : BorderRadius.circular(16),
                    border: Border.all(color: QsColors.border, width: 1.5),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined, color: QsColors.maroon, size: 32),
                      SizedBox(height: 6),
                      Text('Add image', style: TextStyle(fontSize: 12, color: QsColors.muted)),
                    ],
                  ),
                )
              : QsImage(imageName: imageName, label: label, size: size, radius: circle ? size : 16),
          if (imageName != null)
            const Positioned(
              right: 6,
              bottom: 6,
              child: CircleAvatar(
                radius: 16,
                backgroundColor: QsColors.maroon,
                child: Icon(Icons.edit, size: 16, color: Colors.white),
              ),
            ),
        ],
      ),
    ),
  );
}
