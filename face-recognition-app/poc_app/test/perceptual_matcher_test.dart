import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:poc_app/matching/perceptual_matcher.dart';
import 'package:poc_app/matching/signature.dart';
import 'package:poc_app/models.dart';

Uint8List _jpeg(img.Image image, {int quality = 90}) =>
    Uint8List.fromList(img.encodeJpg(image, quality: quality));

img.Image _shapes(int seed) {
  final image = img.Image(width: 256, height: 256);
  img.fill(image, color: img.ColorRgb8(10 + seed * 30, 40, 200 - seed * 30));
  img.fillRect(
    image,
    x1: 20 + seed * 15,
    y1: 20,
    x2: 120 + seed * 15,
    y2: 140,
    color: img.ColorRgb8(250, 240 - seed * 40, 10),
  );
  return image;
}

StoredImage _stored(String label, Uint8List bytes) => StoredImage(
      id: label,
      label: label,
      path: '/tmp/$label.jpg',
      signature: ImageSignature.fromBytes(bytes)!,
      addedAt: DateTime(2024),
    );

void main() {
  const matcher = PerceptualMatcher();

  test('decisions follow the thresholds', () {
    expect(matcher.decide(null), Decision.noMatch);
    expect(matcher.decide(matcher.reviewThreshold - 0.01), Decision.noMatch);
    expect(matcher.decide(matcher.reviewThreshold), Decision.review);
    expect(matcher.decide(matcher.matchThreshold - 0.01), Decision.review);
    expect(matcher.decide(matcher.matchThreshold), Decision.match);
    expect(matcher.decide(1.0), Decision.match);
  });

  test('an empty gallery gives no match and no candidates', () async {
    final outcome = await matcher.match(
      probe: _jpeg(_shapes(0)),
      gallery: const [],
      caseType: CaseType.missing,
      fileName: 'probe.jpg',
    );

    expect(outcome.decision, Decision.noMatch);
    expect(outcome.candidates, isEmpty);
    expect(outcome.best, isNull);
    expect(outcome.comparisons, 0);
  });

  test('undecodable uploads are rejected', () {
    expect(
      () => matcher.match(
        probe: Uint8List.fromList([9, 9, 9]),
        gallery: const [],
        caseType: CaseType.missing,
        fileName: 'probe.jpg',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('a recompressed copy of a stored image is matched and ranked first',
      () async {
    final gallery = [
      _stored('one', _jpeg(_shapes(1))),
      _stored('two', _jpeg(_shapes(2))),
      _stored('three', _jpeg(_shapes(3))),
    ];
    final probe = _jpeg(img.copyResize(_shapes(2), width: 128), quality: 60);

    final outcome = await matcher.match(
      probe: probe,
      gallery: gallery,
      caseType: CaseType.missing,
      fileName: 'probe.jpg',
    );

    expect(outcome.best!.image.label, 'two');
    expect(outcome.decision, Decision.match);
    expect(outcome.comparisons, 3);
    expect(outcome.candidates.length, 3);
  });

  test('candidates come back sorted by descending score', () async {
    final gallery = [
      for (var i = 0; i < 4; i++) _stored('$i', _jpeg(_shapes(i)))
    ];

    final outcome = await matcher.match(
      probe: _jpeg(_shapes(0)),
      gallery: gallery,
      caseType: CaseType.missing,
      fileName: 'probe.jpg',
    );
    final scores = outcome.candidates.map((c) => c.score).toList();

    expect(
        scores, orderedEquals(List.of(scores)..sort((a, b) => b.compareTo(a))));
  });

  test('topK caps the number of candidates returned', () async {
    final gallery = [
      for (var i = 0; i < 5; i++) _stored('$i', _jpeg(_shapes(i)))
    ];

    final outcome = await matcher.match(
      probe: _jpeg(_shapes(0)),
      gallery: gallery,
      caseType: CaseType.missing,
      fileName: 'probe.jpg',
      topK: 2,
    );

    expect(outcome.candidates.length, 2);
    expect(outcome.comparisons, 5);
  });
}
