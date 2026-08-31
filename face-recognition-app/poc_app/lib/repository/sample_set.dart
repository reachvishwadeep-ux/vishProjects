import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

class DemoAsset {
  const DemoAsset({required this.label, required this.path});

  final String label;
  final String path;
}

class DemoImage {
  const DemoImage({required this.label, required this.bytes});

  final String label;
  final Uint8List bytes;
}

const demoPortraitAssets = [
  DemoAsset(
    label: 'Reference portrait 1',
    path: 'assets/demo/reference_portrait_1.jpg',
  ),
  DemoAsset(
    label: 'Reference portrait 2',
    path: 'assets/demo/reference_portrait_2.jpg',
  ),
  DemoAsset(
    label: 'Reference portrait 3',
    path: 'assets/demo/reference_portrait_3.png',
  ),
];

Future<List<DemoImage>> buildDemoSet() async {
  final images = <DemoImage>[];
  for (final asset in demoPortraitAssets) {
    final data = await rootBundle.load(asset.path);
    images.add(
      DemoImage(
        label: asset.label,
        bytes: data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        ),
      ),
    );
  }
  return images;
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
