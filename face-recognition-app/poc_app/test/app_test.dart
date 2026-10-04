import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:poc_app/app_state.dart';
import 'package:poc_app/main.dart';
import 'package:poc_app/matching/perceptual_matcher.dart';
import 'package:poc_app/matching/signature.dart';
import 'package:poc_app/models.dart';
import 'package:poc_app/repository/gallery_repository.dart';
import 'package:poc_app/screens/result_screen.dart';
import 'package:poc_app/theme.dart';

Uint8List _jpeg() {
  final image = img.Image(width: 128, height: 128);
  img.fill(image, color: img.ColorRgb8(30, 120, 200));
  return Uint8List.fromList(img.encodeJpg(image));
}

void main() {
  late Directory root;
  late AppState state;

  setUp(() {
    root = Directory.systemTemp.createTempSync('app_test');
    state = AppState(
      repository: GalleryRepository(root: root),
      matcher: const PerceptualMatcher(),
    );
  });
  tearDown(() => root.deleteSync(recursive: true));

  testWidgets('starts on the upload tab and exposes the redesigned flow',
      (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(PocApp(state: state));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    expect(find.text('Find a missing person'), findsOneWidget);
    expect(find.text('I’m looking for someone'), findsOneWidget);
    expect(find.text('I found someone'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Choose from Gallery'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Choose from Gallery'), findsOneWidget);

    await tester.tap(find.text('Saved Info'));
    await tester.pumpAndSettle();

    expect(find.text('No saved images yet'), findsOneWidget);
  });

  testWidgets('stored images appear in the repository tab', (tester) async {
    // Adding hashes in a real isolate, so it has to run outside the fake clock.
    await tester.runAsync(
      () => state.addImage(bytes: _jpeg(), label: 'Amber Ridge'),
    );

    await tester.pumpWidget(PocApp(state: state));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Saved Info'));
    await tester.pumpAndSettle();

    expect(find.text('Amber Ridge'), findsOneWidget);
    expect(find.textContaining('1 saved image'), findsOneWidget);
  });

  testWidgets('the result screen reports a match with its candidates',
      (tester) async {
    final bytes = _jpeg();
    final signature = ImageSignature.fromBytes(bytes)!;
    final file = File('${root.path}/amber.jpg')..writeAsBytesSync(bytes);
    final stored = StoredImage(
      id: 'amber',
      label: 'Amber Ridge',
      path: file.path,
      signature: signature,
      addedAt: DateTime(2024),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: ResultScreen(
          probe: bytes,
          outcome: MatchOutcome(
            decision: Decision.match,
            candidates: [
              MatchCandidate(
                image: stored,
                score: 0.97,
                structureScore: 0.98,
                colourScore: 0.94,
              ),
            ],
            matcherName: 'Perceptual hash (on-device)',
            duration: const Duration(milliseconds: 12),
            comparisons: 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MATCH FOUND!'), findsOneWidget);
    expect(find.text('Potential match found'), findsOneWidget);
    expect(find.text('Amber Ridge'), findsOneWidget);
    expect(find.text('97%'), findsOneWidget);
  });
}
