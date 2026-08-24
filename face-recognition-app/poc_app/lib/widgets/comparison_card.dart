import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

class ComparisonCard extends StatelessWidget {
  const ComparisonCard({
    super.key,
    required this.probe,
    required this.storedPath,
  });

  final Uint8List probe;
  final String storedPath;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ImagePanel(
            label: 'Uploaded',
            image: Image.memory(probe, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ImagePanel(
            label: 'Stored',
            image: Image.file(File(storedPath), fit: BoxFit.cover),
          ),
        ),
      ],
    );
  }
}

class _ImagePanel extends StatelessWidget {
  const _ImagePanel({required this.label, required this.image});

  final String label;
  final Widget image;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: image,
          ),
        ),
      ],
    );
  }
}
