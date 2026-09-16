import 'dart:typed_data';

import '../models.dart';

abstract class Matcher {
  String get name;

  Future<MatchOutcome> match({
    required Uint8List probe,
    required List<StoredImage> gallery,
    required CaseType caseType,
    required String fileName,
    int topK = 5,
  });
}
