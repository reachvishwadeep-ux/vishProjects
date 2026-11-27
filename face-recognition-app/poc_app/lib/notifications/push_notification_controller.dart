import 'dart:async';

import 'package:firebase_app_installations/firebase_app_installations.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../audit/installation_repository.dart';

class PushNotificationController extends ChangeNotifier {
  PushNotificationController({
    required InstallationRepository installations,
    FirebaseMessaging? messaging,
    FirebaseInstallations? firebaseInstallations,
  })  : _installations = installations,
        _messaging = messaging ?? FirebaseMessaging.instance,
        _firebaseInstallations =
            firebaseInstallations ?? FirebaseInstallations.instance;

  final InstallationRepository _installations;
  final FirebaseMessaging _messaging;
  final FirebaseInstallations _firebaseInstallations;

  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<String>? _fidSubscription;
  String? _pendingConnectionId;
  var _showForegroundAlert = false;
  var _started = false;

  String? takePendingConnectionId() {
    final value = _pendingConnectionId;
    _pendingConnectionId = null;
    return value;
  }

  bool takeForegroundAlert() {
    final value = _showForegroundAlert;
    _showForegroundAlert = false;
    return value;
  }

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );
    _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
      if (message.data['type'] != 'potential_match') return;
      _showForegroundAlert = true;
      notifyListeners();
    });
    _openedSubscription =
        FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleOpenedMessage(initialMessage);
    }
  }

  Future<void> registerForAuthenticatedAccount() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    final enabled =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
    if (!enabled) {
      await _installations.registerPush(fid: null, enabled: false);
      return;
    }

    // Initializes FCM's device registration. The backend targets the related
    // Firebase Installation ID rather than retaining the rotating FCM token.
    await _messaging.getToken();
    await _registerCurrentFid();
    _fidSubscription ??= _firebaseInstallations.onIdChange.listen((_) async {
      try {
        await _registerCurrentFid();
      } on Object {
        // The next sign-in or installation ID change retries registration.
      }
    });
  }

  Future<void> _registerCurrentFid() async {
    final fid = await _firebaseInstallations.getId();
    await _installations.registerPush(fid: fid, enabled: true);
  }

  void _handleOpenedMessage(RemoteMessage message) {
    if (message.data['type'] != 'potential_match') return;
    final connectionId = message.data['connection_id'];
    if (connectionId == null || connectionId.isEmpty) return;
    _pendingConnectionId = connectionId;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_foregroundSubscription?.cancel());
    unawaited(_openedSubscription?.cancel());
    unawaited(_fidSubscription?.cancel());
    super.dispose();
  }
}
