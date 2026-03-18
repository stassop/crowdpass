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
        throw ImageFileException('File is too large. Maximum size is 5MB.');
      }

      // 4. Generate Hash
      final String hash;
      try {
        hash = await ImageFileService.hashImageFile(filePath);
      } catch (e) {
        throw ImageFileException('Failed to process image data: $e');
      }

      final normalizedDir = storageDir.isNotEmpty && !storageDir.endsWith('/') ? '$storageDir/' : storageDir;
      final storagePath = '$normalizedDir$hash$extension';
      final refStorage = FirebaseStorage.instance.ref().child(storagePath);

      // 5. Deduplication Check
      try {
        return await refStorage.getDownloadURL();
      } on FirebaseException catch (e) {
        // If it's anything other than 'not found', handle it as a storage error
        if (e.code != 'object-not-found') {
          throw ImageFileException(handleError(e));
        }
      }

      // 6. Upload File
      try {
        await refStorage.putFile(
          file,
          SettableMetadata(contentType: contentType),
        );
      } on FirebaseException catch (e) {
        throw ImageFileException(handleError(e));
      }

      // 7. Return Final URL
      return await refStorage.getDownloadURL();
      
    } on ImageFileException {
      rethrow; // Pass through custom exceptions
    } catch (e) {
      throw ImageFileException('An unexpected error occurred: $e');
    }
  }

  /// Maps Firebase and Storage error codes to user-friendly messages.
  static String handleError(dynamic error) {
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
}