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
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 112),
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
                                letterSpacing: -.6,
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
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: brandPurple,
                ),
                icon: const Icon(Icons.tune_rounded),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.fromLTRB(17, 16, 14, 16),
            decoration: BoxDecoration(
              gradient: brandGradient,
              borderRadius: BorderRadius.circular(23),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x297057F5),
                  blurRadius: 22,
                  offset: Offset(0, 9),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .16),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${matches.length} possible connections',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Photos paired for this visual prototype',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .75),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ...matches.map(
            (match) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
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
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: brandLavender,
                  backgroundImage: AssetImage(match.theirSnap),
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
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: brandLavender,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    match.time,
                    style: const TextStyle(
                      color: brandPurple,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Stack(
              alignment: Alignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _SnapPreview(
                        label: 'YOUR SNAP',
                        assetPath: match.yourSnap,
                        labelColor: brandInk,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SnapPreview(
                        label: 'FOUND SNAP',
                        assetPath: match.theirSnap,
                        labelColor: brandPurple,
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    gradient: brandGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x337057F5),
                        blurRadius: 13,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.link_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => _showPrototypeMessage(context),
                    icon:
                        const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                    label: const Text('Chat Now'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      backgroundColor: brandLavender,
                      foregroundColor: brandPurple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
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
      aspectRatio: 1.3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(assetPath, fit: BoxFit.cover),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Color(0x66000000)],
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: labelColor.withValues(alpha: .88),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .3,
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
