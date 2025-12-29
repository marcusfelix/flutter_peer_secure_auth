# AGENTS.MD: Cryptographic Identity & Encryption Layer (Pure Dart)

## 1. High-Level Overview

This document designs a **pure Dart package** for cryptographic identity, peer
authentication, and end-to-end encryption. It provides a simple, explicit, and
safe API for developers using Dart and Flutter.

The core concept is that identity is purely cryptographic, represented by a
keypair. This package **generates and manages keys in-memory** but **does not
handle storage**. The consuming application is responsible for securely
persisting and loading cryptographic keys and trust data.

Trust is established manually and offline between peers by exchanging public
keys (e.g., via QR code). Once trusted, peers can derive session keys to encrypt
all data exchanged between them. This ensures data is protected in transit and
allows the consumer to build systems that protect data at rest.

This package is **only** responsible for identity and cryptographic operations,
not networking or storage.

---

## 2. Core Principles

- **Cryptographic Identity**: Identity is a keypair. No phone numbers, emails,
  or servers.
- **Caller-Owned Storage**: The package is stateless. The calling application is
  responsible for all persistence (e.g., storing private keys in
  `flutter_secure_storage` and trust data in a database).
- **Offline Trust Establishment**: Peers must exchange public keys offline to
  prevent man-in-the-middle attacks.
- **Encrypt Everything**: All application-level data is encrypted before being
  handed to the transport layer.
- **Proven Cryptography**: Use well-established, audited cryptographic
  primitives (X25519, Ed25519, ChaCha20-Poly1305).
- **Clarity Over Cleverness**: The design prioritizes readability and
  maintainability.

---

## 3. Core Classes and Responsibilities

### `IdentityKeys`

A simple, serializable data class holding the sensitive private and public
keypairs. **This object must be handled with care by the consuming application
and stored securely.**

- **Properties**:
  - `signingKey` (Uint8List): The private Ed25519 key.
  - `encryptionKey` (Uint8List): The private X25519 key.
  - `publicIdentity` (PublicIdentity): The corresponding public identity.

### `IdentityManager`

The primary entry point for performing cryptographic operations using a given
identity. It is a stateless service configured with the user's keys.

- **Responsibilities**:
  - Providing the user's public identity.
  - Creating `SessionCrypto` instances for communicating with trusted peers.
  - Signing data with the private signing key.

### `PublicIdentity`

A simple, serializable data class representing a user's public identity. This is
what gets shared during pairing.

- **Properties**:
  - `peerId` (String): A unique identifier, derived from a hash of the public
    signing key.
  - `publicSigningKey` (Uint8List): Ed25519 public key for verifying signatures.
  - `publicEncryptionKey` (Uint8List): X25519 public key for ECDH key exchange.

### `TrustStore`

An **in-memory** collection of trusted peer identities. The consuming
application is responsible for persisting and loading this store's state.

- **Responsibilities**:
  - Managing a map of trusted `PublicIdentity` objects.
  - Providing methods to serialize to and from a JSON format for persistence.

### `SessionCrypto`

An ephemeral class that handles encryption and decryption for a specific
peer-to-peer session.

- **Responsibilities**:
  - Deriving a shared secret via ECDH.
  - Encrypting outgoing data and decrypting incoming data for the session.

### `EncryptedPayload`

A serializable data class representing encrypted data ready for transport.

- **Properties**:
  - `senderPeerId` (String): The `peerId` of the sender.
  - `ciphertext` (Uint8List): The encrypted data.
  - `nonce` (Uint8List): The unique nonce used for the encryption.

---

## 4. Public Method Design

### `IdentityKeys`

`static Future<IdentityKeys> generate()`

- **Does**: Creates new Ed25519 and X25519 keypairs.
- **Inputs**: None.
- **Output**: A new `IdentityKeys` object containing the private and public
  keys.
- **When**: On first app launch to create a new user identity. The consumer is
  responsible for securely storing the returned object.

`Map<String, dynamic> toJson()` /
`IdentityKeys.fromJson(Map<String, dynamic> json)`

- **Does**: Serializes/deserializes the keys for storage.
- **Output**: A JSON-compatible map.
- **When**: When saving to or loading from secure storage.

### `IdentityManager`

