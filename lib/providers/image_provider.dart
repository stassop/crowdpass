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

  Future<String> uploadImage(String filePath, [String storageDir = '']) async {
    // Only update state if we aren't doing a bulk upload 
    // to avoid UI "flicker" between multiple images.
    state = const AsyncValue.loading();

    try {
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

      // Check existence
      try {
        final existingUrl = await refStorage.getDownloadURL();
        state = AsyncValue.data(existingUrl);
        return existingUrl;
      } on FirebaseException catch (e) {
        if (e.code != 'object-not-found') rethrow;
      }

      // Upload with metadata
      await refStorage.putFile(
        file,
        SettableMetadata(contentType: contentType),
      );

      final url = await refStorage.getDownloadURL();
      state = AsyncValue.data(url);
      return url;

    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Bulk upload: Note that this will currently result in the 
  /// LAST image URL being the final state of the notifier.
  Future<List<String>> uploadImages(List<String> filePaths, [String storageDir = '']) async {
    try {
      final urls = await Future.wait(
        filePaths.map((p) => uploadImage(p, storageDir))
      );
      // Explicitly set state to the last URL or handle as a list
      state = AsyncValue.data(urls.isNotEmpty ? urls.last : null);
      return urls;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}