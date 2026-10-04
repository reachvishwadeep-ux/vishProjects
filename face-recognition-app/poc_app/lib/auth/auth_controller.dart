import 'package:flutter/foundation.dart';

import 'auth_repository.dart';

class AuthController extends ChangeNotifier {
  AuthController({required this.repository});

  final AuthRepository repository;

  bool _initialized = false;
  bool _busy = false;
  AccountSession? _account;
  String? _error;

  bool get initialized => _initialized;
  bool get busy => _busy;
  bool get authenticated => _account != null;
  AccountSession? get account => _account;
  String? get error => _error;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _busy = true;
    notifyListeners();
    try {
      _account = await repository.restore();
    } finally {
      _initialized = true;
      _busy = false;
      notifyListeners();
    }
  }

  Future<OtpChallenge?> requestOtp(String phoneNumber) async {
    return _run(() => repository.requestOtp(phoneNumber));
  }

  Future<bool> verifyOtp({
    required String phoneNumber,
    required String challengeId,
    required String code,
  }) async {
    final account = await _run(
      () => repository.verifyOtp(
        phoneNumber: phoneNumber,
        challengeId: challengeId,
        code: code,
      ),
    );
    if (account == null) {
      return false;
    }
    _account = account;
    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    _busy = true;
    _error = null;
    notifyListeners();
    await repository.logout();
    _account = null;
    _busy = false;
    notifyListeners();
  }

  Future<T?> _run<T>(Future<T> Function() action) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      return await action();
    } on AuthException catch (error) {
      _error = error.message;
      return null;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
