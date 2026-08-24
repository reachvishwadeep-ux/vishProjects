import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:poc_app/repository/gallery_repository.dart';

Uint8List _jpeg(int seed) {
  final image = img.Image(width: 128, height: 128);
  img.fill(image, color: img.ColorRgb8(seed * 40, 90, 200 - seed * 40));
  return Uint8List.fromList(img.encodeJpg(image));
}

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('gallery_test'));
  tearDown(() => root.deleteSync(recursive: true));

  test('added images survive a reload from the on-disk index', () async {
    final repository = GalleryRepository(root: root);
    final stored = await repository.add(bytes: _jpeg(1), label: 'Amber');

    expect(stored, isNotNull);
    expect(File(stored!.path).existsSync(), isTrue);

    final reloaded = await GalleryRepository(root: root).load();
    expect(reloaded.map((i) => i.label), ['Amber']);
    expect(
      reloaded.single.signature.hashSimilarity(stored.signature),
      1.0,
    );
  });

  test('non-image bytes are not added', () async {
    final repository = GalleryRepository(root: root);

    expect(
        await repository.add(bytes: Uint8List.fromList([0, 1]), label: 'bad'),
        isNull);
    expect(await repository.load(), isEmpty);
  });

  test('removing an image deletes its file and index entry', () async {
    final repository = GalleryRepository(root: root);
    final first = await repository.add(bytes: _jpeg(1), label: 'Amber');
    await repository.add(bytes: _jpeg(2), label: 'Cobalt');

    await repository.remove(first!.id);

    expect(File(first.path).existsSync(), isFalse);
    expect((await repository.load()).map((i) => i.label), ['Cobalt']);
    expect((await GalleryRepository(root: root).load()).length, 1);
  });

  test('clear empties the repository', () async {
    final repository = GalleryRepository(root: root);
    await repository.add(bytes: _jpeg(1), label: 'Amber');
    await repository.add(bytes: _jpeg(2), label: 'Cobalt');

    await repository.clear();

    expect(await repository.load(), isEmpty);
    expect(await GalleryRepository(root: root).load(), isEmpty);
  });

  test('newest images come first', () async {
    final repository = GalleryRepository(root: root);
    await repository.add(bytes: _jpeg(1), label: 'first');
    await repository.add(bytes: _jpeg(2), label: 'second');

    expect((await repository.load()).map((i) => i.label), ['second', 'first']);
  });
}
