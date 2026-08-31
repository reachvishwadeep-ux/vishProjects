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
        const Center(
          child: _StatusPill(
            label: 'MATCH FOUND!',
            icon: Icons.auto_awesome_rounded,
            color: brandGreen,
            background: Color(0xFFEAF9F2),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          decisionTitle(outcome.decision),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -.5,
              ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 186,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 27,
                top: 8,
                child: Transform.rotate(
                  angle: -.055,
                  child: _SnapCard(
                    image: Image.memory(probe, fit: BoxFit.cover),
                  ),
                ),
              ),
              Positioned(
                right: 27,
                top: 18,
                child: Transform.rotate(
                  angle: .075,
                  child: _SnapCard(
                    image: Image.file(
                      File(best.image.path),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: brandLavender,
                        child: Icon(Icons.image_outlined, color: brandPurple),
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: brandPurple,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x336C5CE7),
                      blurRadius: 14,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.link_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 23,
                      backgroundColor: brandLavender,
                      child: Text(
                        'RP',
                        style: TextStyle(
                          color: brandPurple,
                          fontWeight: FontWeight.w900,
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
                            style: const TextStyle(fontWeight: FontWeight.w900),
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
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF9F2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$score%',
                        style: const TextStyle(
                          color: brandGreen,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
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
        FilledButton.icon(
          onPressed: onChat,
          icon: const Icon(Icons.chat_bubble_outline_rounded),
          label: const Text('Initiate Chat'),
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
        const Center(
          child: _StatusPill(
            label: 'NO MATCH YET',
            icon: Icons.schedule_rounded,
            color: brandPurple,
            background: brandLavender,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          decisionTitle(Decision.noMatch),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -.5,
              ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your snap is saved in this prototype session.',
          textAlign: TextAlign.center,
          style: TextStyle(color: brandMuted),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: AspectRatio(
              aspectRatio: 1.3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.memory(probe, fit: BoxFit.cover),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
            child: Column(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: const BoxDecoration(
                    color: brandLavender,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_active_outlined,
                    color: brandPurple,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 17),
                Text(
                  'We’ll keep looking',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 9),
                Text(
                  decisionMessage(Decision.noMatch),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: brandMuted, height: 1.5),
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
  const _SnapCard({required this.image});

  final Widget image;

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
        child: image,
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
