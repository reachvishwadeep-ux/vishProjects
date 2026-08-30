import 'package:flutter/material.dart';

import 'app_state.dart';
import 'matching/perceptual_matcher.dart';
import 'repository/gallery_repository.dart';
import 'screens/shell.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    PocApp(
      state: AppState(
        repository: GalleryRepository(),
        matcher: const PerceptualMatcher(),
      ),
    ),
  );
}

class PocApp extends StatefulWidget {
  const PocApp({super.key, required this.state});

  final AppState state;

  @override
  State<PocApp> createState() => _PocAppState();
}

class _PocAppState extends State<PocApp> {
  @override
  void initState() {
    super.initState();
    widget.state.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MatchSnap',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      themeMode: ThemeMode.light,
      home: AppShell(state: widget.state),
    );
  }
}
