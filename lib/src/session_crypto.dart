import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

import 'encrypted_payload.dart';
import 'identity_keys.dart';
import 'public_identity.dart';

/// Handles encryption and decryption for a specific peer-to-peer session.
class SessionCrypto {
  final IdentityKeys _selfKeys;
  final PublicIdentity _peerIdentity;

  // We used X25519 for key exchange, now we need a shared secret.
  // We will derive a symmetric key from the shared secret.
  // Spec mentions X25519 and ChaCha20-Poly1305.

  static final KeyExchangeAlgorithm _kexAlgo = X25519();
  static final Cipher _cipherAlgo = Chacha20.poly1305Aead();

  // We cache the shared secret key to avoid re-deriving it for every message if possible,
  // or re-derive it. `cryptography` makes it easy to just keep the SecretKey.
  // However, shared secret from ECDH is raw bytes. We need to convert it to a SecretKey
  // usable by ChaCha20.
  // We commonly use HKDF to derive a symmetric key from the ECDH shared secret.
  // But for simplicity if not strictly specified, we can just use the shared secret hash or similar.
  // agents.md says: "Deriving a shared secret via ECDH."
  // It doesn't specify HKDF, but it's best practice.
  // Let's use the shared secret directly if it fits the key size (32 bytes for ChaCha20),
  // or hashing it. X25519 shared secret is 32 bytes.
  // So we can use it directly as the ChaCha20 key.

  SecretKey? _sharedKey;

  SessionCrypto({
    required IdentityKeys selfKeys,
    required PublicIdentity peerIdentity,
  }) : _selfKeys = selfKeys,
       _peerIdentity = peerIdentity;

  /// Initializes the session by deriving the shared secret.
  /// This must be called before encrypt/decrypt?
  /// Or we can do it lazily. Let's do it lazily or in constructor.
  /// Constructor is sync, so we can't await there.
  /// We'll do it lazily.

  Future<SecretKey> _getSharedKey() async {
    if (_sharedKey != null) return _sharedKey!;

    final sharedSecret = await _kexAlgo.sharedSecretKey(
      keyPair: _selfKeys.encryptionKey,
      remotePublicKey: _peerIdentity.publicEncryptionKey,
    );

    // The shared secret is calculated.
    // We treat this shared secret as the key for ChaCha20.
    // Note: In production protocols we should use HKDF here to salt it and avoid weak keys etc.
    // checks: sharedSecret is 32 bytes (X25519). ChaCha20 takes 32 bytes.
    // So we can use it.

    _sharedKey = sharedSecret;
    return sharedSecret;
  }

  /// Encrypts data for the peer.
  Future<EncryptedPayload> encryptData(Uint8List data) async {
    final key = await _getSharedKey();

    // Encrypt
    final secretBox = await _cipherAlgo.encrypt(data, secretKey: key);

    return EncryptedPayload(
      senderPeerId: _selfKeys.publicIdentity.peerId,
      ciphertext: Uint8List.fromList(secretBox.cipherText),
      nonce: Uint8List.fromList(secretBox.nonce),
      mac: Uint8List.fromList(secretBox.mac.bytes),
    );
  }

  /// Decrypts data from the peer.
  ///
  /// Returns null if decryption fails (e.g. wrong key, bad MAC, etc).
  Future<Uint8List?> decryptData(EncryptedPayload payload) async {
    // Basic check: is this payload from the expected peer?
    if (payload.senderPeerId != _peerIdentity.peerId) {
      // In a multi-peer scenario, the IdentityManager would dispatch identifying the right SessionCrypto.
      // But if we are calling decrypt on THIS session object, we expect it to be from THIS peer.
      // However, the `agents.md` example shows:
      // `aliceSessionWithBob.decryptData(receivedPayload)`
      // So yes, we should verify sender.
      // If verification fails, we could throw or return null.
      // Let's return null to be safe/simple.
      print(
        'Sender ID mismatch. Expected ${_peerIdentity.peerId}, got ${payload.senderPeerId}',
      );
      return null;
    }

    try {
      final key = await _getSharedKey();

      final secretBox = SecretBox(
        payload.ciphertext,
        nonce: payload.nonce,
        mac: Mac(payload.mac),
      );

      final clearText = await _cipherAlgo.decrypt(secretBox, secretKey: key);

      return Uint8List.fromList(clearText);
    } catch (e) {
      // Decryption failed (MAC mismatch mostly)
      print('Decryption failed: $e');
      return null;
    }
  }
}
