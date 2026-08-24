import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/comparison_card.dart';
import '../widgets/score_ring.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.probe,
    required this.outcome,
  });

  final Uint8List probe;
  final MatchOutcome outcome;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.outcome.decision == Decision.match) {
      HapticFeedback.mediumImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final outcome = widget.outcome;
    final best = outcome.best;
    final color = decisionColor(context, outcome.decision);

    return Scaffold(
      appBar: AppBar(title: const Text('Comparison result')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    outcome.decision == Decision.match
                        ? Icons.check_circle_rounded
                        : outcome.decision == Decision.review
                            ? Icons.help_rounded
                            : Icons.cancel_outlined,
                    color: color,
                    size: 46,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    decisionTitle(outcome.decision),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    decisionMessage(outcome.decision),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.outline),
                  ),
                  if (best != null) ...[
                    const SizedBox(height: 20),
                    ScoreRing(score: best.score, color: color),
                    const SizedBox(height: 12),
                    Text(
                      best.image.label,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (best != null) ...[
            const SizedBox(height: 20),
            Text(
              'Side-by-side',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            ComparisonCard(probe: widget.probe, storedPath: best.image.path),
          ],
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  _DetailRow(label: 'Matcher', value: outcome.matcherName),
                  const Divider(height: 24),
                  _DetailRow(label: 'Images compared', value: '${outcome.comparisons}'),
                  const Divider(height: 24),
                  _DetailRow(label: 'Finished in', value: '${outcome.duration.inMilliseconds} ms'),
                ],
              ),
            ),
          ),
          if (outcome.candidates.length > 1) ...[
            const SizedBox(height: 24),
            Text(
              'Closest candidates',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            ...outcome.candidates.skip(1).map(
                  (candidate) => Card(
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(candidate.image.path),
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.image_rounded),
                        ),
                      ),
                      title: Text(candidate.image.label),
                      trailing: Text(
                        '${(candidate.score * 100).round()}%',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
