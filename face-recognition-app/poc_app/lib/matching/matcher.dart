import 'dart:typed_data';

import '../models.dart';

class MatchPhoto {
  const MatchPhoto({
    required this.bytes,
    required this.fileName,
  });

  final Uint8List bytes;
  final String fileName;
}

abstract class Matcher {
  const Matcher();

  String get name;

  Future<MatchOutcome> match({
    required Uint8List probe,
    required List<StoredImage> gallery,
    required CaseType caseType,
    required String fileName,
    int topK = 5,
  });

  Future<MatchOutcome> matchPhotos({
    required List<MatchPhoto> photos,
    required List<StoredImage> gallery,
    required CaseType caseType,
    int topK = 5,
  }) {
    if (photos.isEmpty) {
      throw ArgumentError.value(photos, 'photos', 'must not be empty');
    }
    final photo = photos.first;
    return match(
      probe: photo.bytes,
      gallery: gallery,
      caseType: caseType,
      fileName: photo.fileName,
      topK: topK,
    );
  }
}
