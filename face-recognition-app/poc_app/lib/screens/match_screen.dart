import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_state.dart';
import '../repository/sample_set.dart';
import '../theme.dart';
import 'active_upload_screen.dart';

class MatchScreen extends StatelessWidget {
  const MatchScreen({super.key, required this.state});

  final AppState state;

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 92,
      maxWidth: 1800,
    );
    if (picked == null) {
      return;
    }
    final bytes = await picked.readAsBytes();
    if (!context.mounted) {
      return;
    }
    _openActiveUpload(context, bytes, picked.name);
  }

  void _openActiveUpload(
    BuildContext context,
    Uint8List bytes,
    String fileName,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActiveUploadScreen(
          state: state,
          probe: bytes,
          fileName: fileName,
        ),
      ),
    );
  }

  Future<void> _tryMatch(BuildContext context) async {
    await state.addDemoImages();
    if (!context.mounted || state.gallery.isEmpty) {
      return;
    }
    final reference = state.gallery.firstWhere(
      (image) => image.label == demoPortraitAssets.first.label,
      orElse: () => state.gallery.first,
    );
    final bytes = await state.demoProbe(reference);
    if (context.mounted) {
      _openActiveUpload(context, bytes, 'reference-portrait-match.jpg');
    }
  }

  void _showHowItWorks(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => const Padding(
        padding: EdgeInsets.fromLTRB(24, 4, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How this prototype works',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 12),
            Text(
              'Choose a photo, compare it with the local demo gallery, and preview the future MatchSnap connection experience.',
              style: TextStyle(color: brandMuted, height: 1.5),
            ),
            SizedBox(height: 12),
            Text(
              'Continuous online matching, alerts, chat, and contact sharing are visual concepts only.',
              style: TextStyle(color: brandMuted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6557E8), Color(0xFF9B5CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.cancel_outlined,
                  color: Colors.white,
                  size: 19,
                ),
              ),
              const SizedBox(width: 9),
              const Text(
                'MatchSnap',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _showHowItWorks(context),
                style: TextButton.styleFrom(
                  backgroundColor: brandLavender,
                  foregroundColor: brandPurple,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: const Text(
                  'How it works',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            'Upload. Match.\nConnect.',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.02,
                  letterSpacing: -.7,
                ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Share a snapshot of your moment. We’ll compare it with the demo gallery and preview how an exact match could connect people.',
            style: TextStyle(color: brandMuted, height: 1.45),
          ),
          const SizedBox(height: 22),
          GestureDetector(
            onTap: state.matching
                ? null
                : () => _pick(context, ImageSource.gallery),
            child: CustomPaint(
              foregroundPainter: const _DashedBorderPainter(),
              child: Container(
                height: 166,
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: const BoxDecoration(
                        color: brandLavender,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.hide_image_outlined,
                        color: brandPurple,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'Select a photograph',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Tap here or choose a source below',
                      style: TextStyle(color: Color(0xFFA0A4B2), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _GradientButton(
            onPressed: state.matching
                ? null
                : () => _pick(context, ImageSource.gallery),
            icon: Icons.photo_library_outlined,
            label: 'Choose from Gallery',
          ),
          TextButton.icon(
            onPressed: state.matching
                ? null
                : () => _pick(context, ImageSource.camera),
            icon: const Icon(Icons.camera_alt_outlined, size: 18),
            label: const Text('Use camera instead'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Why MatchSnap?',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 9),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, color: brandPurple),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Safe & Anonymous',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Contact details are shown only in this visual prototype.',
                          style: TextStyle(color: brandMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F2FF),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Prototype previews',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed:
                            state.loading ? null : () => _tryMatch(context),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 42),
                          backgroundColor: Colors.white,
                          foregroundColor: brandPurple,
                        ),
                        child: const Text('Preview match'),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: state.loading
                            ? null
                            : () => _openActiveUpload(
                                  context,
                                  buildUnknownDemo(),
                                  'demo-no-match.jpg',
                                ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 42),
                          backgroundColor: Colors.white,
                          foregroundColor: brandInk,
                        ),
                        child: const Text('Preview no match'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: onPressed == null
            ? null
            : const LinearGradient(
                colors: [Color(0xFF6257E8), Color(0xFF9258F1)],
              ),
        color: onPressed == null ? const Color(0xFFD5D3DE) : null,
        borderRadius: BorderRadius.circular(13),
      ),
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = brandPurple
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(18),
        ),
      );

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = distance + 8 < metric.length ? distance + 8 : metric.length;
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += 13;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
