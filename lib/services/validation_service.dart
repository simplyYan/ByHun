import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

// Validation Service
class ValidationService {
  // Validate .byhun file structure
  static Future<ValidationResult> validateByhunFile(
    Uint8List fileData,
    String appId,
  ) async {
    try {
      // Check minimum size (should have IVs + some encrypted data)
      if (fileData.length < 32) {
        return ValidationResult(
          isValid: false,
          error: 'File is too small. Invalid .byhun file structure.',
        );
      }

      // Check if file has proper encrypted structure (has IVs at the beginning)
      // We can't fully validate encrypted content, but we can check structure
      final iv1 = fileData.sublist(0, 16);
      final iv3 = fileData.sublist(16, 32);
      final encryptedData = fileData.sublist(32);

      if (iv1.length != 16 || iv3.length != 16 || encryptedData.isEmpty) {
        return ValidationResult(
          isValid: false,
          error: 'Invalid file structure. Missing IVs or encrypted data.',
        );
      }

      // Try to decrypt and validate ZIP structure
      try {
        // Note: This will be called after decryption, so we'll validate the decrypted ZIP
        return ValidationResult(
          isValid: true,
          message: 'File structure is valid',
        );
      } catch (e) {
        return ValidationResult(
          isValid: false,
          error: 'Failed to decrypt file: $e',
        );
      }
    } catch (e) {
      return ValidationResult(
        isValid: false,
        error: 'Validation error: $e',
      );
    }
  }

  // Validate decrypted ZIP contains index.html
  static ValidationResult validateDecryptedZip(Uint8List zipData) {
    try {
      final archive = ZipDecoder().decodeBytes(zipData);
      
      // Check if archive is not empty
      if (archive.isEmpty) {
        return ValidationResult(
          isValid: false,
          error: 'ZIP archive is empty',
        );
      }

      // Check if index.html exists
      final hasIndexHtml = archive.any(
        (file) => file.name == 'index.html' ||
            file.name == '/index.html' ||
            file.name.endsWith('/index.html'),
      );

      if (!hasIndexHtml) {
        return ValidationResult(
          isValid: false,
          error: 'ZIP file must contain an index.html file',
        );
      }

      // Validate file structure
      final fileCount = archive.length;
      final totalSize = archive.fold<int>(
        0,
        (sum, file) => sum + (file.isFile ? (file.content as List<int>).length : 0),
      );

      return ValidationResult(
        isValid: true,
        message: 'Valid ZIP structure with $fileCount files (${(totalSize / 1024).toStringAsFixed(1)} KB)',
      );
    } catch (e) {
      return ValidationResult(
        isValid: false,
        error: 'Invalid ZIP file: $e',
      );
    }
  }

  // Calculate SHA256 hash
  static String calculateSha256(Uint8List data) {
    final hash = sha256.convert(data);
    return hash.toString();
  }

  // Verify file integrity
  static bool verifyIntegrity(String storedHash, String currentHash) {
    return storedHash == currentHash;
  }
}

class ValidationResult {
  final bool isValid;
  final String? error;
  final String? message;

  ValidationResult({
    required this.isValid,
    this.error,
    this.message,
  });
}
