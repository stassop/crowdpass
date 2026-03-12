import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:path/path.dart' as path;

import 'package:crowdpass/services/image_service.dart';

/// A notifier that manages image uploads and returns the download URL.
final imageProvider = AsyncNotifierProvider<ImageNotifier, String?>(
  ImageNotifier.new,
);

class ImageNotifier extends AsyncNotifier<String?> {
  static const int _maxFileSize = 5 * 1024 * 1024;
  
  static const Map<String, String> _supportedFormats = {
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.png': 'image/png',
  };

  @override
  Future<String?> build() async => null;

  /// Validates and uploads an image directly to Firebase Storage.
  Future<String> uploadImage(String filePath, [String storageDir = '']) async {
    
    state = const AsyncValue.loading();

    try {
      final file = File(filePath);

      // 1. Basic Validations
      if (!await file.exists()) throw Exception('File not found.');
      
      final extension = path.extension(filePath).toLowerCase();
      if (!_supportedFormats.containsKey(extension)) {
        throw Exception('Unsupported format (use JPG/PNG).');
      }

      if (await file.length() > _maxFileSize) {
        throw Exception('File exceeds 5MB limit.');
      }

      // 2. Generate Storage Reference
      final hash = await ImageFileService.hashImageFile(filePath);
      // Make sure storageDir ends with a slash
      if (storageDir.isNotEmpty && !storageDir.endsWith('/')) storageDir += '/';
      final storagePath = '$storageDir$hash$extension';
      
      // Directly calling the instance
      final refStorage = FirebaseStorage.instance.ref().child(storagePath);

      // 3. Deduplication Check
      // Using getDownloadURL is the most stable way to check existence in the emulator.
      try {
        final existingUrl = await refStorage.getDownloadURL();
        state = AsyncValue.data(existingUrl);
        return existingUrl;
      } catch (_) {
        // If it throws, the file doesn't exist yet. Proceed to upload.
      }

      // 4. Upload Task
      // Awaiting the task directly prevents the 'hang' often seen in emulators.
      await refStorage.putFile(
        file,
        SettableMetadata(contentType: _supportedFormats[extension]),
      );

      // 5. Finalize
      final url = await refStorage.getDownloadURL();
      state = AsyncValue.data(url);
      return url;

    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  // Optimized Parallel Upload
  Future<List<String>> uploadImages(List<String> filePaths, [String storageDir = '']) async {
    // Use Future.wait for parallel execution
    final uploadTasks = filePaths.map((path) => uploadImage(path, storageDir)).toList();
    
    try {
      final urls = await Future.wait(uploadTasks);
      // Return the full list (duplicates preserved, order maintained)
      return urls;
    } catch (e) {
      // Handle partial failures or rethrow
      rethrow;
    }
  }
}