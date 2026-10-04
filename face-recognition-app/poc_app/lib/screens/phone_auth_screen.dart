import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_controller.dart';
import '../auth/auth_repository.dart';
import '../theme.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key, required this.controller});

  final AuthController controller;

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _phoneController = TextEditingController(text: '+91');
  final _codeController = TextEditingController();
  OtpChallenge? _challenge;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    final challenge = await widget.controller.requestOtp(_phoneController.text);
    if (!mounted || challenge == null) {
      return;
    }
    setState(() {
      _challenge = challenge;
      _codeController.text = challenge.developmentCode ?? '';
    });
  }

  Future<void> _verifyOtp() async {
    final challenge = _challenge;
    if (challenge == null) {
      return;
    }
    await widget.controller.verifyOtp(
      phoneNumber: _phoneController.text,
      challengeId: challenge.id,
      code: _codeController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 44, 24, 32),
              children: [
                Align(
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      gradient: brandGradient,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x337057F5),
                          blurRadius: 28,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  _challenge == null ? 'Verify your phone' : 'Enter your code',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.6,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  _challenge == null
                      ? 'MatchSnap uses your phone number to protect photo submissions and matches.'
                      : 'Use the six-digit code sent for ${_phoneController.text}.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: brandMuted,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 32),
                if (_challenge == null) ...[
                  TextField(
                    controller: _phoneController,
                    enabled: !widget.controller.busy,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    decoration: const InputDecoration(
                      labelText: 'Mobile number',
                      hintText: '+919876543210',
                      prefixIcon: Icon(Icons.phone_outlined),
                      helperText: 'Include country code, for example +91.',
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: widget.controller.busy ? null : _requestOtp,
                    child: const Text('Send verification code'),
                  ),
                ] else ...[
                  TextField(
                    controller: _codeController,
                    enabled: !widget.controller.busy,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 10,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'One-time code',
                    ),
                  ),
                  if (_challenge?.developmentCode != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: brandLavender,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Local demo code: ${_challenge!.developmentCode}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: brandPurpleDark,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: widget.controller.busy ? null : _verifyOtp,
                    child: const Text('Verify and continue'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: widget.controller.busy
                        ? null
                        : () {
                            setState(() {
                              _challenge = null;
                              _codeController.clear();
                            });
                          },
                    child: const Text('Use a different number'),
                  ),
                ],
                if (widget.controller.busy) ...[
                  const SizedBox(height: 20),
                  const Center(child: CircularProgressIndicator()),
                ],
                if (widget.controller.error != null) ...[
                  const SizedBox(height: 18),
                  Text(
                    widget.controller.error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lock_outline_rounded,
                        color: brandGreen, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your phone number is used for account access. It is not shown to other users.',
                        style: TextStyle(
                          color: brandMuted,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
