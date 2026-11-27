import 'package:flutter/material.dart';

import '../theme.dart';

class MatchedPhotoPair extends StatelessWidget {
  const MatchedPhotoPair({
    required this.role,
    required this.myImageUrl,
    required this.otherImageUrl,
    super.key,
  });

  final String role;
  final String? myImageUrl;
  final String? otherImageUrl;

  @override
  Widget build(BuildContext context) {
    final otherLabel = role == 'missing' ? 'FOUND PHOTO' : 'MISSING PHOTO';
    return Row(
      children: [
        Expanded(
          child: _MatchedPhoto(
            label: 'YOUR PHOTO',
            imageUrl: myImageUrl,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MatchedPhoto(
            label: otherLabel,
            imageUrl: otherImageUrl,
          ),
        ),
      ],
    );
  }
}

class _MatchedPhoto extends StatelessWidget {
  const _MatchedPhoto({
    required this.label,
    required this.imageUrl,
  });

  final String label;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1.15,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: ColoredBox(
              color: brandSurfaceStrong,
              child: imageUrl == null
                  ? const Center(
                      child: Icon(
                        Icons.person_search_rounded,
                        color: brandMuted,
                        size: 30,
                      ),
                    )
                  : Image.network(
                      imageUrl!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: brandMuted,
                          size: 28,
                        ),
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: brandMuted,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: .5,
          ),
        ),
      ],
    );
  }
}
