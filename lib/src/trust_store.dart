import 'dart:convert';

import 'public_identity.dart';

/// Manages the set of trusted peers.
///
/// This store is in-memory only. The consumer is responsible for persistence.
class TrustStore {
  // Map of peerId -> PublicIdentity
  final Map<String, PublicIdentity> _trustedPeers = {};

  TrustStore();

  /// Creates a [TrustStore] from a serialized JSON string.
  ///
  /// The [jsonString] should be the output of [serialize].
  factory TrustStore.fromSerialized(String jsonString) {
    if (jsonString.isEmpty) return TrustStore();

    final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
    final store = TrustStore();

    if (jsonMap.containsKey('peers')) {
      final peersList = jsonMap['peers'] as List;
      if (peersList.isNotEmpty) {
        throw UnimplementedError("Use fromSerializedAsync instead");
      }
    }
    return store;
  }

  /// Asynchronous factory to load from serialized string.
  static Future<TrustStore> fromSerializedAsync(String jsonString) async {
    final store = TrustStore();
    if (jsonString.isEmpty) return store;

    try {
      final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
      if (jsonMap.containsKey('peers')) {
        final peersList = jsonMap['peers'] as List;
        for (final peerJson in peersList) {
          final identity = await PublicIdentity.fromJson(peerJson);
          store._trustedPeers[identity.peerId] = identity;
        }
      }
    } catch (e) {
      // Handle corruption or format error?
      // For now, rethrow or invalid format means empty/partial store.
      print('Error loading trust store: $e');
      rethrow;
    }
    return store;
  }

  /// Serializes the current trust store to a JSON string.
  Future<String> serialize() async {
    final peersList = await Future.wait(
      _trustedPeers.values.map((p) => p.toJson()),
    );

    final jsonMap = {'peers': peersList};

    return jsonEncode(jsonMap);
  }

  /// Trusts a peer.
  ///
  /// Overwrites any existing identity for the same peerId.
  void trustPeer(PublicIdentity peerIdentity) {
    _trustedPeers[peerIdentity.peerId] = peerIdentity;
  }

  /// Checks if a peer is trusted.
  bool isPeerTrusted(String peerId) {
    return _trustedPeers.containsKey(peerId);
  }

  /// Retrieves a trusted peer's identity.
  PublicIdentity? getTrustedPeer(String peerId) {
    return _trustedPeers[peerId];
  }

  /// Returns a list of all trusted peers.
  List<PublicIdentity> getAllTrustedPeers() {
    return _trustedPeers.values.toList();
  }
}
