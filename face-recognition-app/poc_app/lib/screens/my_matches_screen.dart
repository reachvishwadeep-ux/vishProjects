import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../repository/sample_set.dart';
import '../theme.dart';

class MyMatchesScreen extends StatelessWidget {
  const MyMatchesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final samples = buildDemoSet();
    final matches = [
      _PreviewMatch(
        name: 'Marcus Aurelius',
        location: 'San Francisco, CA',
        time: '2 hours ago',
        yourSnap: samples[0].bytes,
        theirSnap: samples[0].bytes,
      ),
      _PreviewMatch(
        name: 'Sarah Jenkins',
        location: 'Denver, CO',
        time: 'Yesterday, 4:15 PM',
        yourSnap: samples[1].bytes,
        theirSnap: samples[1].bytes,
      ),
      _PreviewMatch(
        name: 'Kenji Sato',
        location: 'Tokyo, JP',
        time: '3 days ago',
        yourSnap: samples[2].bytes,
        theirSnap: samples[2].bytes,
      ),
    ];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Matches',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Previewing ${matches.length} possible connections',
                      style: const TextStyle(color: brandMuted),
                    ),
                  ],
                ),
              ),
              IconButton.outlined(
                tooltip: 'Filter matches',
                onPressed: () => _showPrototypeMessage(context),
                icon: const Icon(Icons.tune_rounded),
              ),
            ],
          ),
          const SizedBox(height: 22),
          ...matches.map(
            (match) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _MatchPreviewCard(match: match),
            ),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Text(
              'Mock data for visual prototype',
              style: TextStyle(
                color: brandMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchPreviewCard extends StatelessWidget {
  const _MatchPreviewCard({required this.match});

  final _PreviewMatch match;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: brandLavender,
                  child: Text(
                    match.name.split(' ').take(2).map((part) => part[0]).join(),
                    style: const TextStyle(
                      color: brandPurple,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        match.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        match.location,
                        style: const TextStyle(
                          color: brandMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  match.time,
                  style: const TextStyle(color: brandMuted, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: _SnapPreview(
                    label: 'Your Snap',
                    bytes: match.yourSnap,
                    labelColor: brandInk,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SnapPreview(
                    label: 'Their Snap',
                    bytes: match.theirSnap,
                    labelColor: brandPurple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => _showPrototypeMessage(context),
                    icon:
                        const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                    label: const Text('Chat Now'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 42),
                      backgroundColor: brandLavender,
                      foregroundColor: brandPurple,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'More',
                  onPressed: () => _showPrototypeMessage(context),
                  icon: const Icon(Icons.more_horiz_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SnapPreview extends StatelessWidget {
  const _SnapPreview({
    required this.label,
    required this.bytes,
    required this.labelColor,
  });

  final String label;
  final Uint8List bytes;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.65,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(bytes, fit: BoxFit.cover),
            Positioned(
              left: 7,
              top: 7,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: labelColor.withValues(alpha: .84),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewMatch {
  const _PreviewMatch({
    required this.name,
    required this.location,
    required this.time,
    required this.yourSnap,
    required this.theirSnap,
  });

  final String name;
  final String location;
  final String time;
  final Uint8List yourSnap;
  final Uint8List theirSnap;
}

void _showPrototypeMessage(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('This action will be connected in the online version.'),
    ),
  );
}
