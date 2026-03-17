import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:crowdpass/services/image_service.dart';

final imageNotifier = AsyncNotifierProvider<ImageNotifier, String?>(
  ImageNotifier.new,
);

class ImageNotifier extends AsyncNotifier<String?> {
  static const int _maxFileSize = 5 * 1024 * 1024; // 5MB
  
  static const Map<String, String> _supportedFormats = {
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.png': 'image/png',
  };

  @override
  Future<String?> build() async => null;

  /// Internal upload logic that does not touch provider state.
  Future<String> _doUploadFile(String filePath, String storageDir) async {
    final file = File(filePath);

    if (!await file.exists()) throw Exception('File not found.');

    final extension = path.extension(filePath).toLowerCase();
    final contentType = _supportedFormats[extension];
    if (contentType == null) {
      throw Exception('Unsupported format (use JPG/PNG).');
    }

    if (await file.length() > _maxFileSize) {
      throw Exception('File exceeds 5MB limit.');
    }

    final hash = await ImageFileService.hashImageFile(filePath);
    final normalizedDir = storageDir.isNotEmpty && !storageDir.endsWith('/')
        ? '$storageDir/'
        : storageDir;

    final storagePath = '$normalizedDir$hash$extension';
    final refStorage = FirebaseStorage.instance.ref().child(storagePath);

    // Return existing URL if already uploaded (deduplication).
    try {
      return await refStorage.getDownloadURL();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }

    await refStorage.putFile(
      file,
      SettableMetadata(contentType: contentType),
    );

    return await refStorage.getDownloadURL();
  }

  Future<String> uploadImage(String filePath, [String storageDir = '']) async {
    state = const AsyncValue.loading();
    try {
      final url = await _doUploadFile(filePath, storageDir);
      state = AsyncValue.data(url);
      return url;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Bulk upload: sets state once at the start and once at the end,
  /// avoiding rapid state transitions between individual uploads.
  Future<List<String>> uploadImages(List<String> filePaths, [String storageDir = '']) async {
    state = const AsyncValue.loading();
    try {
      final urls = await Future.wait(
        filePaths.map((p) => _doUploadFile(p, storageDir)),
      );
      state = AsyncValue.data(urls.isNotEmpty ? urls.last : null);
      return urls;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}