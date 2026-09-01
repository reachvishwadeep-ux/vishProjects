import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import 'result_screen.dart';

class ActiveUploadScreen extends StatefulWidget {
  const ActiveUploadScreen({
    super.key,
    required this.state,
    required this.probe,
    required this.fileName,
  });

  final AppState state;
  final Uint8List probe;
  final String fileName;

  @override
  State<ActiveUploadScreen> createState() => _ActiveUploadScreenState();
}

class _ActiveUploadScreenState extends State<ActiveUploadScreen> {
  MatchOutcome? _outcome;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _search();
  }

  Future<void> _search() async {
    try {
      final match = widget.state.compare(widget.probe);
      await Future<void>.delayed(const Duration(milliseconds: 900));
      final outcome = await match;
      if (mounted) {
        setState(() => _outcome = outcome);
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    }
  }

  void _showResult() {
    final outcome = _outcome;
    if (outcome == null) {
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultScreen(probe: widget.probe, outcome: outcome),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sizeMb = widget.probe.lengthInBytes / (1024 * 1024);
    final complete = _outcome != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Matching photo'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
          children: [
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: _error != null
                      ? const Color(0xFFFFEDED)
                      : complete
                          ? const Color(0xFFE9F9F1)
                          : brandLavender,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _error != null
                          ? Icons.error_outline_rounded
                          : complete
                              ? Icons.check_circle_outline_rounded
                              : Icons.radar_rounded,
                      color: _error != null
                          ? const Color(0xFFD45757)
                          : complete
                              ? brandGreen
                              : brandPurple,
                      size: 15,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _error != null
                          ? 'SCAN INTERRUPTED'
                          : complete
                              ? 'SCAN COMPLETE'
                              : 'LOCAL SCAN ACTIVE',
                      style: TextStyle(
                        color: _error != null
                            ? const Color(0xFFD45757)
                            : complete
                                ? brandGreen
                                : brandPurple,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: brandGradient,
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x297057F5),
                    blurRadius: 24,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 1.22,
                      child: Image.memory(widget.probe, fit: BoxFit.cover),
                    ),
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: brandInk.withValues(alpha: .78),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.image_outlined,
                              size: 17,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                widget.fileName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              '${sizeMb.toStringAsFixed(sizeMb < 1 ? 2 : 1)} MB',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: .72),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _ProcessStep(
                          icon: Icons.upload_rounded,
                          label: 'Ready',
                          active: true,
                          complete: true,
                        ),
                        const _ProcessLine(active: true),
                        _ProcessStep(
                          icon: Icons.search_rounded,
                          label: 'Scanning',
                          active: !complete && _error == null,
                          complete: complete,
                        ),
                        _ProcessLine(active: complete),
                        _ProcessStep(
                          icon: Icons.flag_outlined,
                          label: 'Result',
                          active: complete,
                          complete: false,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      child: Container(
                        key: ValueKey('${_error != null}-$complete'),
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: _error != null
                              ? const Color(0xFFFFEDED)
                              : complete
                                  ? const Color(0xFFE9F9F1)
                                  : brandLavender,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: _error != null
                              ? const Icon(
                                  Icons.error_outline_rounded,
                                  color: Color(0xFFD45757),
                                  size: 30,
                                )
                              : complete
                                  ? const Icon(
                                      Icons.check_rounded,
                                      color: brandGreen,
                                      size: 31,
                                    )
                                  : const SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.7,
                                        color: brandPurple,
                                      ),
                                    ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: Text(
                        _error != null
                            ? 'Unable to scan this image'
                            : complete
                                ? 'Your result is ready'
                                : 'Searching for matches...',
                        key: ValueKey('${_error != null}-$complete-title'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -.3,
                            ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error != null
                          ? 'Choose another supported image and try again.'
                          : complete
                              ? 'The local comparison finished successfully.'
                              : 'Comparing your photo with every image saved on this device.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: brandMuted,
                        height: 1.45,
                        fontSize: 13,
                      ),
                    ),
                    if (!complete && _error == null) ...[
                      const SizedBox(height: 20),
                      const ClipRRect(
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                        child: LinearProgressIndicator(
                          minHeight: 7,
                          color: brandPurple,
                          backgroundColor: brandLavender,
                        ),
                      ),
                      const SizedBox(height: 9),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            color: brandMuted,
                            size: 13,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Processing privately on this device',
                            style: TextStyle(
                              color: brandMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (complete) ...[
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _showResult,
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Text('View result'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Upload another snap'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Visual prototype · matching runs only on this device',
              textAlign: TextAlign.center,
              style: TextStyle(color: brandMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProcessStep extends StatelessWidget {
  const _ProcessStep({
    required this.icon,
    required this.label,
    required this.active,
    required this.complete,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final highlighted = active || complete;
    return Column(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: highlighted ? brandLavender : brandSurfaceStrong,
            shape: BoxShape.circle,
            border: Border.all(
              color: highlighted ? brandPurple : brandBorder,
            ),
          ),
          child: Icon(
            complete ? Icons.check_rounded : icon,
            color: highlighted ? brandPurple : brandMuted,
            size: 17,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            color: highlighted ? brandInk : brandMuted,
            fontSize: 9,
            fontWeight: highlighted ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ProcessLine extends StatelessWidget {
  const _ProcessLine({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.fromLTRB(7, 0, 7, 19),
        color: active ? brandPurple : brandBorder,
      ),
    );
  }
}
