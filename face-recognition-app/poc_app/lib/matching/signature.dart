import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

class ImageSignature {
  const ImageSignature({
    required this.dHash,
    required this.pHash,
    required this.colourHistogram,
  });

  final List<int> dHash;
  final List<int> pHash;
  final List<double> colourHistogram;

  static ImageSignature? fromBytes(Uint8List bytes) {
    final img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (_) {
      return null;
    }
    if (decoded == null) {
      return null;
    }

    return ImageSignature(
      dHash: _differenceHash(decoded),
      pHash: _perceptualHash(decoded),
      colourHistogram: _histogram(decoded),
    );
  }

  double hashSimilarity(ImageSignature other) {
    final dSimilarity = _bitSimilarity(dHash, other.dHash);
    final pSimilarity = _bitSimilarity(pHash, other.pHash);
    return ((dSimilarity + pSimilarity) / 2).clamp(0.0, 1.0);
  }

  double colourSimilarity(ImageSignature other) {
    if (colourHistogram.length != other.colourHistogram.length) {
      return 0;
    }

    var intersection = 0.0;
    for (var i = 0; i < colourHistogram.length; i++) {
      intersection += math.min(colourHistogram[i], other.colourHistogram[i]);
    }
    return intersection.clamp(0.0, 1.0);
  }

  Map<String, Object> toJson() => {
        'dHash': dHash,
        'pHash': pHash,
        'colourHistogram': colourHistogram,
      };

  factory ImageSignature.fromJson(Map<String, Object?> json) {
    return ImageSignature(
      dHash: (json['dHash']! as List<Object?>)
          .cast<num>()
          .map((value) => value.toInt())
          .toList(),
      pHash: (json['pHash']! as List<Object?>)
          .cast<num>()
          .map((value) => value.toInt())
          .toList(),
      colourHistogram: (json['colourHistogram']! as List<Object?>)
          .cast<num>()
          .map((value) => value.toDouble())
          .toList(),
    );
  }

  static List<int> _differenceHash(img.Image source) {
    final grayscale =
        img.grayscale(img.copyResize(source, width: 9, height: 8));
    final bits = <int>[];

    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        bits.add(grayscale.getPixel(x, y).r > grayscale.getPixel(x + 1, y).r
            ? 1
            : 0);
      }
    }
    return bits;
  }

  static List<int> _perceptualHash(img.Image source) {
    final grayscale =
        img.grayscale(img.copyResize(source, width: 32, height: 32));
    final pixels = List.generate(
      32,
      (y) => List.generate(32, (x) => grayscale.getPixel(x, y).r.toDouble()),
    );
    final coefficients = <double>[];

    for (var v = 0; v < 8; v++) {
      for (var u = 0; u < 8; u++) {
        var sum = 0.0;
        for (var y = 0; y < 32; y++) {
          for (var x = 0; x < 32; x++) {
            sum += pixels[y][x] *
                math.cos(((2 * x + 1) * u * math.pi) / 64) *
                math.cos(((2 * y + 1) * v * math.pi) / 64);
          }
        }
        coefficients.add(sum);
      }
    }

    final values = coefficients.sublist(1)..sort();
    final median = values[values.length ~/ 2];
    return coefficients.map((value) => value >= median ? 1 : 0).toList();
  }

  static List<double> _histogram(img.Image source) {
    final resized = img.copyResize(source, width: 96, height: 96);
    final bins = List<double>.filled(64, 0);

    for (final pixel in resized) {
      final red = (pixel.r.toInt() * 4 ~/ 256).clamp(0, 3);
      final green = (pixel.g.toInt() * 4 ~/ 256).clamp(0, 3);
      final blue = (pixel.b.toInt() * 4 ~/ 256).clamp(0, 3);
      bins[red * 16 + green * 4 + blue]++;
    }

    final total = resized.width * resized.height;
    return bins.map((value) => value / total).toList();
  }

  static double _bitSimilarity(List<int> left, List<int> right) {
    if (left.length != right.length || left.isEmpty) {
      return 0;
    }

    var differences = 0;
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) {
        differences++;
      }
    }
    return 1 - differences / left.length;
  }
}
