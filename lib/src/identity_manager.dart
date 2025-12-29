import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

import 'identity_keys.dart';
import 'public_identity.dart';
import 'session_crypto.dart';
import 'trust_store.dart';

/// The primary entry point for performing cryptographic operations.
class IdentityManager {
  final IdentityKeys _keys;

  /// Creates an [IdentityManager] with the given [keys].
  IdentityManager.fromKeys(IdentityKeys keys) : _keys = keys;

  /// Returns the public identity of the user.
  PublicIdentity getPublicIdentity() {
    return _keys.publicIdentity;
  }

  /// Creates a session for communicating with a trusted peer.
  ///
  /// Throws [Exception] if the peer is not found in the [trustStore].
  SessionCrypto createSession(String peerId, TrustStore trustStore) {
    if (!trustStore.isPeerTrusted(peerId)) {
      throw Exception('Peer $peerId is not trusted.');
    }

    final peerIdentity = trustStore.getTrustedPeer(peerId)!;

    return SessionCrypto(selfKeys: _keys, peerIdentity: peerIdentity);
  }

  /// Signs data with the private signing key.
  Future<Uint8List> signData(Uint8List data) async {
    final signature = await Ed25519().sign(data, keyPair: _keys.signingKey);
    return Uint8List.fromList(signature.bytes);
  }
}
