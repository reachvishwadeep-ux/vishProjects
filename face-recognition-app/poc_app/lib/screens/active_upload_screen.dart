import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_state.dart';
import '../matching/matcher.dart';
import '../matching/remote_matcher.dart';
import '../models.dart';
import '../theme.dart';
import 'result_screen.dart';

class ActiveUploadScreen extends StatefulWidget {
  const ActiveUploadScreen({
    super.key,
    required this.state,
    required this.photos,
    required this.caseType,
  });

  final AppState state;
  final List<MatchPhoto> photos;
  final CaseType caseType;

  @override
  State<ActiveUploadScreen> createState() => _ActiveUploadScreenState();
}

class _ActiveUploadScreenState extends State<ActiveUploadScreen> {
  late final List<MatchPhoto> _photos;
  MatchOutcome? _outcome;
  Object? _error;
  var _searching = false;

  bool get _canEdit => !_searching && _outcome == null;

  int? get _rejectedPhotoIndex {
    final error = _error;
    if (error is! RemoteRecognitionException) {
      return null;
    }
    final index = error.photoIndex;
    if (index == null || index < 1 || index > _photos.length) {
      return null;
    }
    return index - 1;
  }

  @override
  void initState() {
    super.initState();
    _photos = List<MatchPhoto>.of(widget.photos);
  }

  Future<MatchPhoto> _readPhoto(XFile picked) async {
    return MatchPhoto(
      bytes: await picked.readAsBytes(),
      fileName: picked.name,
    );
  }

  Future<void> _addPhotos() async {
    final remaining = 5 - _photos.length;
    if (!_canEdit || remaining <= 0) {
      return;
    }
    final picked = await ImagePicker().pickMultiImage(
      imageQuality: 92,
      maxWidth: 1800,
      limit: remaining,
    );
    if (picked.isEmpty || !mounted) {
      return;
    }
    final additions = await Future.wait(picked.take(remaining).map(_readPhoto));
    if (!mounted) {
      return;
    }
    setState(() {
      _photos.addAll(additions);
      _clearError();
    });
  }

