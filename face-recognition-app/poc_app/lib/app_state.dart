import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'matching/matcher.dart';
import 'models.dart';
import 'repository/gallery_repository.dart';
import 'repository/sample_set.dart';

class AppState extends ChangeNotifier {
  AppState({
    required this.repository,
    required this.matcher,
  });

  final GalleryRepository repository;
  final Matcher matcher;

  List<StoredImage> _gallery = [];
  bool _initialized = false;
  bool _loading = false;
  bool _matching = false;

  List<StoredImage> get gallery => List.unmodifiable(_gallery);
  bool get loading => _loading;
  bool get matching => _matching;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    _loading = true;
    notifyListeners();
    _gallery = await repository.load();
    _loading = false;
    notifyListeners();
  }

  Future<StoredImage?> addImage({
    required Uint8List bytes,
    required String label,
  }) async {
    await initialize();
    final image = await repository.add(bytes: bytes, label: label);
    if (image != null) {
      _gallery = [image, ..._gallery];
      notifyListeners();
    }
    return image;
  }

  Future<void> addDemoImages() async {
    await initialize();
    if (_gallery.isNotEmpty) {
      return;
    }
    _loading = true;
    notifyListeners();
    for (final sample in buildDemoSet()) {
      final image = await repository.add(bytes: sample.bytes, label: sample.label);
      if (image != null) {
        _gallery.insert(0, image);
      }
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> removeImage(String id) async {
    await repository.remove(id);
    _gallery = _gallery.where((image) => image.id != id).toList();
    notifyListeners();
  }

  Future<void> clear() async {
    await repository.clear();
    _gallery = [];
    notifyListeners();
  }

  Future<MatchOutcome> compare(Uint8List probe) async {
    await initialize();
    _matching = true;
    notifyListeners();
    try {
      return await matcher.match(probe: probe, gallery: _gallery);
    } finally {
      _matching = false;
      notifyListeners();
    }
  }

  Future<Uint8List> demoProbe(StoredImage image) async {
    return makeProbeCopy(await File(image.path).readAsBytes());
  }
}
