# Image Match — on-device proof of concept

A Flutter app (Android + iOS) that answers one question: **is this photo already
in the repository?** You upload or take a photo, it is compared against the
images stored on the device, and you get a decision plus a ranked list of the
closest candidates with a side-by-side comparison.

Everything runs offline. No backend, no network calls, nothing leaves the phone.

## What the matcher actually does

The PoC matcher is perceptual, not biometric: it combines a **dHash** and a
**pHash** (low-frequency DCT block) for structure with a 4×4×4 RGB **histogram**
for colour, blended 75/25, and scores every stored image in a few milliseconds.

That recognises *the same picture* — rescaled, recompressed, mildly edited — and
**not the same person photographed twice**. Face identity needs an embedding
model; that is the ArcFace service in `../backend`, which is the planned next
step.

Scores map to three outcomes (`PerceptualMatcher`):

| score          | decision   | UI                                     |
| -------------- | ---------- | -------------------------------------- |
| `>= 0.90`      | `match`    | green "Match found", haptic feedback   |
| `0.78 – 0.90`  | `review`   | amber "Possible match", check yourself |
| `< 0.78`       | `noMatch`  | grey "No match"                        |

## Swapping in ArcFace later

The UI and state layer only know about `Matcher`:

```dart
abstract class Matcher {
  String get name;
  Future<MatchOutcome> match({
    required Uint8List probe,
    required List<StoredImage> gallery,
    int topK = 5,
  });
}
```

An `ArcFaceMatcher` that POSTs the probe to the FastAPI service and maps its
response onto `MatchOutcome` drops in at the single construction site in
`lib/main.dart`; no screen changes.

## Layout

```
lib/
  main.dart                     app entry, picks the Matcher implementation
  app_state.dart                gallery + history, ChangeNotifier
  models.dart                   StoredImage, MatchCandidate, MatchOutcome
  theme.dart                    Material 3 theme and per-decision styling
  matching/
    matcher.dart                the pluggable interface
    perceptual_matcher.dart     PoC implementation and thresholds
    signature.dart              dHash, pHash, colour histogram
  repository/
    gallery_repository.dart     stored images + cached signatures (index.json)
    sample_set.dart             synthetic demo images, drawn at runtime
  screens/                      shell, match, gallery, result
  widgets/                      score ring, side-by-side comparison
```

Signatures are computed once when an image is added and cached, so a match run
only decodes the upload. Decoding happens in an isolate to keep the UI smooth.

The demo gallery is *generated* rather than shipped as assets — no binaries in
the repo, and no licensing question, which matters because public face datasets
are research-only. Tapping a stored image re-encodes it (downscale + lossy JPEG)
and feeds it back as an upload, so the match flow can be shown without having a
duplicate photo to hand.

## Run it

```bash
flutter pub get
flutter run                # device or emulator
flutter test
flutter analyze
flutter build apk --debug
```

iOS needs a Mac: `flutter build ios` (unverified here — built and tested on
Android only).
