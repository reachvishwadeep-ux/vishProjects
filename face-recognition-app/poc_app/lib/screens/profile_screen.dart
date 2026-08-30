import 'package:flutter/material.dart';

import '../theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          Text(
            'Profile',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Manage how people can connect with you.',
            style: TextStyle(color: brandMuted),
          ),
          const SizedBox(height: 28),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: const BoxDecoration(
                      color: brandLavender,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: brandPurple,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your MatchSnap profile',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Profile and contact-sharing controls will be connected in the online version.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: brandMuted, height: 1.45),
                  ),
                  const SizedBox(height: 20),
                  const _PrototypePill(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrototypePill extends StatelessWidget {
  const _PrototypePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: brandLavender,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'VISUAL PROTOTYPE',
        style: TextStyle(
          color: brandPurple,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: .6,
        ),
      ),
    );
  }
}
