import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/auth_service.dart';

/// Thrown when a message can't be encrypted because the recipient hasn't
/// uploaded a public key yet (i.e. hasn't opened the app since end-to-end
/// encryption shipped).
class RecipientKeyUnavailableException implements Exception {
  final String message;
  RecipientKeyUnavailableException([
    this.message = "This user hasn't enabled secure messaging yet.",
  ]);

  @override
  String toString() => message;
}

/// Handles end-to-end encryption for chat messages.
///
/// Scheme: X25519 key agreement + ChaCha20-Poly1305 authenticated
/// encryption (the same primitive family as libsodium's crypto_box).
/// Each device generates its own keypair; the private key is written only
/// to secure/encrypted storage and never leaves the device. Only the
/// public key is uploaded, so the backend can store and relay ciphertext
/// without ever being able to read message content.
///
/// Keypairs are stored *per signed-in account*, not just per device --
/// switching accounts on the same device (e.g. testing with two test
/// users) must not reuse one account's keypair for another, or the
/// shared-secret math breaks for everyone involved.
///
/// Note: this uses static long-term keys, not a ratcheting protocol, so it
/// does not provide forward secrecy (a compromised private key could
/// decrypt past messages). That would require a full Signal-style double
/// ratchet -- a much larger undertaking, worth doing only if the threat
/// model calls for it.
class EncryptionService {
  EncryptionService._();

  static const _storage = FlutterSecureStorage();

  static final X25519 _keyExchange = X25519();
  static final Chacha20 _cipher = Chacha20.poly1305Aead();

  /// Poly1305 MAC is always 16 bytes; used to split the stored ciphertext
  /// blob back into cipherText + mac on decrypt.
  static const int _macLength = 16;

  static SimpleKeyPair? _keyPair;

  /// Which account's keypair is currently loaded into [_keyPair]. Used to
  /// detect an account switch on the same device/process.
  static String? _activeEmail;

  static final Map<int, SecretKey> _sharedSecretCache = {};
  static final Map<int, String> _remotePublicKeyCache = {};

  /// Loads the on-device keypair *for the currently signed-in account*,
  /// generating and uploading a new one on first run for that account.
  /// Safe to call repeatedly -- it's a no-op once already initialized for
  /// the active account, but correctly re-initializes (and clears cached
  /// shared secrets) if a different account has since signed in.
  static Future<void> ensureInitialized() async {
    final email = await AuthService.getUserEmail();
    if (email == null || email.isEmpty) {
      throw StateError('Cannot set up secure messaging: no signed-in user.');
    }

    if (_keyPair != null && _activeEmail == email) return;

    // Either first run, or the signed-in account changed since we last
    // initialized -- reset everything so we don't carry over another
    // account's keypair or cached shared secrets.
    _keyPair = null;
    _sharedSecretCache.clear();
    _remotePublicKeyCache.clear();
    _activeEmail = email;

    final privateKeyStorageKey = 'e2ee_private_key:$email';
    final publicKeyStorageKey = 'e2ee_public_key:$email';

    final storedPrivate = await _storage.read(key: privateKeyStorageKey);
    final storedPublic = await _storage.read(key: publicKeyStorageKey);

    if (storedPrivate != null && storedPublic != null) {
      _keyPair = SimpleKeyPairData(
        base64Decode(storedPrivate),
        publicKey: SimplePublicKey(
          base64Decode(storedPublic),
          type: KeyPairType.x25519,
        ),
        type: KeyPairType.x25519,
      );
      return;
    }

    // First run for this account on this device (or a reinstall).
    // Re-uploading overwrites the server's record of this account's
    // public key, which means any messages encrypted under a previous
    // key become permanently undecryptable -- an inherent tradeoff of
    // E2EE, not a bug.
    final newKeyPair = await _keyExchange.newKeyPair();
    final privateBytes = await newKeyPair.extractPrivateKeyBytes();
    final publicKey = await newKeyPair.extractPublicKey();

    await _storage.write(
      key: privateKeyStorageKey,
      value: base64Encode(privateBytes),
    );
    await _storage.write(
      key: publicKeyStorageKey,
      value: base64Encode(publicKey.bytes),
    );
    _keyPair = newKeyPair;

    await ApiService.put('/api/users/public-key', {
      'publicKey': base64Encode(publicKey.bytes),
    });
  }