  Future<void> _replacePhoto(int index) async {
    if (!_canEdit) {
      return;
    }
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
      maxWidth: 1800,
    );
    if (picked == null || !mounted) {
      return;
    }
    final replacement = await _readPhoto(picked);
    if (!mounted) {
      return;
    }
    setState(() {
      _photos[index] = replacement;
      _clearError();
    });
  }

  void _removePhoto(int index) {
    if (!_canEdit) {
      return;
    }
    setState(() {
      _photos.removeAt(index);
      _clearError();
    });
  }

  void _clearError() {
    _error = null;
  }

  Future<void> _search() async {
    if (_photos.isEmpty || _searching) {
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
      _outcome = null;
    });
    try {
      final outcome = await widget.state.comparePhotos(
        List<MatchPhoto>.unmodifiable(_photos),
        caseType: widget.caseType,
      );
      if (mounted) {
        setState(() => _outcome = outcome);
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    } finally {
      if (mounted) {
        setState(() => _searching = false);
      }
    }
  }

  void _showResult() {
    final outcome = _outcome;
    if (outcome == null || _photos.isEmpty) {
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          probe: _photos.first.bytes,
          outcome: outcome,
          connections: widget.state.connections,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final complete = _outcome != null;
    final hasError = _error != null;
    final photoCount = _photos.length;
    final photoLabel = photoCount == 1 ? '1 photo' : '$photoCount photos';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review photos'),
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
              child: _StatusChip(
                error: hasError,
                complete: complete,
                searching: _searching,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              complete
                  ? 'Your result is ready'
                  : hasError
                      ? 'One photo needs attention'
                      : _searching
                          ? 'Checking $photoLabel...'
                          : 'Review selected photos',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.4,
                  ),
            ),
            const SizedBox(height: 7),
            Text(
              complete
                  ? 'All $photoLabel passed validation and the remote comparison finished successfully.'
                  : hasError
                      ? _error.toString()
                      : _searching
                          ? 'Each photo is being validated before the remote comparison.'
                          : 'Remove or replace any photo before starting the search.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: brandMuted,
                height: 1.45,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 18),
            if (_photos.isEmpty)
              _EmptySelection(onAdd: _addPhotos)
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _photos.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: .76,
                ),
                itemBuilder: (context, index) {
                  return _EditablePhotoCard(
                    key: ValueKey('photo-card-$index'),
                    photo: _photos[index],
                    number: index + 1,
                    rejected: index == _rejectedPhotoIndex,
                    editable: _canEdit,
                    onRemove: () => _removePhoto(index),
                    onReplace: () => _replacePhoto(index),
                  );
                },
              ),
            if (_photos.isNotEmpty && _photos.length < 5 && _canEdit) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const ValueKey('add-photos-button'),
                onPressed: _addPhotos,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text('Add photos (${_photos.length}/5)'),
              ),
            ],
            const SizedBox(height: 18),
            if (_searching) ...[
              const ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(20)),
                child: LinearProgressIndicator(
                  minHeight: 7,
                  color: brandPurple,
                  backgroundColor: brandLavender,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Processing on the remote recognition service',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: brandMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ] else if (complete)
              FilledButton.icon(
                onPressed: _showResult,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('View result'),
              )
            else
              FilledButton.icon(
                key: const ValueKey('search-photos-button'),
                onPressed: _photos.isEmpty ? null : _search,
                icon: Icon(
                  hasError ? Icons.refresh_rounded : Icons.search_rounded,
                ),
                label: Text(hasError ? 'Try again' : 'Search for matches'),
              ),
            if (hasError && _rejectedPhotoIndex != null) ...[
              const SizedBox(height: 10),
              Text(
                'Photo ${_rejectedPhotoIndex! + 1} is highlighted. '
                'Remove or replace it, then try again.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFD45757),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: _searching ? null : () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Choose different photos'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Recognition and matching run on the configured remote service',
              textAlign: TextAlign.center,
              style: TextStyle(color: brandMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.error,
    required this.complete,
    required this.searching,
  });

  final bool error;
  final bool complete;
  final bool searching;

  @override
  Widget build(BuildContext context) {
    final color = error
        ? const Color(0xFFD45757)
        : complete
            ? brandGreen
            : brandPurple;
    final background = error
        ? const Color(0xFFFFEDED)
        : complete
            ? const Color(0xFFE9F9F1)
            : brandLavender;
    final icon = error
        ? Icons.error_outline_rounded
        : complete
            ? Icons.check_circle_outline_rounded
            : searching
                ? Icons.radar_rounded
                : Icons.photo_library_outlined;
    final label = error
        ? 'PHOTO NEEDS ATTENTION'
        : complete
            ? 'SEARCH COMPLETE'
            : searching
                ? 'REMOTE SEARCH ACTIVE'
                : 'READY TO REVIEW';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: .6,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditablePhotoCard extends StatelessWidget {
  const _EditablePhotoCard({
    super.key,
    required this.photo,
    required this.number,
    required this.rejected,
    required this.editable,
    required this.onRemove,
    required this.onReplace,
  });

  final MatchPhoto photo;
  final int number;
  final bool rejected;
  final bool editable;
  final VoidCallback onRemove;
  final VoidCallback onReplace;

  @override
  Widget build(BuildContext context) {
    final borderColor = rejected ? const Color(0xFFD45757) : brandBorder;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: borderColor, width: rejected ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(photo.bytes, fit: BoxFit.cover),
                Positioned(
                  left: 8,
                  top: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: rejected
                          ? const Color(0xFFD45757)
                          : brandInk.withValues(alpha: .76),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      rejected ? 'PHOTO $number • CHECK' : 'PHOTO $number',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                if (editable)
                  Positioned(
                    right: 5,
                    top: 5,
                    child: IconButton(
                      key: ValueKey('remove-photo-${number - 1}'),
                      tooltip: 'Remove photo $number',
                      onPressed: onRemove,
                      style: IconButton.styleFrom(
                        backgroundColor: brandInk.withValues(alpha: .74),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(34, 34),
                        padding: const EdgeInsets.all(7),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    photo.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (editable)
                  TextButton(
                    key: ValueKey('replace-photo-${number - 1}'),
                    onPressed: onReplace,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      textStyle: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    child: const Text('Replace'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySelection extends StatelessWidget {
  const _EmptySelection({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 26),
      decoration: BoxDecoration(
        color: brandLavender,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: brandBorder),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.add_photo_alternate_outlined,
            color: brandPurple,
            size: 36,
          ),
          const SizedBox(height: 12),
          const Text(
            'Add at least one photo',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'You can add up to five clear photos of the same person.',
            textAlign: TextAlign.center,
            style: TextStyle(color: brandMuted, height: 1.4),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: const ValueKey('add-photos-empty-button'),
            onPressed: onAdd,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Add photos'),
          ),
        ],
      ),
    );
  }
}
