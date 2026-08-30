import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import 'result_screen.dart';

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

  Future<void> _compareStored(BuildContext context, StoredImage image) async {
    final bytes = await state.demoProbe(image);
    final outcome = await state.compare(bytes);
    if (!context.mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultScreen(probe: bytes, outcome: outcome),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = state.gallery.length;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
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
              IconButton.filled(
                tooltip: 'Add image',
                onPressed: () => _addImage(context),
                icon: const Icon(Icons.add_photo_alternate_rounded),
              ),
            ],
          ),
          const SizedBox(height: 22),
          if (state.loading)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Column(
                children: [
                  Icon(Icons.hourglass_top_rounded, size: 36),
                  SizedBox(height: 12),
                  Text('Loading repository…'),
                ],
              ),
            )
          else if (state.gallery.isEmpty)
            _EmptyGallery(
                onAddDemo: state.addDemoImages,
                onAddImage: () => _addImage(context))
          else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .secondaryContainer
                    .withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                children: [
                  Icon(Icons.touch_app_rounded),
                  SizedBox(width: 10),
                  Expanded(
                      child: Text(
                          'Tap a stored image to test it as a recompressed upload.')),
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
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.82,
              ),
              itemBuilder: (context, index) {
                final image = state.gallery[index];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _compareStored(context, image),
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
                                child: IconButton.filledTonal(
                                  tooltip: 'Remove',
                                  onPressed: () => state.removeImage(image.id),
                                  icon: const Icon(Icons.delete_outline_rounded,
                                      size: 20),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(13),
                          child: Text(
                            image.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
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
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 58,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No saved images yet',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your own image or load a generated sample set. Nothing leaves this device.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAddDemo,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Add demo images'),
            ),
            TextButton(
                onPressed: onAddImage,
                child: const Text('Choose my own image')),
          ],
        ),
      ),
    );
  }
}
