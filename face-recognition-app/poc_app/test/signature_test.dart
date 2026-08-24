import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:poc_app/matching/signature.dart';

Uint8List _jpeg(img.Image image, {int quality = 90}) =>
    Uint8List.fromList(img.encodeJpg(image, quality: quality));

img.Image _gradient({int size = 256, int shift = 0}) {
  final image = img.Image(width: size, height: size);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      image.setPixel(
        x,
        y,
        img.ColorRgb8((x + shift) % 256, (y + shift) % 256, ((x + y) ~/ 2) % 256),
      );
    }
  }
  return image;
}

img.Image _blocks({int size = 256}) {
  final image = img.Image(width: size, height: size);
  img.fill(image, color: img.ColorRgb8(20, 20, 20));
  img.fillRect(
    image,
    x1: 10,
    y1: 10,
    x2: size ~/ 2,
    y2: size ~/ 2,
    color: img.ColorRgb8(240, 30, 30),
  );
  img.fillCircle(
    image,
    x: (size * 3) ~/ 4,
    y: (size * 3) ~/ 4,
    radius: size ~/ 6,
    color: img.ColorRgb8(30, 30, 240),
  );
  return image;
}

void main() {
  test('undecodable bytes yield no signature', () {
    expect(ImageSignature.fromBytes(Uint8List.fromList([1, 2, 3, 4])), isNull);
  });

  test('an image is identical to itself', () {
    final signature = ImageSignature.fromBytes(_jpeg(_blocks()))!;
    expect(signature.hashSimilarity(signature), 1.0);
    expect(signature.colourSimilarity(signature), closeTo(1.0, 1e-6));
  });

  test('a resized, recompressed copy still scores as a near duplicate', () {
    final original = _blocks();
    final probe = _jpeg(img.copyResize(original, width: 128), quality: 60);

    final stored = ImageSignature.fromBytes(_jpeg(original))!;
    final uploaded = ImageSignature.fromBytes(probe)!;

    expect(uploaded.hashSimilarity(stored), greaterThan(0.9));
    expect(uploaded.colourSimilarity(stored), greaterThan(0.9));
  });

  test('structurally different images score lower than near duplicates', () {
    final blocks = ImageSignature.fromBytes(_jpeg(_blocks()))!;
    final gradient = ImageSignature.fromBytes(_jpeg(_gradient()))!;
    final blocksCopy = ImageSignature.fromBytes(
      _jpeg(img.copyResize(_blocks(), width: 96), quality: 55),
    )!;

    expect(
      blocks.hashSimilarity(gradient),
      lessThan(blocks.hashSimilarity(blocksCopy)),
    );
  });

  test('similarity is symmetric', () {
    final a = ImageSignature.fromBytes(_jpeg(_blocks()))!;
    final b = ImageSignature.fromBytes(_jpeg(_gradient()))!;

    expect(a.hashSimilarity(b), b.hashSimilarity(a));
    expect(a.colourSimilarity(b), closeTo(b.colourSimilarity(a), 1e-9));
  });

  test('hash similarity stays within bounds', () {
    final a = ImageSignature.fromBytes(_jpeg(_blocks()))!;
    final b = ImageSignature.fromBytes(_jpeg(_gradient(shift: 128)))!;

    expect(a.hashSimilarity(b), inInclusiveRange(0.0, 1.0));
    expect(a.colourSimilarity(b), inInclusiveRange(0.0, 1.0));
  });
}
