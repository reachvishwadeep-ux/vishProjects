import 'dart:typed_data';

import 'package:image/image.dart' as img;

class DemoImage {
  const DemoImage({required this.label, required this.bytes});

  final String label;
  final Uint8List bytes;
}

List<DemoImage> buildDemoSet() {
  return [
    DemoImage(
      label: 'Amber Ridge',
      bytes: _encode(
        background: const [29, 33, 54],
        accent: const [247, 180, 68],
        secondary: const [244, 105, 76],
        variant: 0,
      ),
    ),
    DemoImage(
      label: 'Cobalt Current',
      bytes: _encode(
        background: const [17, 54, 86],
        accent: const [45, 189, 207],
        secondary: const [86, 116, 235],
        variant: 1,
      ),
    ),
    DemoImage(
      label: 'Emerald Field',
      bytes: _encode(
        background: const [18, 63, 54],
        accent: const [71, 204, 137],
        secondary: const [219, 232, 95],
        variant: 2,
      ),
    ),
    DemoImage(
      label: 'Violet Orbit',
      bytes: _encode(
        background: const [48, 27, 76],
        accent: const [172, 112, 239],
        secondary: const [240, 91, 154],
        variant: 3,
      ),
    ),
  ];
}

Uint8List buildUnknownDemo() {
  final image = img.Image(width: 720, height: 720);
  img.fill(image, color: img.ColorRgb8(236, 239, 245));
  for (var i = 0; i < 8; i++) {
    img.drawLine(
      image,
      x1: i * 105 - 80,
      y1: 0,
      x2: i * 105 + 250,
      y2: 720,
      color: img.ColorRgb8(40, 47, 62),
      thickness: 18,
    );
  }
  img.fillCircle(
    image,
    x: 360,
    y: 360,
    radius: 118,
    color: img.ColorRgb8(249, 205, 61),
  );
  return Uint8List.fromList(img.encodeJpg(image, quality: 90));
}

Uint8List makeProbeCopy(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    return bytes;
  }
  final resized = img.copyResize(decoded, width: 420);
  return Uint8List.fromList(img.encodeJpg(resized, quality: 62));
}

Uint8List _encode({
  required List<int> background,
  required List<int> accent,
  required List<int> secondary,
  required int variant,
}) {
  final image = img.Image(width: 720, height: 720);
  img.fill(image,
      color: img.ColorRgb8(background[0], background[1], background[2]));

  final offset = variant * 28;
  img.fillRect(
    image,
    x1: 70 + offset,
    y1: 80,
    x2: 430 + offset,
    y2: 420,
    color: img.ColorRgb8(accent[0], accent[1], accent[2]),
  );
  img.fillCircle(
    image,
    x: 500 - offset,
    y: 480,
    radius: 145,
    color: img.ColorRgb8(secondary[0], secondary[1], secondary[2]),
  );
  img.drawLine(
    image,
    x1: 80,
    y1: 610 - offset,
    x2: 630,
    y2: 130 + offset,
    color: img.ColorRgb8(250, 250, 250),
    thickness: 22,
  );
  return Uint8List.fromList(img.encodeJpg(image, quality: 92));
}
