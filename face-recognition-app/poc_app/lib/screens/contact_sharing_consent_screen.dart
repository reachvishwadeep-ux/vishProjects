import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../theme.dart';

class ContactSharingConsentScreen extends StatelessWidget {
  const ContactSharingConsentScreen({
    super.key,
    required this.controller,
  });

  final AuthController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: controller,
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
                    ),
                    child: const Icon(
                      Icons.phone_in_talk_outlined,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Connect after a match',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.6,
                      ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'For this MVP, ReuniteNow lets matched seekers and finders '
                  'contact each other directly.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: brandMuted, height: 1.45),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: brandLavender,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE3DFFF)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'What you are agreeing to',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 9),
                      Text(
                        'If a cross-account photo match is found, your verified '
                        'phone number will be shown to the matched seeker or '
                        'finder. Their verified phone number will be shown to '
                        'you. A phone number cannot be taken back after someone '
                        'has seen or saved it.',
                        style: TextStyle(
                          color: brandMuted,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed:
                      controller.busy ? null : controller.acceptContactSharing,
                  child: const Text('Agree and continue'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: controller.busy ? null : controller.logout,
                  child: const Text('Sign out'),
                ),
                if (controller.busy) ...[
                  const SizedBox(height: 18),
                  const Center(child: CircularProgressIndicator()),
                ],
                if (controller.error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    controller.error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                const Text(
                  'A visual match is not proof of identity, guardianship, '
                  'custody, intent, or a safe handoff.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: brandMuted,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
