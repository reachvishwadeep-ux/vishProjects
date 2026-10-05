import 'package:flutter/material.dart';

import 'app_state.dart';
import 'auth/auth_controller.dart';
import 'auth/auth_repository.dart';
import 'config.dart';
import 'connections/connection_repository.dart';
import 'matching/remote_matcher.dart';
import 'repository/gallery_repository.dart';
import 'screens/phone_auth_screen.dart';
import 'screens/shell.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final authRepository = AuthRepository(baseUrl: Config.apiBaseUrl);
  final auth = AuthController(repository: authRepository);
  final connections = ConnectionRepository(
    baseUrl: Config.apiBaseUrl,
    tokenProvider: authRepository.validAccessToken,
    onAuthenticationFailure: auth.logout,
  );
  runApp(
    PocApp(
      auth: auth,
      connections: connections,
      state: AppState(
        repository: GalleryRepository(),
        matcher: RemoteMatcher(
          baseUrl: Config.apiBaseUrl,
          tokenProvider: authRepository.validAccessToken,
          onAuthenticationFailure: auth.logout,
        ),
      ),
    ),
  );
}

class PocApp extends StatefulWidget {
  const PocApp({
    super.key,
    required this.state,
    this.auth,
    this.connections,
  });

  final AppState state;
  final AuthController? auth;
  final ConnectionRepository? connections;

  @override
  State<PocApp> createState() => _PocAppState();
}

class _PocAppState extends State<PocApp> {
  @override
  void initState() {
    super.initState();
    widget.state.initialize();
    widget.auth?.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MatchSnap',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      themeMode: ThemeMode.light,
      home: widget.auth == null
          ? AppShell(state: widget.state, connections: widget.connections)
          : AnimatedBuilder(
              animation: widget.auth!,
              builder: (context, _) {
                if (!widget.auth!.initialized) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                if (!widget.auth!.authenticated) {
                  return PhoneAuthScreen(controller: widget.auth!);
                }
                return AppShell(
                  state: widget.state,
                  auth: widget.auth,
                  connections: widget.connections,
                );
              },
            ),
    );
  }
}
