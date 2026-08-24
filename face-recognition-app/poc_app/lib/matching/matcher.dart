import 'dart:typed_data';

import '../models.dart';

abstract class Matcher {
  String get name;

  Future<MatchOutcome> match({
    required Uint8List probe,
    required List<StoredImage> gallery,
    int topK = 5,
  });
}
