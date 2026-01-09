import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Encryption Service - Multi-layer encryption without exposed keys
class EncryptionService {
  static const String _storageKey = 'byhun_user_data';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Derive encryption key from user credentials
  Future<String> _deriveKey(String username, String password) async {
    final combined = '$username:$password:byhun_salt_v2';
    final bytes = utf8.encode(combined);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  // Multi-layer encryption (with optional private key for commercial apps)
  Future<Uint8List> encryptData(
    Uint8List data,
    String appId, {
    String? privateKey,
  }) async {
    try {
      // If private key is provided, use it as an additional layer
      final baseKey = privateKey != null
          ? sha256.convert(utf8.encode('$appId:$privateKey')).toString()
          : sha256.convert(utf8.encode(appId)).toString();

      // Layer 1: AES encryption with app ID (and private key if provided) as key
      final key1 = sha256
          .convert(utf8.encode('$baseKey:layer1'))
          .toString()
          .substring(0, 32);
      final iv1 = encrypt.IV.fromLength(16);
      final encrypter1 = encrypt.Encrypter(
        encrypt.AES(encrypt.Key.fromBase64(base64Encode(utf8.encode(key1)))),
      );
      final encrypted1 = encrypter1.encryptBytes(data, iv: iv1);

      // Layer 2: XOR with derived key (includes private key if provided)
      final key2 = sha256
          .convert(utf8.encode('$baseKey:layer2:byhun'))
          .toString();
      final key2Bytes = utf8.encode(key2.substring(0, 32));
      final data2 = encrypted1.bytes;
      final encrypted2 = Uint8List(data2.length);
      for (int i = 0; i < data2.length; i++) {
        encrypted2[i] = data2[i] ^ key2Bytes[i % key2Bytes.length];
      }

      // Layer 3: Final AES encryption (includes private key if provided)
      final key3 = sha256
          .convert(utf8.encode('$baseKey:layer3:final'))
          .toString()
          .substring(0, 32);
      final iv3 = encrypt.IV.fromLength(16);
      final encrypter3 = encrypt.Encrypter(
        encrypt.AES(encrypt.Key.fromBase64(base64Encode(utf8.encode(key3)))),
      );
      final encrypted3 = encrypter3.encryptBytes(encrypted2, iv: iv3);

      // Layer 4: Additional private key layer (if provided)
      if (privateKey != null) {
        final privateKeyHash = sha256
            .convert(utf8.encode('$privateKey:byhun:private'))
            .toString();
        final privateKeyBytes = utf8.encode(privateKeyHash.substring(0, 32));
        final encrypted4 = Uint8List(encrypted3.bytes.length);
        for (int i = 0; i < encrypted3.bytes.length; i++) {
          encrypted4[i] = encrypted3.bytes[i] ^ privateKeyBytes[i % privateKeyBytes.length];
        }

        // Combine IVs, private key flag (1 byte), and encrypted data
        final result = Uint8List(16 + 16 + 1 + encrypted4.length);
        result.setRange(0, 16, iv1.bytes);
        result.setRange(16, 32, iv3.bytes);
        result[32] = 1; // Flag indicating private key was used
        result.setRange(33, result.length, encrypted4);

        return result;
      }

      // Combine IVs, private key flag (1 byte), and encrypted data
      final result = Uint8List(16 + 16 + 1 + encrypted3.bytes.length);
      result.setRange(0, 16, iv1.bytes);
      result.setRange(16, 32, iv3.bytes);
      result[32] = 0; // Flag indicating no private key
      result.setRange(33, result.length, encrypted3.bytes);

      return result;
    } catch (e) {
      throw Exception('Encryption failed: $e');
    }
  }

  // Multi-layer decryption (with optional private key for commercial apps)
  Future<Uint8List> decryptData(
    Uint8List encryptedData,
    String appId, {
    String? privateKey,
  }) async {
    try {
      if (encryptedData.length < 33) {
        throw Exception('Invalid encrypted data length');
      }

      // Extract IVs and private key flag
      final iv1 = encrypt.IV(encryptedData.sublist(0, 16));
      final iv3 = encrypt.IV(encryptedData.sublist(16, 32));
      final isPrivate = encryptedData[32] == 1;
      final encryptedPayload = encryptedData.sublist(33);

      // Check if private key is required but not provided
      if (isPrivate && privateKey == null) {
        throw Exception(
          'This is a private/commercial app. A private key is required to decrypt.',
        );
      }

      // Check if private key is provided but not required
      if (!isPrivate && privateKey != null) {
        // Try with private key anyway (backward compatibility)
      }

      // Derive base key
      final baseKey = privateKey != null
          ? sha256.convert(utf8.encode('$appId:$privateKey')).toString()
          : sha256.convert(utf8.encode(appId)).toString();

      // Layer 4: Remove private key layer (if present)
      Uint8List decrypted4;
      if (isPrivate && privateKey != null) {
        final privateKeyHash = sha256
            .convert(utf8.encode('$privateKey:byhun:private'))
            .toString();
        final privateKeyBytes = utf8.encode(privateKeyHash.substring(0, 32));
        decrypted4 = Uint8List(encryptedPayload.length);
        for (int i = 0; i < encryptedPayload.length; i++) {
          decrypted4[i] = encryptedPayload[i] ^ privateKeyBytes[i % privateKeyBytes.length];
        }
      } else {
        decrypted4 = encryptedPayload;
      }

      // Layer 3: Decrypt
      final key3 = sha256
          .convert(utf8.encode('$baseKey:layer3:final'))
          .toString()
          .substring(0, 32);
      final encrypter3 = encrypt.Encrypter(
        encrypt.AES(encrypt.Key.fromBase64(base64Encode(utf8.encode(key3)))),
      );
      final decrypted3 = encrypter3.decryptBytes(
        encrypt.Encrypted(decrypted4),
        iv: iv3,
      );

      // Layer 2: XOR reverse
      final key2 = sha256
          .convert(utf8.encode('$baseKey:layer2:byhun'))
          .toString();
      final key2Bytes = utf8.encode(key2.substring(0, 32));
      final decrypted2 = Uint8List(decrypted3.length);
      for (int i = 0; i < decrypted3.length; i++) {
        decrypted2[i] = decrypted3[i] ^ key2Bytes[i % key2Bytes.length];
      }

      // Layer 1: Final decrypt
      final key1 = sha256
          .convert(utf8.encode('$baseKey:layer1'))
          .toString()
          .substring(0, 32);
      final encrypter1 = encrypt.Encrypter(
        encrypt.AES(encrypt.Key.fromBase64(base64Encode(utf8.encode(key1)))),
      );
      final decrypted1 = encrypter1.decryptBytes(
        encrypt.Encrypted(decrypted2),
        iv: iv1,
      );

      return Uint8List.fromList(decrypted1);
    } catch (e) {
      throw Exception('Decryption failed: $e');
    }
  }

  // Save encrypted user data
  Future<void> saveUserData(String username, String password) async {
    final key = await _deriveKey(username, password);
    await _storage.write(key: _storageKey, value: key);
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final keys = await _storage.readAll();
    return keys.containsKey(_storageKey);
  }

  // Clear user data
  Future<void> logout() async {
    await _storage.deleteAll();
  }
}
