import 'dart:convert';
import 'package:cryptography/cryptography.dart';

/// Represents the public identity of a user, which can be safely shared.
class PublicIdentity {
  /// Unique identifier for the peer, derived from the public signing key.
  final String peerId;

  /// The public key used for verifying signatures (Ed25519).
  final SimplePublicKey publicSigningKey;

  /// The public key used for encryption (X25519).
  final SimplePublicKey publicEncryptionKey;

  PublicIdentity({
    required this.peerId,
    required this.publicSigningKey,
    required this.publicEncryptionKey,
  });

  /// Creates a [PublicIdentity] from JSON.
  static Future<PublicIdentity> fromJson(Map<String, dynamic> json) async {
    final signingKeyBytes = base64Decode(json['publicSigningKey'] as String);
    final encryptionKeyBytes = base64Decode(
      json['publicEncryptionKey'] as String,
    );

    // We assume standard algorithms here: Ed25519 and X25519
    final signingKey = SimplePublicKey(
      signingKeyBytes,
      type: KeyPairType.ed25519,
    );
    final encryptionKey = SimplePublicKey(
      encryptionKeyBytes,
      type: KeyPairType.x25519,
    );

    return PublicIdentity(
      peerId: json['peerId'] as String,
      publicSigningKey: signingKey,
      publicEncryptionKey: encryptionKey,
    );
  }

  /// Serializes the identity to JSON.
  Future<Map<String, dynamic>> toJson() async {
    return {
      'peerId': peerId,
      'publicSigningKey': base64Encode(publicSigningKey.bytes),
      'publicEncryptionKey': base64Encode(publicEncryptionKey.bytes),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PublicIdentity && other.peerId == peerId;
  }

  @override
  int get hashCode => peerId.hashCode;
}
