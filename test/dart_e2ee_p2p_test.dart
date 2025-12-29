import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_e2ee_p2p/dart_e2ee_p2p.dart';

void main() {
  group('IdentityKeys', () {
    test('generate creates valid keys and peerId', () async {
      final keys = await IdentityKeys.generate();
      expect(keys.signingKey, isNotNull);
      expect(keys.encryptionKey, isNotNull);
      expect(keys.publicIdentity.peerId, isNotEmpty);
      expect(keys.publicIdentity.publicSigningKey, isNotNull);
      expect(keys.publicIdentity.publicEncryptionKey, isNotNull);
    });

    test('serialization and deserialization works', () async {
      final originalKeys = await IdentityKeys.generate();
      final json = await originalKeys.toJson();

      final loadedKeys = await IdentityKeys.fromJson(json);

      expect(
        loadedKeys.publicIdentity.peerId,
        originalKeys.publicIdentity.peerId,
      );
      // We can't easily compare private keys directly as they are hidden,
      // but checking public identity derived from them is a good proxy.
      expect(
        loadedKeys.publicIdentity.publicSigningKey.bytes,
        originalKeys.publicIdentity.publicSigningKey.bytes,
      );
    });
  });

  group('TrustStore', () {
    test('trustPeer and isPeerTrusted work', () async {
      final store = TrustStore();
      final keys = await IdentityKeys.generate();

      expect(store.isPeerTrusted(keys.publicIdentity.peerId), isFalse);

      store.trustPeer(keys.publicIdentity);
      expect(store.isPeerTrusted(keys.publicIdentity.peerId), isTrue);
      expect(
        store.getTrustedPeer(keys.publicIdentity.peerId),
        equals(keys.publicIdentity),
      );
    });

    test('serialization works', () async {
      final store = TrustStore();
      final keys1 = await IdentityKeys.generate();
      final keys2 = await IdentityKeys.generate();

      store.trustPeer(keys1.publicIdentity);
      store.trustPeer(keys2.publicIdentity);

      final jsonString = await store.serialize();
      final loadedStore = await TrustStore.fromSerializedAsync(jsonString);

      expect(loadedStore.isPeerTrusted(keys1.publicIdentity.peerId), isTrue);
      expect(loadedStore.isPeerTrusted(keys2.publicIdentity.peerId), isTrue);
      expect(loadedStore.getAllTrustedPeers().length, 2);
    });
  });

  group('End-to-End Encryption Flow', () {
    test('Alice and Bob can exchange encrypted messages', () async {
      // 1. Setup
      final aliceKeys = await IdentityKeys.generate();
      final bobKeys = await IdentityKeys.generate();

      final aliceStore = TrustStore();
      final bobStore = TrustStore();

      // 2. Trust Exchange
      aliceStore.trustPeer(bobKeys.publicIdentity);
      bobStore.trustPeer(aliceKeys.publicIdentity);

      final aliceManager = IdentityManager.fromKeys(aliceKeys);
      final bobManager = IdentityManager.fromKeys(bobKeys);

      // 3. Alice encrypts for Bob
      final message = 'Hello Bob!';
      final messageBytes = utf8.encode(message);

      final aliceSession = aliceManager.createSession(
        bobKeys.publicIdentity.peerId,
        aliceStore,
      );
      final encryptedPayload = await aliceSession.encryptData(messageBytes);

      expect(encryptedPayload.senderPeerId, aliceKeys.publicIdentity.peerId);
      expect(encryptedPayload.ciphertext, isNot(messageBytes));

      // 4. Bob decrypts
      final bobSession = bobManager.createSession(
        aliceKeys.publicIdentity.peerId,
        bobStore,
      );
      final decryptedBytes = await bobSession.decryptData(encryptedPayload);

      expect(decryptedBytes, isNotNull);
      expect(utf8.decode(decryptedBytes!), message);
    });

    test('Decryption fails with wrong keys (simulated)', () async {
      final aliceKeys = await IdentityKeys.generate();
      final bobKeys = await IdentityKeys.generate();
      final eveKeys = await IdentityKeys.generate();

      final aliceStore = TrustStore();
      aliceStore.trustPeer(bobKeys.publicIdentity); // Alice trusts Bob

      final aliceManager = IdentityManager.fromKeys(aliceKeys);
      final aliceSession = aliceManager.createSession(
        bobKeys.publicIdentity.peerId,
        aliceStore,
      );

      final message = utf8.encode('Secret');
      final encryptedPayload = await aliceSession.encryptData(message);

      // Eve tries to decrypt without trusting Alice or having Bob's private key
      // Eve pretends to be Bob? No, Eve has her own keys.
      // Eve cannot create a session that results in the same shared key because she lacks Bob's private key.
      // Even if Eve trusts Alice.

      final eveStore = TrustStore();
      eveStore.trustPeer(aliceKeys.publicIdentity);
      final eveManager = IdentityManager.fromKeys(eveKeys);

      final eveSession = eveManager.createSession(
        aliceKeys.publicIdentity.peerId,
        eveStore,
      );

      // Eve tries to decrypt payload intended for Bob
      final result = await eveSession.decryptData(encryptedPayload);

      // Should fail because shared secret is different (Alice-Bob vs Alice-Eve)
      // Decryption should return null (MAC verification failed) or garbage (if no MAC, but we have MAC).
      expect(result, isNull);
    });
  });
}
