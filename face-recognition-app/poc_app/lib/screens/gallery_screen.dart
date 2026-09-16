import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_state.dart';
import '../theme.dart';

class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key, required this.state});

  final AppState state;

  Future<void> _addImage(BuildContext context) async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 94);
    if (picked == null || !context.mounted) {
      return;
    }

    final controller = TextEditingController(
      text: picked.name.replaceFirst(RegExp(r'\.[^.]+$'), ''),
    );
    final label = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Name this image'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Label'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Store image'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (label == null) {
      return;
    }

    final image =
        await state.addImage(bytes: await picked.readAsBytes(), label: label);
    if (image == null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('That file could not be decoded as an image.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = state.gallery.length;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 112),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Saved Info',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -.6,
                              ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$count saved ${count == 1 ? 'image' : 'images'} · on this device',
                      style: const TextStyle(color: brandMuted),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: brandGradient,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x297057F5),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: IconButton(
                  tooltip: 'Add image',
                  onPressed: () => _addImage(context),
                  color: Colors.white,
                  icon: const Icon(Icons.add_photo_alternate_rounded),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (state.loading)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: Column(
                  children: [
                    CircularProgressIndicator(color: brandPurple),
                    SizedBox(height: 16),
                    Text(
                      'Loading repository…',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            )
          else if (state.gallery.isEmpty)
            _EmptyGallery(
                onAddDemo: state.addDemoImages,
                onAddImage: () => _addImage(context))
          else ...[
            Container(
              padding: const EdgeInsets.fromLTRB(15, 14, 14, 14),
              decoration: BoxDecoration(
                color: brandLavender,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE3DFFF)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.touch_app_rounded,
                      color: brandPurple,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 11),
                  const Expanded(
                    child: Text(
                      'Saved images stay on this device and are not used for matching.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: count,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.76,
              ),
              itemBuilder: (context, index) {
                final image = state.gallery[index];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.file(File(image.path), fit: BoxFit.cover),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: brandInk.withValues(alpha: .72),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    tooltip: 'Remove',
                                    onPressed: () =>
                                        state.removeImage(image.id),
                                    color: Colors.white,
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 9,
                                bottom: 9,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: brandInk.withValues(alpha: .72),
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.lock_outline_rounded,
                                        color: Colors.white,
                                        size: 11,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'LOCAL',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: .4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 11, 10, 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  image.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: brandPurple,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Clear repository?'),
                    content: const Text(
                        'All stored images and cached signatures will be deleted.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await state.clear();
                }
              },
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('Clear repository'),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyGallery extends StatelessWidget {
  const _EmptyGallery({required this.onAddDemo, required this.onAddImage});

  final VoidCallback onAddDemo;
  final VoidCallback onAddImage;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 30, 26, 27),
        child: Column(
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: const BoxDecoration(
                gradient: brandGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x337057F5),
                    blurRadius: 19,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.photo_library_outlined,
                size: 34,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 19),
            Text(
              'No saved images yet',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your own image or load the authorized reference set. Nothing leaves this device.',
              textAlign: TextAlign.center,
              style: TextStyle(color: brandMuted, height: 1.45),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: onAddDemo,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Add reference photos'),
            ),
            const SizedBox(height: 5),
            TextButton.icon(
              onPressed: onAddImage,
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: const Text('Choose my own image'),
            ),
          ],
        ),
      ),
    );
  }
}
