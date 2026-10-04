import 'matching/signature.dart';

enum Decision { match, review, noMatch }

enum CaseType { missing, found }

class StoredImage {
  const StoredImage({
    required this.id,
    required this.label,
    required this.path,
    required this.signature,
    required this.addedAt,
    this.remoteUrl,
  });

  factory StoredImage.remote({
    required String id,
    required String label,
    required String? remoteUrl,
  }) {
    return StoredImage(
      id: id,
      label: label,
      path: '',
      signature: const ImageSignature(
        dHash: [],
        pHash: [],
        colourHistogram: [],
      ),
      addedAt: DateTime.now(),
      remoteUrl: remoteUrl,
    );
  }

  final String id;
  final String label;
  final String path;
  final ImageSignature signature;
  final DateTime addedAt;
  final String? remoteUrl;

  Map<String, Object> toJson() => {
        'id': id,
        'label': label,
        'path': path,
        'signature': signature.toJson(),
        'addedAt': addedAt.toIso8601String(),
        if (remoteUrl != null) 'remoteUrl': remoteUrl!,
      };

  factory StoredImage.fromJson(Map<String, Object?> json) {
    return StoredImage(
      id: json['id']! as String,
      label: json['label']! as String,
      path: json['path']! as String,
      signature: ImageSignature.fromJson(
        (json['signature']! as Map<Object?, Object?>).cast<String, Object?>(),
      ),
      addedAt: DateTime.parse(json['addedAt']! as String),
      remoteUrl: json['remoteUrl'] as String?,
    );
  }
}

class MatchCandidate {
  const MatchCandidate({
    required this.image,
    required this.score,
    required this.structureScore,
    required this.colourScore,
  });

  final StoredImage image;
  final double score;
  final double structureScore;
  final double colourScore;
}

class MatchOutcome {
  const MatchOutcome({
    required this.decision,
    required this.candidates,
    required this.matcherName,
    required this.duration,
    required this.comparisons,
  });

  final Decision decision;
  final List<MatchCandidate> candidates;
  final String matcherName;
  final Duration duration;
  final int comparisons;

  MatchCandidate? get best => candidates.isEmpty ? null : candidates.first;
}
