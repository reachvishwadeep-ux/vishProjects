import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../matching/signature.dart';
import '../models.dart';

class GalleryRepository {
  GalleryRepository({Directory? root}) : _configuredRoot = root;

  final Directory? _configuredRoot;
  Directory? _root;

  Future<List<StoredImage>> load() async {
    final root = await _resolveRoot();
    final index = File('${root.path}/index.json');
    if (!await index.exists()) {
      return [];
    }

    try {
      final entries = (jsonDecode(await index.readAsString()) as List<Object?>)
          .cast<Map<Object?, Object?>>();
      final images = entries
          .map((entry) => StoredImage.fromJson(entry.cast<String, Object?>()))
          .where((image) => File(image.path).existsSync())
          .toList()
        ..sort((left, right) => right.addedAt.compareTo(left.addedAt));
      return images;
    } on FormatException {
      return [];
    }
  }

  Future<StoredImage?> add({
    required Uint8List bytes,
    required String label,
  }) async {
    final signature = ImageSignature.fromBytes(bytes);
    if (signature == null) {
      return null;
    }

    final root = await _resolveRoot();
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final file = File('${root.path}/$id.image');
    await file.writeAsBytes(bytes, flush: true);

    final image = StoredImage(
      id: id,
      label: label.trim().isEmpty ? 'Untitled image' : label.trim(),
      path: file.path,
      signature: signature,
      addedAt: DateTime.now(),
    );
    final images = await load();
    images.insert(0, image);
    await _writeIndex(images);
    return image;
  }

  Future<void> remove(String id) async {
    final images = await load();
    final removed = images.where((image) => image.id == id).toList();
    for (final image in removed) {
      final file = File(image.path);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await _writeIndex(images.where((image) => image.id != id).toList());
  }

  Future<void> clear() async {
    final images = await load();
    for (final image in images) {
      final file = File(image.path);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await _writeIndex([]);
  }

  Future<Directory> _resolveRoot() async {
    if (_root != null) {
      return _root!;
    }

    final root = _configuredRoot ??
        Directory('${(await getApplicationDocumentsDirectory()).path}/image_match_gallery');
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    _root = root;
    return root;
  }

  Future<void> _writeIndex(List<StoredImage> images) async {
    final root = await _resolveRoot();
    final index = File('${root.path}/index.json');
    await index.writeAsString(
      const JsonEncoder.withIndent('  ').convert(images.map((image) => image.toJson()).toList()),
      flush: true,
    );
  }
}
