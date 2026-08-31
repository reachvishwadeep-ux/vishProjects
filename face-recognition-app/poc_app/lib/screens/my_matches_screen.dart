import 'package:flutter/material.dart';

import '../repository/sample_set.dart';
import '../theme.dart';

class MyMatchesScreen extends StatelessWidget {
  const MyMatchesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final matches = [
      _PreviewMatch(
        name: 'Reference profile 1',
        location: 'Authorized demo images',
        time: '2 hours ago',
        yourSnap: demoPortraitAssets[1].path,
        theirSnap: demoPortraitAssets[0].path,
      ),
      _PreviewMatch(
        name: 'Reference profile 2',
        location: 'Authorized demo images',
        time: 'Yesterday, 4:15 PM',
        yourSnap: demoPortraitAssets[2].path,
        theirSnap: demoPortraitAssets[0].path,
      ),
      _PreviewMatch(
        name: 'Reference profile 3',
        location: 'Authorized demo images',
        time: '3 days ago',
        yourSnap: demoPortraitAssets[1].path,
        theirSnap: demoPortraitAssets[2].path,
      ),
      _PreviewMatch(
        name: 'Reference profile 4',
        location: 'Authorized demo images',
        time: 'Last week',
        yourSnap: demoPortraitAssets[3].path,
        theirSnap: demoPortraitAssets[1].path,
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
                    assetPath: match.yourSnap,
                    labelColor: brandInk,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SnapPreview(
                    label: 'Their Snap',
                    assetPath: match.theirSnap,
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
    required this.assetPath,
    required this.labelColor,
  });

  final String label;
  final String assetPath;
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
            Image.asset(assetPath, fit: BoxFit.cover),
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
  final String yourSnap;
  final String theirSnap;
}

void _showPrototypeMessage(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('This action will be connected in the online version.'),
    ),
  );
}
