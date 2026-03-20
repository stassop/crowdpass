import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

/// Custom exception for image file operations.
class ImageFileException implements Exception {
  final String message;
  final String? path;

  ImageFileException(this.message, {this.path});

  @override
  String toString() => path != null
      ? 'ImageFileException: $message (Path: $path)'
      : 'ImageFileException: $message';
}

class ImageFileService {
  ImageFileService._();

  static const int _maxFileSize = 5 * 1024 * 1024; // 5MB
  static const Map<String, String> _supportedFormats = {
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.png': 'image/png',
  };

  /// Uploads an image with step-by-step error handling and deduplication.
  static Future<String> uploadImageFile(
    String filePath,
    String storageDir,
  ) async {
    try {
      // Ensure Firebase is initialized
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      final file = File(filePath);

      // 1. Validate File Existence
      if (!await file.exists()) {
        throw ImageFileException(
          'The selected file was not found.',
          path: filePath,
        );
      }

      // 2. Validate Format
      final extension = path.extension(filePath).toLowerCase();
      final contentType = _supportedFormats[extension];
      if (contentType == null) {
        throw ImageFileException(
          'Unsupported format. Please use JPG or PNG.',
          path: filePath,
        );
      }

      // 3. Validate Size
      if (await file.length() > _maxFileSize) {
        throw ImageFileException(
          'File is too large. Maximum size is 5MB.',
          path: filePath,
        );
      }

      // 4. Generate Hash (for deduplication)
      final String hash;
      try {
        hash = await hashImageFile(filePath);
      } catch (e) {
        throw ImageFileException(
          'Failed to process image data: $e',
          path: filePath,
        );
      }

      final normalizedDir = storageDir.isNotEmpty && !storageDir.endsWith('/')
          ? '$storageDir/'
          : storageDir;

      final storagePath = '$normalizedDir$hash$extension';
      final refStorage = FirebaseStorage.instance.ref().child(storagePath);

      // 5. Deduplication: Check if file already exists
      try {
        // If this succeeds, the file is already there. Return the URL.
        return await refStorage.getDownloadURL();
      } catch (e) {
        // If it fails (usually 404), it doesn't exist yet. Proceed to upload.
      }

      // 6. Upload File
      try {
        await _retryOnUnauthorized(
          () => refStorage.putFile(
            file,
            SettableMetadata(
              contentType: contentType,
              cacheControl: 'public, max-age=31536000',
            ),
          ),
        );
      } on FirebaseException catch (e) {
        throw ImageFileException(_handleError(e), path: filePath);
      }

      // 7. Return Final URL
      return await refStorage.getDownloadURL();
    } on ImageFileException {
      rethrow;
    } catch (e) {
      throw ImageFileException(
        'An unexpected error occurred: $e',
        path: filePath,
      );
    }
  }

  /// Deletes a single image by its URL.
  static Future<void> deleteImage(String url) async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      final refStorage = FirebaseStorage.instance.refFromURL(url);
      await refStorage.delete();
    } on FirebaseException catch (e) {
      throw ImageFileException(_handleError(e), path: url);
    } catch (e) {
      throw ImageFileException(
        'An unexpected error occurred during deletion: $e',
        path: url,
      );
    }
  }

  /// Deletes multiple images by their URLs.
  static Future<void> deleteImages(List<String> urls) async {
    if (urls.isEmpty) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      // Execute deletions in parallel
      await Future.wait(urls.map((url) async {
        final refStorage = FirebaseStorage.instance.refFromURL(url);
        await refStorage.delete();
      }));
    } on FirebaseException catch (e) {
      throw ImageFileException(_handleError(e), path: urls.join(', '));
    } catch (e) {
      throw ImageFileException(
        'An unexpected error occurred during batch deletion: $e',
        path: urls.join(', '),
      );
    }
  }

  /// Returns URLs of all images in a directory.
  static Future<List<String>> listImages(String storageDir) async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      final normalizedDir = storageDir.isNotEmpty && !storageDir.endsWith('/')
          ? '$storageDir/'
          : storageDir;
          
      final listResult = await FirebaseStorage.instance.ref().child(normalizedDir).listAll();
      final urls = await Future.wait(listResult.items.map((ref) => ref.getDownloadURL()));
      return urls;
    } on FirebaseException catch (e) {
      throw ImageFileException(_handleError(e), path: storageDir);
    } catch (e) {
      throw ImageFileException(
        'An unexpected error occurred while listing images: $e',
        path: storageDir,
      );
    }
  }

  /// Helper to retry an action once if it fails due to unauthorized status.
  static Future<T> _retryOnUnauthorized<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseException catch (e) {
      if (e.code == 'unauthorized') {
        await Future.delayed(const Duration(milliseconds: 1000));
        return await action();
      }
      rethrow;
    }
  }

  /// Maps Firebase error codes to user-friendly messages.
  static String _handleError(dynamic error) {
    if (error is! FirebaseException) {
      return 'An unknown error occurred.';
    }

    switch (error.code) {
      case 'unauthorized':
        return 'Permission denied. Please check your login status.';
      case 'canceled':
        return 'Operation was canceled.';
      case 'quota-exceeded':
        return 'Storage quota exceeded. Please contact support.';
      case 'retry-limit-exceeded':
        return 'Network timeout. Please check your connection.';
      case 'not-found':
      case 'object-not-found':
        return 'The file was not found on the server.';
      case 'invalid-checksum':
        return 'The upload was corrupted. Please try again.';
      default:
        return 'Storage error: ${error.message ?? "Unknown error"}';
    }
  }

  // --- Helper Methods ---

  static Future<String> uploadImage(String filePath, [String storageDir = '']) async {
    return await uploadImageFile(filePath, storageDir);
  }

  static Future<List<String>> uploadImages(List<String> filePaths, [String storageDir = '']) async {
    return await Future.wait(filePaths.map((p) => uploadImageFile(p, storageDir)));
  }

  static Future<String> hashImageFile(String filePath) async {
    final file = File(filePath);
    try {
      if (!await file.exists()) {
        throw ImageFileException('File does not exist.', path: filePath);
      }
      return await _hashFile(file);
    } on FileSystemException catch (e) {
      throw ImageFileException('File system error: ${e.message}', path: e.path);
    }
  }

  /// Generates SHA-256 hash using stream processing for memory efficiency.
  static Future<String> _hashFile(File file) async {
    // bind() returns a stream that emits a single Digest 
    // after the source stream (file) is fully processed.
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  /// Compares two files using SHA-256 hash to determine if they are identical.
  static Future<bool> isIdenticalFile(String filePath1, String filePath2) async {
    final file1 = File(filePath1);
    final file2 = File(filePath2);

    try {
      final existsResults = await Future.wait([file1.exists(), file2.exists()]);
      if (!existsResults[0] || !existsResults[1]) return false;

      // Quick check: If sizes differ, files cannot be identical
      final lengths = await Future.wait([file1.length(), file2.length()]);
      if (lengths[0] != lengths[1]) return false;

      // Deep check: Compare hashes
      final hash1 = await _hashFile(file1);
      final hash2 = await _hashFile(file2);

      return hash1 == hash2;
    } on FileSystemException catch (e) {
      throw ImageFileException(
        'File system error during comparison: ${e.message}',
        path: e.path,
      );
    } catch (e) {
      throw ImageFileException('Unexpected error during file comparison: $e');
    }
  }
}