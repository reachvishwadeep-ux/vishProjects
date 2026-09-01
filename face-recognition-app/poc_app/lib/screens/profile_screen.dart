import 'package:flutter/material.dart';

import '../theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 112),
        children: [
          Text(
            'Profile',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.6,
                ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Manage how people can connect with you.',
            style: TextStyle(color: brandMuted),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
            decoration: BoxDecoration(
              gradient: brandGradient,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x337057F5),
                  blurRadius: 26,
                  offset: Offset(0, 11),
                ),
              ],
            ),
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .18),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .7),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 41,
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 27,
                        height: 27,
                        decoration: BoxDecoration(
                          color: brandGreen,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Your MatchSnap profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.4,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Control what is shared after a future match.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .76),
                    height: 1.4,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                const _PrototypePill(inverted: true),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Privacy & sharing',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(7),
              child: Column(
                children: [
                  _ProfileSetting(
                    icon: Icons.mail_outline_rounded,
                    title: 'Email address',
                    subtitle: 'Hidden until you approve sharing',
                    value: 'Private',
                  ),
                  Divider(height: 1, indent: 54),
                  _ProfileSetting(
                    icon: Icons.phone_outlined,
                    title: 'Phone number',
                    subtitle: 'Not provided',
                    value: 'Off',
                  ),
                  Divider(height: 1, indent: 54),
                  _ProfileSetting(
                    icon: Icons.notifications_outlined,
                    title: 'Match alerts',
                    subtitle: 'Planned for the online version',
                    value: 'Soon',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: brandLavender,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE3DFFF)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.shield_outlined,
                  color: brandPurple,
                  size: 21,
                ),
                SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You stay in control',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'These controls preview the future experience and are not connected yet.',
                        style: TextStyle(
                          color: brandMuted,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrototypePill extends StatelessWidget {
  const _PrototypePill({this.inverted = false});

  final bool inverted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: inverted ? Colors.white.withValues(alpha: .16) : brandLavender,
        borderRadius: BorderRadius.circular(20),
        border: inverted
            ? Border.all(color: Colors.white.withValues(alpha: .18))
            : null,
      ),
      child: Text(
        'VISUAL PROTOTYPE',
        style: TextStyle(
          color: inverted ? Colors.white : brandPurple,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: .6,
        ),
      ),
    );
  }
}

class _ProfileSetting extends StatelessWidget {
  const _ProfileSetting({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: brandLavender,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: brandPurple, size: 19),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: brandMuted, fontSize: 10),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: brandSurfaceStrong,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value,
              style: const TextStyle(
                color: brandMuted,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
