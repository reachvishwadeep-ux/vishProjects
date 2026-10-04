import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Picks a photo and shrinks it before upload.
///
/// The model consumes a 112x112 aligned crop, so anything beyond ~1280px on the
/// long edge is wasted bandwidth with no effect on accuracy.
class ImageSourceService {
  ImageSourceService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  static const int _maxEdge = 1280;
  static const int _jpegQuality = 85;

  Future<File?> pick(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 100);
    if (picked == null) {
      return null;
    }
    return _compress(File(picked.path));
  }

  Future<File> _compress(File input) async {
    final dir = await getTemporaryDirectory();
    final target =
        '${dir.path}/upload_${DateTime.now().microsecondsSinceEpoch}.jpg';
    final result = await FlutterImageCompress.compressAndGetFile(
      input.absolute.path,
      target,
      minWidth: _maxEdge,
      minHeight: _maxEdge,
      quality: _jpegQuality,
    );
    return result == null ? input : File(result.path);
  }
}
