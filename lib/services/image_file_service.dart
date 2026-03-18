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
  String toString() => path != null ? 'ImageFileException: $message (Path: $path)' : 'ImageFileException: $message';
}

class ImageFileService {
  ImageFileService._();

  static const int _maxFileSize = 5 * 1024 * 1024;
  static const Map<String, String> _supportedFormats = {
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.png': 'image/png',
  };

  /// Uploads an image with step-by-step error handling and deduplication.
  static Future<String> uploadImageFile(String filePath, String storageDir) async {
    try {
      // Ensure Firebase is initialized
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      final file = File(filePath);

      // 1. Validate File Existence
      if (!await file.exists()) {
        throw ImageFileException('The selected file was not found.', path: filePath);
      }

      // 2. Validate Format
      final extension = path.extension(filePath).toLowerCase();
      final contentType = _supportedFormats[extension];
      if (contentType == null) {
        throw ImageFileException('Unsupported format. Please use JPG or PNG.', path: filePath);
      }

      // 3. Validate Size
      if (await file.length() > _maxFileSize) {
        throw ImageFileException('File is too large. Maximum size is 5MB.', path: filePath);
      }

      // 4. Generate Hash
      final String hash;
      try {
        hash = await ImageFileService.hashImageFile(filePath);
      } catch (e) {
        throw ImageFileException('Failed to process image data: $e', path: filePath);
      }

      final normalizedDir =
          storageDir.isNotEmpty && !storageDir.endsWith('/')
              ? '$storageDir/'
              : storageDir;

      final storagePath = '$normalizedDir$hash$extension';
      final refStorage = FirebaseStorage.instance.ref().child(storagePath);

      // 5. Deduplication (FIXED)
      try {
        final existingURL = await refStorage.getDownloadURL();
        // If this succeeds → file already exists → reuse it
        return existingURL;
      } on FirebaseException catch (e) {
        if (e.code != 'not-found') {
          throw ImageFileException(_handleError(e), path: filePath);
        }
      }

      // 6. Upload File
      try {
        await _retryOnUnauthorized(() => refStorage.putFile(
          file,
          SettableMetadata(
            contentType: contentType,
            cacheControl: 'public, max-age=31536000',
          ),
        ));
      } on FirebaseException catch (e) {
        throw ImageFileException(_handleError(e), path: filePath);
      }

      // 7. Return Final URL
      return await refStorage.getDownloadURL();

    } on ImageFileException {
      rethrow;
    } catch (e) {
      throw ImageFileException('An unexpected error occurred: $e', path: filePath);
    }
  }

  /// Retries an asynchronous action if it fails due to an unauthorized error.
  /// Useful for handling transient auth issues during uploads.
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

  /// Maps Firebase and Storage error codes to user-friendly messages.
  static String _handleError(dynamic error) {
    if (error is! FirebaseException) {
      return 'An unknown error occurred during the upload.';
    }

    switch (error.code) {
      case 'unauthorized':
        return 'Permission denied. Please check your login status.';
      case 'canceled':
        return 'Upload was canceled by the user.';
      case 'quota-exceeded':
        return 'Storage quota exceeded. Please contact support.';
      case 'retry-limit-exceeded':
        return 'Network issues. The upload timed out. Please try again.';
      case 'not-found':
        return 'The requested file was not found on the server.';
      case 'invalid-checksum':
        return 'The upload was corrupted. Please try again.';
      default:
        return 'Upload failed: ${error.message ?? "Unknown error"}';
    }
  }

  // --- Keep existing helper methods below ---
  
  static Future<String> uploadImage(String filePath, [String storageDir = '']) async {
    return await uploadImageFile(filePath, storageDir);
  }

  static Future<List<String>> uploadImages(List<String> filePaths, [String storageDir = '']) async {
    return await Future.wait(filePaths.map((p) => uploadImageFile(p, storageDir)));
  }

  static Future<String> hashImageFile(String filePath) async {
    final file = File(filePath);
    try {
      if (!await file.exists()) throw ImageFileException('File does not exist.', path: filePath);
      return await _hashFile(file);
    } on FileSystemException catch (e) {
      throw ImageFileException('File system error: ${e.message}', path: e.path);
    }
  }

  static Future<String> _hashFile(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  /// Compares two files for identity using SHA-256 hash.
  ///
  /// Returns `true` if files are identical, `false` otherwise.
  ///
  /// - Returns false if either file does not exist.
  /// - Uses file size check as a quick early exit.
  /// - Uses streaming hash computation for memory efficiency.
  ///
  /// Throws [ImageFileException] if file access fails.
  static Future<bool> isIdenticalFile(
    String filePath1,
    String filePath2,
  ) async {
    final file1 = File(filePath1);
    final file2 = File(filePath2);

    try {
      // Check existence in parallel
      final existsResults =
          await Future.wait([file1.exists(), file2.exists()]);

      if (!existsResults[0] || !existsResults[1]) {
        return false;
      }

      // Quick size check before hashing
      final lengths =
          await Future.wait([file1.length(), file2.length()]);

      if (lengths[0] != lengths[1]) {
        return false;
      }

      // Stream-based hashing (constant memory)
      final hash1 = await _hashFile(file1);
      final hash2 = await _hashFile(file2);

      return hash1 == hash2;
    } on FileSystemException catch (e) {
      throw ImageFileException(
        'File system error during file comparison: ${e.message}',
        path: e.path,
      );
    } catch (e) {
      throw ImageFileException(
        'Unexpected error during file comparison: $e',
      );
    }
  }
}