  /// Encrypts [plaintext] for [otherUserId]. Throws
  /// [RecipientKeyUnavailableException] if that user hasn't published a
  /// public key yet.
  static Future<({String content, String nonce})> encryptFor(
    int otherUserId,
    String plaintext,
  ) async {
    return encryptBytesFor(otherUserId, utf8.encode(plaintext));
  }

  /// Byte-level version of [encryptFor], used for both message text and
  /// file attachments so both go through the exact same cipher path.
  static Future<({String content, String nonce})> encryptBytesFor(
    int otherUserId,
    List<int> bytes,
  ) async {
    await ensureInitialized();
    final secretKey = await _sharedSecretWith(otherUserId);

    final secretBox = await _cipher.encrypt(bytes, secretKey: secretKey);

    final combined = Uint8List.fromList([
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ]);

    return (
      content: base64Encode(combined),
      nonce: base64Encode(secretBox.nonce),
    );
  }

  /// Decrypts a message from/to [otherUserId]. Returns the original
  /// [content] unchanged if [nonce] is null or empty (a pre-E2EE plaintext
  /// message from before this feature shipped), and a friendly placeholder
  /// if decryption fails for any other reason (key mismatch, corruption).
  static Future<String> decryptFrom(
    int otherUserId,
    String content,
    String? nonce,
  ) async {
    if (nonce == null || nonce.isEmpty) {
      return content;
    }
    final bytes = await decryptBytesFrom(otherUserId, content, nonce);
    if (bytes == null) return '🔒 Sent from another device';
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return '🔒 Sent from another device';
    }
  }

  /// Byte-level version of [decryptFrom]. Returns null on failure instead
  /// of a placeholder string, since callers may be decrypting binary file
  /// data where a text placeholder wouldn't make sense.
  static Future<List<int>?> decryptBytesFrom(
    int otherUserId,
    String content,
    String nonce,
  ) async {
    try {
      await ensureInitialized();
      final secretKey = await _sharedSecretWith(otherUserId);

      final combined = base64Decode(content);
      if (combined.length <= _macLength) return null;

      final cipherText = combined.sublist(0, combined.length - _macLength);
      final mac = combined.sublist(combined.length - _macLength);

      final secretBox = SecretBox(
        cipherText,
        nonce: base64Decode(nonce),
        mac: Mac(mac),
      );

      return await _cipher.decrypt(secretBox, secretKey: secretKey);
    } catch (_) {
      return null;
    }
  }

  /// Derives (and caches) the shared secret with [otherUserId]. X25519
  /// shared secrets are symmetric -- sharedSecret(myPriv, theirPub) equals
  /// sharedSecret(theirPriv, myPub) -- so this is the same key regardless
  /// of who sent a given message in the conversation.
  static Future<SecretKey> _sharedSecretWith(int otherUserId) async {
    final cached = _sharedSecretCache[otherUserId];
    if (cached != null) return cached;

    final remotePublicKeyBytes = await _remotePublicKeyBytes(otherUserId);
    final remotePublicKey = SimplePublicKey(
      remotePublicKeyBytes,
      type: KeyPairType.x25519,
    );

    final secret = await _keyExchange.sharedSecretKey(
      keyPair: _keyPair!,
      remotePublicKey: remotePublicKey,
    );
    _sharedSecretCache[otherUserId] = secret;
    return secret;
  }

  static Future<List<int>> _remotePublicKeyBytes(int otherUserId) async {
    final cached = _remotePublicKeyCache[otherUserId];
    if (cached != null) return base64Decode(cached);

    final response = await ApiService.get('/api/users/$otherUserId/public-key');
    final key = response is Map ? response['publicKey'] as String? : null;
    if (key == null || key.isEmpty) {
      throw RecipientKeyUnavailableException();
    }
    _remotePublicKeyCache[otherUserId] = key;
    return base64Decode(key);
  }
}
