import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart' as crypto_hash;

import 'public_identity.dart';

/// Holds the sensitive private keys for identity and encryption.
///
/// This class MUST be stored securely by the consuming application.
class IdentityKeys {
  /// Private signing key (Ed25519).
  final SimpleKeyPair signingKey;

  /// Private encryption key (X25519).
  final SimpleKeyPair encryptionKey;

  /// The public identity associated with these keys.
  final PublicIdentity publicIdentity;

  IdentityKeys._({
    required this.signingKey,
    required this.encryptionKey,
    required this.publicIdentity,
  });

  /// Generates a new identity with fresh keypairs.
  static Future<IdentityKeys> generate() async {
    final signatureAlgo = Ed25519();
    final keyExchangeAlgo = X25519();

    final signingKey = await signatureAlgo.newKeyPair();
    final encryptionKey = await keyExchangeAlgo.newKeyPair();

    final publicSigning = await signingKey.extractPublicKey();
    final publicEncryption = await encryptionKey.extractPublicKey();

    // Derive peerId from the public signing key bytes.
    // Using SHA-256 hash of the public signing key as the ID.
    // This is a simple, deterministic way to get a unique ID.
    final digest = crypto_hash.sha256.convert(publicSigning.bytes);

    // NOTE: In a real distributed system, we might want a longer ID, but 8 bytes (16 hex) is reasonable for small p2p groups.
    // Let's use the full SHA256 hex or base32 if we want collision resistance globally.
    // Spec says "derived from a hash", let's use full hex.
    final peerIdFull = hex.encode(digest.bytes);

    final publicIdentity = PublicIdentity(
      peerId: peerIdFull,
      publicSigningKey: publicSigning,
      publicEncryptionKey: publicEncryption,
    );

    return IdentityKeys._(
      signingKey: signingKey,
      encryptionKey: encryptionKey,
      publicIdentity: publicIdentity,
    );
  }

  /// Creates [IdentityKeys] from a JSON map (e.g. loaded from secure storage).
  static Future<IdentityKeys> fromJson(Map<String, dynamic> json) async {
    final signingKeyData = base64Decode(json['signingKey'] as String);
    final encryptionKeyData = base64Decode(json['encryptionKey'] as String);

    final signingKey = await Ed25519().newKeyPairFromSeed(signingKeyData);
    final encryptionKey = await X25519().newKeyPairFromSeed(encryptionKeyData);

    // Reconstruct public identity
    final publicSigning = await signingKey.extractPublicKey();
    final publicEncryption = await encryptionKey.extractPublicKey();

    final digest = crypto_hash.sha256.convert(publicSigning.bytes);
    final peerIdFull = hex.encode(digest.bytes);

    // Verify it matches if provided
    if (json.containsKey('peerId')) {
      final storedPeerId = json['peerId'] as String;
      if (storedPeerId != peerIdFull) {
        throw Exception(
          'Stored peerId $storedPeerId does not match derived peerId $peerIdFull',
        );
      }
    }

    final publicIdentity = PublicIdentity(
      peerId: peerIdFull,
      publicSigningKey: publicSigning,
      publicEncryptionKey: publicEncryption,
    );

    return IdentityKeys._(
      signingKey: signingKey,
      encryptionKey: encryptionKey,
      publicIdentity: publicIdentity,
    );
  }

  /// Serializes the private keys to JSON.
  ///
  /// **WARNING**: The output contains SENSITIVE PRIVATE KEYS.
  /// Store this result securely!
  Future<Map<String, dynamic>> toJson() async {
    // We need the seed or private bytes.
    // For Ed25519 and X25519 in `cryptography` package, extractPrivateKeyBytes() or seed.
    // `SimpleKeyPair` created with `newKeyPair` usually has random bytes.
    // We need to extract the raw private key bytes.

    final signingBytes = await signingKey.extractPrivateKeyBytes();
    final encryptionBytes = await encryptionKey.extractPrivateKeyBytes();

    return {
      'signingKey': base64Encode(signingBytes),
      'encryptionKey': base64Encode(encryptionBytes),
      // We don't strictly need to store pub keys as they are derived,
      // but we could store peerId for quick lookup without derivation.
      'peerId': publicIdentity.peerId,
    };
  }
}
