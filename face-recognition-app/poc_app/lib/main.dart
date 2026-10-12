import 'dart:async';

import 'package:flutter/material.dart';

import 'app_state.dart';
import 'audit/installation_repository.dart';
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
  final installations = InstallationRepository(
    baseUrl: Config.apiBaseUrl,
    appVersion: Config.appVersion,
    buildNumber: Config.buildNumber,
    tokenProvider: authRepository.validAccessToken,
  );
  final connections = ConnectionRepository(
    baseUrl: Config.apiBaseUrl,
    tokenProvider: authRepository.validAccessToken,
    onAuthenticationFailure: auth.logout,
  );
  runApp(
    PocApp(
      auth: auth,
      connections: connections,
      installations: installations,
      state: AppState(
        repository: GalleryRepository(),
        matcher: RemoteMatcher(
          baseUrl: Config.apiBaseUrl,
          tokenProvider: authRepository.validAccessToken,
          installationIdProvider: installations.installationId,
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
    this.installations,
  });

  final AppState state;
  final AuthController? auth;
  final ConnectionRepository? connections;
  final InstallationRepository? installations;

  @override
  State<PocApp> createState() => _PocAppState();
}

class _PocAppState extends State<PocApp> {
  String? _boundAccountId;

  @override
  void initState() {
    super.initState();
    widget.state.initialize();
    widget.auth?.initialize();
    widget.auth?.addListener(_handleAuthenticationChange);
    unawaited(_registerInstallation());
  }

  @override
  void dispose() {
    widget.auth?.removeListener(_handleAuthenticationChange);
    super.dispose();
  }

  void _handleAuthenticationChange() {
    final accountId = widget.auth?.account?.accountId;
    if (accountId == null) {
      _boundAccountId = null;
      return;
    }
    if (_boundAccountId == accountId) {
      return;
    }
    _boundAccountId = accountId;
    unawaited(_bindInstallation());
  }

  Future<void> _registerInstallation() async {
    try {
      await widget.installations?.register();
      _handleAuthenticationChange();
    } on Object {
      // Audit registration must not block offline use or authentication.
    }
  }

  Future<void> _bindInstallation() async {
    try {
      await widget.installations?.bind();
    } on Object {
      // The next authenticated app launch retries this association.
    }
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
