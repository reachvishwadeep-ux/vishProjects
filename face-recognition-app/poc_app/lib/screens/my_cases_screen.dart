import 'package:flutter/material.dart';

import '../repository/case_repository.dart';
import '../theme.dart';
import '../widgets/matched_photo_pair.dart';

class MyCasesScreen extends StatefulWidget {
  const MyCasesScreen({
    super.key,
    this.repository,
    this.active = true,
  });

  final CaseRepository? repository;
  final bool active;

  @override
  State<MyCasesScreen> createState() => _MyCasesScreenState();
}

class _MyCasesScreenState extends State<MyCasesScreen> {
  var _loading = false;
  String? _error;
  List<UploadedCase> _cases = const [];

  @override
  void initState() {
    super.initState();
    if (widget.active) _load();
  }

  @override
  void didUpdateWidget(covariant MyCasesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _load();
  }

  Future<void> _load() async {
    final repository = widget.repository;
    if (repository == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = null;
          _cases = const [];
        });
      }
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cases = await repository.list();
      if (!mounted) return;
      setState(() => _cases = cases);
    } on CaseRepositoryException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 112),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cases',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -.6,
                            ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Photos submitted for ongoing missing and found searches',
                        style: TextStyle(color: brandMuted),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Refresh cases',
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (_loading)
              const _StateCard(
                child: Column(
                  children: [
                    CircularProgressIndicator(color: brandPurple),
                    SizedBox(height: 14),
                    Text(
                      'Loading your uploaded cases…',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              )
            else if (_error != null)
              _StateCard(
                child: Column(
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      color: brandGreen,
                      size: 38,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              )
            else if (_cases.isEmpty)
              const _StateCard(
                child: Column(
                  children: [
                    Icon(
                      Icons.folder_open_rounded,
                      color: brandPurple,
                      size: 42,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'No uploaded cases yet',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Submit missing- or found-person photos from Home. '
                      'They will appear here while ReuniteNow keeps searching.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: brandMuted),
                    ),
                  ],
                ),
              )
            else ...[
              for (final uploadedCase in _cases) ...[
                _CaseCard(uploadedCase: uploadedCase),
                const SizedBox(height: 14),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _CaseCard extends StatelessWidget {
  const _CaseCard({required this.uploadedCase});

  final UploadedCase uploadedCase;

  @override
  Widget build(BuildContext context) {
    final isMissing = uploadedCase.caseType == 'missing';
    final hasMatch = uploadedCase.matchState == 'potential_match';
    final accent = isMissing ? brandPurple : brandGreen;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 15, 15, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    isMissing ? 'MISSING PERSON' : 'FOUND PERSON',
                    style: TextStyle(
                      color: accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .4,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDate(uploadedCase.createdAt),
                  style: const TextStyle(
                    color: brandMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Text(
              uploadedCase.subjectLabel,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 142,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: uploadedCase.photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final photo = uploadedCase.photos[index];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: SizedBox(
                      width: 118,
                      child: Image.network(
                        photo.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: brandLavender,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: brandMuted,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            if (uploadedCase.hasMatchedPhotoPair) ...[
              const Text(
                'MATCHED PAIR',
                style: TextStyle(
                  color: brandMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .5,
                ),
              ),
              const SizedBox(height: 8),
              MatchedPhotoPair(
                role: uploadedCase.caseType,
                myImageUrl: uploadedCase.myImageUrl,
                otherImageUrl: uploadedCase.otherImageUrl,
              ),
              const SizedBox(height: 14),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: hasMatch
                    ? brandGreen.withValues(alpha: .08)
                    : brandLavender,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    hasMatch
                        ? Icons.favorite_rounded
                        : Icons.manage_search_rounded,
                    color: hasMatch ? brandGreen : brandPurple,
                    size: 20,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      hasMatch
                          ? '${uploadedCase.matchCount} potential '
                              '${uploadedCase.matchCount == 1 ? 'match' : 'matches'} found'
                          : 'Searching for potential matches',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: child,
      ),
    );
  }
}

String _formatDate(DateTime value) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[value.month - 1]} ${value.day}, ${value.year}';
}
