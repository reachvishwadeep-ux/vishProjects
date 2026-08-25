import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api_client.dart';
import '../image_source.dart';
import '../models.dart';
import '../widgets/photo_source_bar.dart';

class EnrollScreen extends StatefulWidget {
  const EnrollScreen({super.key, required this.api, required this.images});

  final ApiClient api;
  final ImageSourceService images;

  @override
  State<EnrollScreen> createState() => _EnrollScreenState();
}

class _EnrollScreenState extends State<EnrollScreen> {
  final _nameController = TextEditingController();
  File? _photo;
  EnrollResult? _result;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

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
  }

  Future<void> _submit({bool force = false}) async {
    final photo = _photo;
    final name = _nameController.text.trim();
    if (photo == null || name.isEmpty) {
      setState(() => _error = 'Pick a photo and enter a name first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.api.enroll(
        image: photo,
        personName: name,
        force: force,
      );
      if (mounted) {
        setState(() {
          _result = result;
          _photo = null;
        });
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
      appBar: AppBar(title: const Text('Enrol a photo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Person name',
              helperText:
                  'Enrolling several photos per person improves accuracy.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          PhotoSourceBar(enabled: !_busy, onPick: _pick),
          const SizedBox(height: 16),
          if (_photo != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(_photo!, height: 240, fit: BoxFit.cover),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : () => _submit(),
            icon: const Icon(Icons.cloud_upload),
            label: const Text('Enrol'),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            TextButton(
              onPressed: _busy ? null : () => _submit(force: true),
              child: const Text('Enrol anyway (lowers future accuracy)'),
            ),
          ],
          if (_result != null) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: Text('Enrolled ${_result!.displayName}'),
                subtitle: Text(
                  'quality ${_result!.quality.score.toStringAsFixed(2)} · '
                  'face ${_result!.quality.facePixels}px · '
                  'detector ${_result!.quality.detScore.toStringAsFixed(2)}',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