`IdentityManager.fromKeys(IdentityKeys keys)`

- **Does**: Creates a manager instance for a given identity.
- **Inputs**: The `IdentityKeys` for the user.
- **Output**: A new `IdentityManager` instance.
- **When**: After loading keys from storage.

`PublicIdentity getPublicIdentity()`

- **Does**: Returns the public part of the user's identity.
- **Output**: `PublicIdentity` object.
- **When**: When sharing identity with a peer.

`SessionCrypto createSession(String peerId, TrustStore trustStore)`

- **Does**: Creates a session with a trusted peer by fetching the peer's public
  key from the provided `TrustStore` and performing an ECDH exchange.
- **Inputs**: The `peerId` of the trusted peer and the active `TrustStore`.
- **Output**: A `SessionCrypto` instance.
- **When**: Before starting an encrypted communication session.

`Uint8List signData(Uint8List data)`

- **Does**: Signs data with the user's private signing key.
- **Output**: The signature.

### `TrustStore`

`TrustStore.fromSerialized(String json)` / `String serialize()`

- **Does**: Deserializes/serializes the entire trust store.
- **When**: On app startup to load trusted peers, and after modification to save
  changes.

`void trustPeer(PublicIdentity peerIdentity)`

- **Does**: Adds a peer's `PublicIdentity` to the in-memory store.
- **When**: After securely receiving a peer's public identity. The consumer
  should call `serialize()` and save the result after this.

`bool isPeerTrusted(String peerId)`

- **Does**: Checks if a peer is in the memory-store.
- **Output**: `true` if trusted.

`static bool verifySignature(...)`

- Unchanged. Verifies a signature against a peer's public key.

### `SessionCrypto` & `EncryptedPayload`

The APIs for `SessionCrypto` (`encryptData`, `decryptData`) and
`EncryptedPayload` remain unchanged as they are pure, stateless operations.

---

## 5. Key Storage Strategy

This package **does not perform any storage operations**. The consuming
application is entirely responsible for persisting cryptographic materials and
trust data.

- **`IdentityKeys` (Private Keys)**:
  - The `IdentityKeys` object contains the user's private signing and encryption
    keys. **It is the most sensitive data**.
  - The consumer **MUST** store this object's serialized JSON representation in
    the most secure storage available on the platform.
  - **Recommendation**: Use `flutter_secure_storage` to save the JSON string in
    the OS Keychain/Keystore.
  - The keys should be loaded into memory only when needed to instantiate an
    `IdentityManager`.

- **`TrustStore` Data (Peer Public Keys)**:
  - The `TrustStore` can be serialized to a JSON string. This data contains the
    public keys of trusted peers.
  - This data is not secret, but its integrity is important. Storing it in a
    standard database (like Hive, Isar, or SQLite) or a simple file is
    appropriate.
  - The consumer should load this data on app start to initialize the
    `TrustStore` and save it whenever a new peer is trusted.

- **Session Keys**: Unchanged. Session keys are ephemeral, derived on-demand,
  and held only in memory. They are never stored.

---

## 6. Pairing & Trust Flow

1. **Initiation**: User A wants to connect with User B. They meet in person.
2. **Share**: User A's app loads their `IdentityKeys`, creates an
   `IdentityManager`, and calls `getPublicIdentity()`. It displays this
   `PublicIdentity` as a QR code.
3. **Scan**: User B scans the QR code. The app deserializes the data into a
   `PublicIdentity` object.
4. **Verification**: User B's app displays User A's `peerId` for manual, verbal
   verification.
5. **Trust**: User B's app calls `trustStore.trustPeer(userAPublicIdentity)`.
6. **Persist**: User B's app immediately calls `trustStore.serialize()` and
   saves the resulting string to its local database.
7. **Reciprocate & Persist**: The process is repeated for User A to trust User
   B, and User A's app saves its updated `TrustStore`.

---

## 7. Data Protection Model

The data protection model for data in transit and at rest remains the same, as
the cryptographic operations are unchanged. The key difference is that the
security of data at rest now fully depends on the consuming application's
implementation of `IdentityKeys` storage.

---

## 8. Threat Model (Lightweight)

### Protected Against:

- Eavesdropping, Message Tampering/Forgery, Impersonation (post-pairing).
  (Unchanged)

