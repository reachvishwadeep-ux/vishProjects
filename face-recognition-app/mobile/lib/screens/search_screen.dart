import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api_client.dart';
import '../image_source.dart';
import '../models.dart';
import '../widgets/match_card.dart';
import '../widgets/photo_source_bar.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.api, required this.images});

  final ApiClient api;
  final ImageSourceService images;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  File? _photo;
  SearchResult? _result;
  String? _error;
  bool _busy = false;

  Future<void> _pick(ImageSource source) async {
    final file = await widget.images.pick(source);
    if (file == null) {
      return;
    }
    setState(() {
      _photo = file;
      _result = null;
      _error = null;
    });
    await _search();
  }

  Future<void> _search() async {
    final photo = _photo;
    if (photo == null) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.api.search(image: photo);
      if (mounted) {
        setState(() => _result = result);
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'could not reach the server ($error)');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Identify')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PhotoSourceBar(enabled: !_busy, onPick: _pick),
          const SizedBox(height: 16),
          if (_photo != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(_photo!, height: 240, fit: BoxFit.cover),
            ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_result != null) ..._buildResult(_result!),
        ],
      ),
    );
  }

  List<Widget> _buildResult(SearchResult result) {
    return [
      const SizedBox(height: 16),
      _DecisionBanner(result: result),
      const SizedBox(height: 8),
      for (final match in result.results)
        MatchCard(match: match, isTop: match == result.results.first),
      if (result.results.isEmpty)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('The repository contains no comparable face.'),
        ),
    ];
  }
}

class _DecisionBanner extends StatelessWidget {
  const _DecisionBanner({required this.result});

  final SearchResult result;

  @override
  Widget build(BuildContext context) {
    final (text, color) = switch (result.decision) {
      Decision.match => ('Match found', Colors.green),
      Decision.review => ('Borderline — needs human review', Colors.orange),
      Decision.noMatch => ('No match in the repository', Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$text  (threshold ${result.threshold.toStringAsFixed(2)})',
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
