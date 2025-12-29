import 'dart:convert';
import 'dart:typed_data';

/// Represents encrypted data ready for transport.
class EncryptedPayload {
  /// The peerId of the sender.
  final String senderPeerId;

  /// The encrypted data.
  final Uint8List ciphertext;

  /// The unique nonce used for the encryption.
  final Uint8List nonce;

  /// The MAC (Message Authentication Code) / Tag from the encryption.
  /// ChaCha20-Poly1305 produces a MAC that must be checked during decryption.
  final Uint8List mac;

  EncryptedPayload({
    required this.senderPeerId,
    required this.ciphertext,
    required this.nonce,
    required this.mac,
  });

  /// Creates an [EncryptedPayload] from a JSON map.
  factory EncryptedPayload.fromJson(Map<String, dynamic> json) {
    return EncryptedPayload(
      senderPeerId: json['senderPeerId'] as String,
      ciphertext: base64Decode(json['ciphertext'] as String),
      nonce: base64Decode(json['nonce'] as String),
      mac: base64Decode(json['mac'] as String),
    );
  }

  /// Serializes the payload to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'senderPeerId': senderPeerId,
      'ciphertext': base64Encode(ciphertext),
      'nonce': base64Encode(nonce),
      'mac': base64Encode(mac),
    };
  }
}
