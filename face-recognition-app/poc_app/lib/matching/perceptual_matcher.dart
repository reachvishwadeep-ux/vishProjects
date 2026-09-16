import 'dart:typed_data';

import '../models.dart';
import 'matcher.dart';
import 'signature.dart';

class PerceptualMatcher implements Matcher {
  const PerceptualMatcher({
    this.matchThreshold = 0.90,
    this.reviewThreshold = 0.78,
  });

  final double matchThreshold;
  final double reviewThreshold;

  @override
  String get name => 'Perceptual hash (on-device)';

  Decision decide(double? score) {
    if (score == null || score < reviewThreshold) {
      return Decision.noMatch;
    }
    if (score < matchThreshold) {
      return Decision.review;
    }
    return Decision.match;
  }

  @override
  Future<MatchOutcome> match({
    required Uint8List probe,
    required List<StoredImage> gallery,
    required CaseType caseType,
    required String fileName,
    int topK = 5,
  }) async {
    final stopwatch = Stopwatch()..start();
    final signature = ImageSignature.fromBytes(probe);
    if (signature == null) {
      throw const FormatException(
          'The selected file is not a supported image.');
    }

    final candidates = gallery.map((stored) {
      final structure = signature.hashSimilarity(stored.signature);
      final colour = signature.colourSimilarity(stored.signature);
      return MatchCandidate(
        image: stored,
        score: structure * 0.75 + colour * 0.25,
        structureScore: structure,
        colourScore: colour,
      );
    }).toList()
      ..sort((left, right) => right.score.compareTo(left.score));

    stopwatch.stop();
    return MatchOutcome(
      decision: decide(candidates.isEmpty ? null : candidates.first.score),
      candidates: candidates.take(topK).toList(),
      matcherName: name,
      duration: stopwatch.elapsed,
      comparisons: gallery.length,
    );
  }
}
