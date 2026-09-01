import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../theme.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.probe,
    required this.outcome,
  });

  final Uint8List probe;
  final MatchOutcome outcome;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.outcome.decision == Decision.match) {
      HapticFeedback.mediumImpact();
    }
  }

  void _prototypeAction() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Chat and contact sharing require the online service.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Match result'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        top: false,
        child: widget.outcome.decision == Decision.noMatch
            ? _NoMatchResult(
                probe: widget.probe,
                onUploadAnother: () => Navigator.pop(context),
              )
            : _MatchFoundResult(
                probe: widget.probe,
                outcome: widget.outcome,
                onChat: _prototypeAction,
              ),
      ),
    );
  }
}

class _MatchFoundResult extends StatelessWidget {
  const _MatchFoundResult({
    required this.probe,
    required this.outcome,
    required this.onChat,
  });

  final Uint8List probe;
  final MatchOutcome outcome;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    final best = outcome.best!;
    final score = (best.score * 100).round();

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
          decoration: BoxDecoration(
            gradient: brandSoftGradient,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFE7E1FF)),
          ),
          child: Column(
            children: [
              const _StatusPill(
                label: 'MATCH FOUND!',
                icon: Icons.auto_awesome_rounded,
                color: brandGreen,
                background: Color(0xFFE8F9F1),
              ),
              const SizedBox(height: 11),
              Text(
                decisionTitle(outcome.decision),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.7,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Two photos captured the same moment.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: brandMuted.withValues(alpha: .95),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 188,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: 9,
                      top: 8,
                      child: Transform.rotate(
                        angle: -.055,
                        child: _SnapCard(
                          image: Image.memory(probe, fit: BoxFit.cover),
                          label: 'YOUR SNAP',
                        ),
                      ),
                    ),
                    Positioned(
                      right: 9,
                      top: 18,
                      child: Transform.rotate(
                        angle: .075,
                        child: _SnapCard(
                          image: Image.file(
                            File(best.image.path),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const ColoredBox(
                              color: brandLavender,
                              child: Icon(
                                Icons.image_outlined,
                                color: brandPurple,
                              ),
                            ),
                          ),
                          label: 'FOUND SNAP',
                        ),
                      ),
                    ),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        gradient: brandGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x3D7057F5),
                            blurRadius: 18,
                            offset: Offset(0, 7),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.link_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        gradient: brandGradient,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          'RP',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            best.image.label,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Authorized demo image',
                            style: TextStyle(color: brandMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F9F1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFC9EFDE)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.verified_rounded,
                            color: brandGreen,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$score%',
                            style: const TextStyle(
                              color: brandGreen,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                  decoration: BoxDecoration(
                    color: brandSurface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_outlined,
                        color: brandPurple,
                        size: 18,
                      ),
                      SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'High-confidence local image match',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 26),
                const _ContactRow(
                  icon: Icons.mail_outline_rounded,
                  label: 'EMAIL ADDRESS',
                  value: 'reference@matchsnap.demo',
                ),
                const SizedBox(height: 13),
                const _ContactRow(
                  icon: Icons.phone_in_talk_outlined,
                  label: 'PHONE NUMBER',
                  value: 'Not provided',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: brandGradient,
            borderRadius: BorderRadius.circular(17),
            boxShadow: const [
              BoxShadow(
                color: Color(0x297057F5),
                blurRadius: 18,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: FilledButton.icon(
            onPressed: onChat,
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            label: const Text('Initiate Chat'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Authorized reference image · mock contact details',
          textAlign: TextAlign.center,
          style: TextStyle(color: brandMuted, fontSize: 11),
        ),
      ],
    );
  }
}

class _NoMatchResult extends StatelessWidget {
  const _NoMatchResult({
    required this.probe,
    required this.onUploadAnother,
  });

  final Uint8List probe;
  final VoidCallback onUploadAnother;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
          decoration: BoxDecoration(
            gradient: brandSoftGradient,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFE7E1FF)),
          ),
          child: Column(
            children: [
              const _StatusPill(
                label: 'NO MATCH YET',
                icon: Icons.schedule_rounded,
                color: brandPurple,
                background: Colors.white,
              ),
              const SizedBox(height: 11),
              Text(
                decisionTitle(Decision.noMatch),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.7,
                    ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Your snap is saved in this prototype session.',
                textAlign: TextAlign.center,
                style: TextStyle(color: brandMuted, fontSize: 13),
              ),
              const SizedBox(height: 17),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(21),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1C382E64),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: AspectRatio(
                  aspectRatio: 1.35,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.memory(probe, fit: BoxFit.cover),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 78,
                      height: 78,
                      decoration: const BoxDecoration(
                        color: brandLavender,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        gradient: brandGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x337057F5),
                            blurRadius: 16,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.notifications_active_outlined,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 17),
                Text(
                  'We’ll keep looking',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.3,
                      ),
                ),
                const SizedBox(height: 9),
                Text(
                  decisionMessage(Decision.noMatch),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: brandMuted,
                    height: 1.5,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 15),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF5DE),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Alerts are not active in this prototype',
                    style: TextStyle(
                      color: Color(0xFF9A6B12),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: onUploadAnother,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: const Text('Upload another snap'),
        ),
      ],
    );
  }
}

class _SnapCard extends StatelessWidget {
  const _SnapCard({required this.image, required this.label});

  final Widget image;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 125,
      height: 158,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            image,
            Positioned(
              left: 7,
              bottom: 7,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: brandInk.withValues(alpha: .78),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.icon,
    required this.color,
    required this.background,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: .3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: brandLavender,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: brandPurple, size: 17),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: brandMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}
