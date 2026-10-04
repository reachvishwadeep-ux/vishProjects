import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class PhotoSourceBar extends StatelessWidget {
  const PhotoSourceBar({
    super.key,
    required this.onPick,
    this.enabled = true,
  });

  final void Function(ImageSource source) onPick;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: enabled ? () => onPick(ImageSource.camera) : null,
            icon: const Icon(Icons.photo_camera),
            label: const Text('Camera'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: enabled ? () => onPick(ImageSource.gallery) : null,
            icon: const Icon(Icons.photo_library),
            label: const Text('Gallery'),
          ),
        ),
      ],
    );
  }
}