### Out of Scope / Not Protected Against:

- **Application Storage Vulnerabilities**: **NEW**: If the consuming application
  fails to store the `IdentityKeys` object securely (e.g., saves it in a plain
  text file or insecure `SharedPreferences`), a file system compromise could
  lead to total identity theft. The security of the private keys is now the
  consumer's responsibility.
- Pairing Attacks, Key-Loss, Compromised OS, Application-Level Vulnerabilities.
  (Unchanged)

---

## 9. Minimal Example Usage

```dart
import 'dart:convert';
import 'dart:typed_data';
// Assuming 'package:your_crypto_package/your_crypto_package.dart' is the name
// of the package being designed.
import 'package:your_crypto_package/your_crypto_package.dart';


// --- The consuming app is responsible for storage ---
// This is a mock storage. In a real app, use flutter_secure_storage and a database.
class MockStorage {
  String? identityKeysJson;
  String? trustStoreJson;
}

void main() async {
  final storage = MockStorage();

  // --- Device A (Alice) Setup ---
  IdentityKeys aliceKeys;

  // On first launch, generate and save keys
  if (storage.identityKeysJson == null) {
    print("Alice: No keys found. Generating new identity...");
    aliceKeys = await IdentityKeys.generate();
    storage.identityKeysJson = jsonEncode(aliceKeys.toJson());
    // In a real app: await secureStorage.write('keys', storage.identityKeysJson);
  } else {
    print("Alice: Loading keys from storage...");
    aliceKeys = IdentityKeys.fromJson(jsonDecode(storage.identityKeysJson!));
  }

  // Initialize manager and trust store for Alice
  final aliceIdentityManager = IdentityManager.fromKeys(aliceKeys);
  final aliceTrustStore = storage.trustStoreJson == null
      ? TrustStore()
      : TrustStore.fromSerialized(storage.trustStoreJson!);
  
  // Alice shows her public identity as a QR code
  final alicePublicIdentity = aliceIdentityManager.getPublicIdentity();
  final aliceQrData = jsonEncode(alicePublicIdentity.toJson());


  // --- Device B (Bob) ---
  // (Bob would have the same setup logic, creating his own keys and trust store)
  final bobKeys = await IdentityKeys.generate(); // Bob's new keys
  final bobIdentityManager = IdentityManager.fromKeys(bobKeys);
  final bobTrustStore = TrustStore();

  // Bob scans Alice's QR code
  final receivedAliceIdentity = PublicIdentity.fromJson(jsonDecode(aliceQrData));

  // Bob verifies and trusts Alice
  bobTrustStore.trustPeer(receivedAliceIdentity);
  print('Bob now trusts Alice: ${bobTrustStore.isPeerTrusted(receivedAliceIdentity.peerId)}');

  // Bob's app MUST now persist the updated trust store
  // In a real app, this would be saved to a file or database.
  final bobTrustStoreData = bobTrustStore.serialize();
  print("Bob's app would save this trust store data: $bobTrustStoreData");


  // (Assume reciprocation happens, and Alice trusts Bob and saves her store)


  // --- Later, during a chat session ---

  // Bob wants to send Alice an encrypted message
  final bobSessionWithAlice = bobIdentityManager.createSession(receivedAliceIdentity.peerId, bobTrustStore);
  final message = Uint8List.fromList('Hello Alice!'.codeUnits);
  final encryptedPayload = bobSessionWithAlice.encryptData(message);
  final payloadForTransport = jsonEncode(encryptedPayload.toJson());


  // --- Device A (Alice) ---
  
  // Alice receives the payload
  final receivedPayload = EncryptedPayload.fromJson(jsonDecode(payloadForTransport));

  // Alice decrypts using her identity and trust store
  final aliceSessionWithBob = aliceIdentityManager.createSession(receivedPayload.senderPeerId, aliceTrustStore);
  final decryptedMessageBytes = aliceSessionWithBob.decryptData(receivedPayload);

  if (decryptedMessageBytes != null) {
    final decryptedMessage = String.fromCharCodes(decryptedMessageBytes);
    print('Alice received: $decryptedMessage'); // "Hello Alice!"
  } else {
    print('Decryption failed!');
  }
}
```
