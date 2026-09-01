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
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 112),
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: brandGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x3D7057F5),
                      blurRadius: 14,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.join_inner_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 11),
              const Text(
                'MatchSnap',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.4,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'How it works',
                onPressed: () => _showHowItWorks(context),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: brandPurple,
                  side: const BorderSide(color: brandBorder),
                ),
                icon: const Icon(Icons.help_outline_rounded, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 21),
            decoration: BoxDecoration(
              gradient: brandGradient,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x367057F5),
                  blurRadius: 28,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .18),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        color: Colors.white,
                        size: 13,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'PRIVATE · ON DEVICE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .7,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Upload. Match.\nConnect.',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        height: .98,
                        letterSpacing: -1.1,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Find the same moment in your private photo collection.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .82),
                    height: 1.45,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 18),
                const Row(
                  children: [
                    _HeroFact(icon: Icons.bolt_rounded, label: 'Fast scan'),
                    SizedBox(width: 9),
                    _HeroFact(
                      icon: Icons.cloud_off_outlined,
                      label: 'No upload',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: GestureDetector(
                onTap: state.matching
                    ? null
                    : () => _pick(context, ImageSource.gallery),
                child: CustomPaint(
                  foregroundPainter: const _DashedBorderPainter(),
                  child: Container(
                    height: 152,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: brandSoftGradient,
                      borderRadius: BorderRadius.circular(19),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: brandBorder),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x1F7057F5),
                                blurRadius: 16,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.add_photo_alternate_outlined,
                            color: brandPurple,
                            size: 27,
                          ),
                        ),
                        const SizedBox(height: 13),
                        const Text(
                          'Select a photograph',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'JPG or PNG from your device',
                          style: TextStyle(color: brandMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _GradientButton(
            onPressed: state.matching
                ? null
                : () => _pick(context, ImageSource.gallery),
            icon: Icons.photo_library_outlined,
            label: 'Choose from Gallery',
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: state.matching
                      ? null
                      : () => _pick(context, ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined, size: 19),
                  label: const Text('Take a photo'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: state.loading ? null : () => _tryMatch(context),
                  icon: const Icon(Icons.play_circle_outline_rounded, size: 19),
                  label: const Text('Preview match'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Why MatchSnap?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 11),
          const Row(
            children: [
              Expanded(
                child: _BenefitCard(
                  icon: Icons.shield_outlined,
                  title: 'Private',
                  description: 'Photos stay on your device',
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _BenefitCard(
                  icon: Icons.auto_awesome_outlined,
                  title: 'Simple',
                  description: 'One tap to compare',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 15, 12, 15),
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
                    Icons.science_outlined,
                    color: brandPurple,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Try the other result',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Preview the no-match experience',
                        style: TextStyle(color: brandMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Preview no match',
                  onPressed: state.loading
                      ? null
                      : () => _openActiveUpload(
                            context,
                            buildUnknownDemo(),
                            'demo-no-match.jpg',
                          ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: brandPurple,
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroFact extends StatelessWidget {
  const _HeroFact({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitCard extends StatelessWidget {
  const _BenefitCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: brandBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12382E64),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: brandLavender,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: brandPurple, size: 19),
          ),
          const SizedBox(height: 11),
          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(
            description,
            style: const TextStyle(
              color: brandMuted,
              fontSize: 11,
              height: 1.3,
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
