# Flutter Peer Secure Auth

A pure Dart package for cryptographic identity and end-to-end encryption (E2EE)
in peer-to-peer (P2P) applications.

This package provides high-level abstractions for managing cryptographic
identities, establishing trust between peers, and securely exchanging messages.
It uses `Ed25519` for signing/identity and `X25519` + `ChaCha20-Poly1305` for
encryption.

## Features

- **Identity Management**: Generate and manage cryptographic keys
  (Ed25519/X25519).
- **Peer Trust**: Manage a local store of trusted peer identities.
- **End-to-End Encryption**: Encrypt and decrypt messages for trusted peers.
- **Secure Sessions**: Derive shared secrets using ECDH (X25519) for secure
  communication sessions.
- **Platform Agnostic**: Pure Dart implementation, works on iOS, Android, Web,
  Windows, macOS, and Linux.

## Getting Started

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_peer_secure_auth: ^0.0.1
```

Or run:

```bash
flutter pub add flutter_peer_secure_auth
```

## Usage

### 1. Identify Yourself

Generate a new identity (private/public key pairs):

```dart
import 'package:flutter_peer_secure_auth/flutter_peer_secure_auth.dart';

// Generate new keys
final myKeys = await IdentityKeys.generate();

// Get your public identity (safe to share)
final myPublicIdentity = myKeys.publicIdentity;
print('My Peer ID: ${myPublicIdentity.peerId}');

// Serialize to JSON for storage or sharing
final json = await myKeys.toJson();
final publicJson = await myPublicIdentity.toJson();
```

### 2. Trust a Peer

To communicate with another peer, you must first trust their public identity. In
a real app, you would exchange these public identities via a signaling server,
QR code, or other out-of-band method.

```dart
final trustStore = TrustStore();

// Receive peer's public identity JSON
final peerJson = ...; // JSON object from peer
final peerIdentity = await PublicIdentity.fromJson(peerJson);

// Trust the peer
trustStore.trustPeer(peerIdentity);
```

### 3. Encrypt a Message

Create a session and encrypt data for a trusted peer:

```dart
final identityManager = IdentityManager.fromKeys(myKeys);

// Create a session for the target peer
final session = identityManager.createSession(
  peerIdentity.peerId,
  trustStore,
);

final message = 'Hello, Secure World!';
final data = utf8.encode(message);

// Encrypt
final encryptedPayload = await session.encryptData(Uint8List.fromList(data));

// Serialize payload to send over the network
final payloadJson = encryptedPayload.toJson();
```

### 4. Decrypt a Message

On the receiving end:

```dart
// Receive payload JSON
final receivedJson = ...;
final payload = EncryptedPayload.fromJson(receivedJson);

// Identify sender from payload
final senderId = payload.senderPeerId;

// Create session (needs sender's trusted identity in store)
final session = identityManager.createSession(senderId, trustStore);

// Decrypt
final decryptedBytes = await session.decryptData(payload);

if (decryptedBytes != null) {
  print('Decrypted: ${utf8.decode(decryptedBytes)}');
} else {
  print('Decryption failed (Untrusted peer or tampered data)');
}
```

## Example App

Check the `example/` folder for a complete Flutter application demonstrating:

- Identity Generation
- Copy/Paste Identity Exchange
- Trust Management
- Message Encryption & Decryption Simulation

To run the example:

```bash
cd example
flutter run
```
