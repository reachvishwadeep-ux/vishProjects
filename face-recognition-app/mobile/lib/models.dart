class Quality {
  Quality({
    required this.facePixels,
    required this.detScore,
    required this.blurVariance,
    required this.yawDegrees,
    required this.score,
    required this.passed,
    required this.reasons,
  });

  final int facePixels;
  final double detScore;
  final double blurVariance;
  final double yawDegrees;
  final double score;
  final bool passed;
  final List<String> reasons;

  factory Quality.fromJson(Map<String, dynamic> json) => Quality(
    facePixels: json['face_pixels'] as int,
    detScore: (json['det_score'] as num).toDouble(),
    blurVariance: (json['blur_variance'] as num).toDouble(),
    yawDegrees: (json['yaw_degrees'] as num).toDouble(),
    score: (json['score'] as num).toDouble(),
    passed: json['passed'] as bool,
    reasons: (json['reasons'] as List<dynamic>).cast<String>(),
  );
}

class EnrollResult {
  EnrollResult({
    required this.personId,
    required this.displayName,
    required this.quality,
  });

  final String personId;
  final String displayName;
  final Quality quality;

  factory EnrollResult.fromJson(Map<String, dynamic> json) => EnrollResult(
    personId: json['person_id'] as String,
    displayName: json['display_name'] as String,
    quality: Quality.fromJson(json['quality'] as Map<String, dynamic>),
  );
}

class Match {
  Match({
    required this.personId,
    required this.displayName,
    required this.score,
    required this.imageUrl,
  });

  final String personId;
  final String displayName;
  final double score;
  final String? imageUrl;

  factory Match.fromJson(Map<String, dynamic> json) => Match(
    personId: json['person_id'] as String,
    displayName: json['display_name'] as String,
    score: (json['score'] as num).toDouble(),
    imageUrl: json['image_url'] as String?,
  );
}

/// `match` is above the threshold, `review` is borderline and needs a human,
/// `no_match` means nobody in the repository is close enough.
enum Decision { match, review, noMatch }

Decision decisionFromString(String value) => switch (value) {
  'match' => Decision.match,
  'review' => Decision.review,
  _ => Decision.noMatch,
};

class SearchResult {
  SearchResult({
    required this.decision,
    required this.threshold,
    required this.results,
  });

  final Decision decision;
  final double threshold;
  final List<Match> results;

  factory SearchResult.fromJson(Map<String, dynamic> json) => SearchResult(
    decision: decisionFromString(json['decision'] as String),
    threshold: (json['threshold'] as num).toDouble(),
    results: (json['results'] as List<dynamic>)
        .map((entry) => Match.fromJson(entry as Map<String, dynamic>))
        .toList(),
  );
}

class Person {
  Person({required this.id, required this.displayName, required this.faceUrls});

  final String id;
  final String displayName;
  final List<String> faceUrls;

  factory Person.fromJson(Map<String, dynamic> json) => Person(
    id: json['id'] as String,
    displayName: json['display_name'] as String,
    faceUrls: (json['faces'] as List<dynamic>)
        .map((entry) => (entry as Map<String, dynamic>)['image_url'] as String?)
        .whereType<String>()
        .toList(),
  );
}

class ApiException implements Exception {
  ApiException(this.message, {this.reasons = const []});

  final String message;
  final List<String> reasons;

  @override
  String toString() =>
      reasons.isEmpty ? message : '$message: ${reasons.join(', ')}';
}
