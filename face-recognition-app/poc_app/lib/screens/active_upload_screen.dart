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
        title: const Text('Active Upload'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    AspectRatio(
                      aspectRatio: 1.25,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.memory(widget.probe, fit: BoxFit.cover),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 11, 4, 3),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.image_outlined,
                            size: 18,
                            color: brandInk,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              widget.fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text(
                            '${sizeMb.toStringAsFixed(sizeMb < 1 ? 2 : 1)} MB',
                            style: const TextStyle(
                              color: brandMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: brandLavender,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: _error != null
                            ? const Icon(
                                Icons.error_outline_rounded,
                                color: Color(0xFFD45757),
                                size: 31,
                              )
                            : complete
                                ? const Icon(
                                    Icons.check_circle_outline_rounded,
                                    color: brandGreen,
                                    size: 32,
                                  )
                                : const SizedBox(
                                    width: 30,
                                    height: 30,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.6,
                                      color: brandPurple,
                                    ),
                                  ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _error != null
                          ? 'Unable to scan this image'
                          : complete
                              ? 'Search complete'
                              : 'Searching for matches...',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error != null
                          ? 'Choose another supported image and try again.'
                          : complete
                              ? 'Your prototype result is ready to review.'
                              : 'We are scanning the local demo gallery for an identical match.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: brandMuted, height: 1.4),
                    ),
                    if (complete) ...[
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _showResult,
                        child: const Text('View result'),
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
              'Visual prototype · matching runs only while this screen is open',
              textAlign: TextAlign.center,
              style: TextStyle(color: brandMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
