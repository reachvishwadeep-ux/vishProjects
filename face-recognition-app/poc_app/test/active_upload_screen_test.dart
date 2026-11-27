import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:poc_app/app_state.dart';
import 'package:poc_app/matching/matcher.dart' as matching;
import 'package:poc_app/matching/remote_matcher.dart';
import 'package:poc_app/models.dart';
import 'package:poc_app/repository/gallery_repository.dart';
import 'package:poc_app/screens/active_upload_screen.dart';
import 'package:poc_app/theme.dart';

Uint8List _jpeg(int red) {
  final image = img.Image(width: 64, height: 64);
  img.fill(image, color: img.ColorRgb8(red, 80, 120));
  return Uint8List.fromList(img.encodeJpg(image));
}

class _RecordingMatcher extends matching.Matcher {
  final submissions = <List<String>>[];
  RemoteRecognitionException? nextError;

  @override
  String get name => 'Test matcher';

  @override
  Future<MatchOutcome> match({
    required Uint8List probe,
    required List<StoredImage> gallery,
    required CaseType caseType,
    required String fileName,
    int topK = 5,
  }) {
    return matchPhotos(
      photos: [matching.MatchPhoto(bytes: probe, fileName: fileName)],
      gallery: gallery,
      caseType: caseType,
      topK: topK,
    );
  }

  @override
  Future<MatchOutcome> matchPhotos({
    required List<matching.MatchPhoto> photos,
    required List<StoredImage> gallery,
    required CaseType caseType,
    int topK = 5,
  }) async {
    submissions.add(photos.map((photo) => photo.fileName).toList());
    final error = nextError;
    nextError = null;
    if (error != null) {
      throw error;
    }
    return MatchOutcome(
      decision: Decision.noMatch,
      candidates: const [],
      matcherName: name,
      duration: Duration.zero,
      comparisons: 0,
    );
  }
}

void main() {
  late Directory root;
  late _RecordingMatcher matcher;
  late AppState state;

  setUp(() {
    root = Directory.systemTemp.createTempSync('active_upload_test');
    matcher = _RecordingMatcher();
    state = AppState(
      repository: GalleryRepository(root: root),
      matcher: matcher,
    );
  });

  tearDown(() => root.deleteSync(recursive: true));

  Future<void> pumpScreen(
    WidgetTester tester, {
    List<matching.MatchPhoto>? photos,
  }) async {
    await tester.runAsync(state.initialize);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: ActiveUploadScreen(
          state: state,
          photos: photos ??
              [
                matching.MatchPhoto(bytes: _jpeg(40), fileName: 'front.jpg'),
                matching.MatchPhoto(bytes: _jpeg(120), fileName: 'profile.jpg'),
              ],
          caseType: CaseType.missing,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      250,
      scrollable: find.byType(Scrollable).first,
    );
  }

  testWidgets('reviews every photo and submits only the retained selection',
      (tester) async {
    await pumpScreen(tester);

    expect(matcher.submissions, isEmpty);
    expect(find.text('front.jpg'), findsOneWidget);
    expect(find.text('profile.jpg'), findsOneWidget);
    expect(find.text('Replace'), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey('remove-photo-1')));
    await tester.pumpAndSettle();

    expect(find.text('profile.jpg'), findsNothing);
    final searchButton = find.byKey(const ValueKey('search-photos-button'));
    await scrollTo(tester, searchButton);
    await tester.tap(searchButton);
    await tester.pumpAndSettle();

    expect(matcher.submissions, [
      ['front.jpg'],
    ]);
    expect(find.text('View result'), findsOneWidget);
  });

  testWidgets('highlights a rejected photo and retains the others for retry',
      (tester) async {
    matcher.nextError = const RemoteRecognitionException(
      'Photo 2 contains more than one person. '
      'Choose a photo showing only the person for this case.',
      photoIndex: 2,
      reasons: ['Choose a photo showing only the person for this case.'],
    );
    await pumpScreen(tester);

    final searchButton = find.byKey(const ValueKey('search-photos-button'));
    await scrollTo(tester, searchButton);
    await tester.tap(searchButton);
    await tester.pumpAndSettle();

    expect(find.text('Try again'), findsOneWidget);
    await scrollTo(tester, find.text('PHOTO 2 • CHECK'));
    expect(find.text('PHOTO 2 • CHECK'), findsOneWidget);
    expect(find.text('front.jpg', skipOffstage: false), findsOneWidget);
    expect(find.text('profile.jpg', skipOffstage: false), findsOneWidget);

    final removeRejected = find.byKey(const ValueKey('remove-photo-1'));
    await tester.ensureVisible(removeRejected);
    await tester.pumpAndSettle();
    await tester.tap(removeRejected);
    await tester.pumpAndSettle();

    expect(find.text('profile.jpg'), findsNothing);
    await scrollTo(tester, searchButton);
    await tester.tap(searchButton);
    await tester.pumpAndSettle();

    expect(matcher.submissions, [
      ['front.jpg', 'profile.jpg'],
      ['front.jpg'],
    ]);
    expect(find.text('View result'), findsOneWidget);
  });

  testWidgets('requires at least one photo before submission', (tester) async {
    await pumpScreen(
      tester,
      photos: [
        matching.MatchPhoto(bytes: _jpeg(40), fileName: 'front.jpg'),
      ],
    );

    await tester.tap(find.byKey(const ValueKey('remove-photo-0')));
    await tester.pumpAndSettle();

    expect(find.text('Add at least one photo'), findsOneWidget);
    final searchButton = find.byKey(const ValueKey('search-photos-button'));
    await scrollTo(tester, searchButton);
    expect(
      tester.widget<FilledButton>(searchButton).onPressed,
      isNull,
    );
    expect(matcher.submissions, isEmpty);
  });
}
