
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

/// Custom exception for image file operations.
class ImageFileException implements Exception {
  final String message;
  final String? path;

  ImageFileException(this.message, {this.path});

  @override
  String toString() {
    if (path != null) {
      return 'ImageFileException: $message (Path: $path)';
    }
    return 'ImageFileException: $message';
  }
}

/// A service class for handling image file operations,
/// particularly for comparing and hashing image files.
///
/// Uses streaming hashes to avoid loading entire files into memory.
/// Suitable for large files and production environments.
class ImageFileService {
  ImageFileService._(); // Prevent instantiation

  static const int _maxFileSize = 5 * 1024 * 1024;

  static const Map<String, String> _supportedFormats = {
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.png': 'image/png',
  };

  /// Pure upload logic (NO state mutation)
  static Future<String> uploadFile(String filePath, String storageDir) async {
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

    final normalizedDir =
        storageDir.isNotEmpty && !storageDir.endsWith('/')
            ? '$storageDir/'
            : storageDir;

    final storagePath = '$normalizedDir$hash$extension';

    final refStorage =
        FirebaseStorage.instance.ref().child(storagePath);

    // Deduplication
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

  /// SAFE: does NOT interfere with auth flow
  static Future<String> uploadImage(String filePath,
      [String storageDir = '']) async {
    return await uploadFile(filePath, storageDir);
  }

  /// Bulk upload (safe)
  static Future<List<String>> uploadImages(List<String> filePaths,
      [String storageDir = '']) async {
    return await Future.wait(
      filePaths.map((p) => uploadFile(p, storageDir)),
    );
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

  /// Generates a SHA-256 hash for a file's content.
  ///
  /// Returns a hexadecimal string representing the SHA-256 hash.
  ///
  /// Uses streaming to avoid loading entire file into memory.
  ///
  /// Throws [ImageFileException] if reading fails.
  static Future<String> hashImageFile(String filePath) async {
    final file = File(filePath);

    try {
      if (!await file.exists()) {
        throw ImageFileException(
          'File does not exist.',
          path: filePath,
        );
      }

      return await _hashFile(file);
    } on FileSystemException catch (e) {
      throw ImageFileException(
        'File system error while generating hash: ${e.message}',
        path: e.path,
      );
    } catch (e) {
      throw ImageFileException(
        'Unexpected error while hashing file: $e',
        path: filePath,
      );
    }
  }

  /// Internal helper to compute SHA-256 hash of a file using stream.
  static Future<String> _hashFile(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }
}