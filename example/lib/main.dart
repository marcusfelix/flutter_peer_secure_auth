import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_peer_secure_auth/flutter_peer_secure_auth.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Peer Secure Auth Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Peer Secure Auth Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  IdentityKeys? _myKeys;
  final TrustStore _trustStore = TrustStore();
  IdentityManager? _identityManager;

  final TextEditingController _trustPeerController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _encryptedPayloadController =
      TextEditingController();

  String? _lastEncryptedPayload;
  String? _decryptedMessage;
  PublicIdentity? _selectedPeer;

  @override
  void initState() {
    super.initState();
    _generateIdentity();
  }

  Future<void> _generateIdentity() async {
    final keys = await IdentityKeys.generate();
    setState(() {
      _myKeys = keys;
      _identityManager = IdentityManager.fromKeys(keys);
    });
  }

  Future<void> _copyIdentity() async {
    if (_myKeys == null) return;
    final json = await _myKeys!.publicIdentity.toJson();
    final jsonString = jsonEncode(json);
    await Clipboard.setData(ClipboardData(text: jsonString));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Identity copied to clipboard')),
      );
    }
  }

  Future<void> _trustPeer() async {
    final jsonString = _trustPeerController.text.trim();
    if (jsonString.isEmpty) return;

    try {
      final json = jsonDecode(jsonString);
      final peerIdentity = await PublicIdentity.fromJson(json);
      _trustStore.trustPeer(peerIdentity);
      setState(() {
        _selectedPeer = peerIdentity;
        _trustPeerController.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Trusted peer: ${peerIdentity.peerId}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error trusting peer: $e')));
      }
    }
  }

  Future<void> _encryptMessage() async {
    if (_identityManager == null ||
        _selectedPeer == null ||
        _messageController.text.isEmpty) {
      return;
    }

    try {
      final session = _identityManager!.createSession(
        _selectedPeer!.peerId,
        _trustStore,
      );
      final messageBytes = utf8.encode(_messageController.text);
      final payload = await session.encryptData(
        Uint8List.fromList(messageBytes),
      );

      final json = payload.toJson();
      final jsonString = jsonEncode(json);

      setState(() {
        _lastEncryptedPayload = jsonString;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Encryption error: $e')));
      }
    }
  }

  Future<void> _copyEncryptedPayload() async {
    final payload = _lastEncryptedPayload;
    if (payload == null) return;
    await Clipboard.setData(ClipboardData(text: payload));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Encrypted payload copied to clipboard')),
      );
    }
  }

  Future<void> _decryptPayload() async {
    if (_identityManager == null) return;
    final jsonString = _encryptedPayloadController.text.trim();
    if (jsonString.isEmpty) return;

    try {
      final json = jsonDecode(jsonString);
      final payload = EncryptedPayload.fromJson(json);

      // We need to know who sent it to create the session to decrypt.
      // EncryptedPayload has senderPeerId.
      final senderId = payload.senderPeerId;

      final session = _identityManager!.createSession(senderId, _trustStore);
      final decryptedBytes = await session.decryptData(payload);

      if (decryptedBytes != null) {
        setState(() {
          _decryptedMessage = utf8.decode(decryptedBytes);
        });
      } else {
        setState(() {
          _decryptedMessage = 'Decryption failed (null result)';
        });
      }
    } catch (e) {
      setState(() {
        _decryptedMessage = 'Error decrypting: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final trustedPeers = _trustStore.getAllTrustedPeers();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Identity Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Identity',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    if (_myKeys != null) ...[
                      SelectableText(
                        'Peer ID: ${_myKeys!.publicIdentity.peerId}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _copyIdentity,
                            icon: const Icon(Icons.copy),
                            label: const Text('Copy Identity JSON'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _generateIdentity,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Regenerate'),
                          ),
                        ],
                      ),
                    ] else
                      const CircularProgressIndicator(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Trust Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trust Peers',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _trustPeerController,
                      decoration: const InputDecoration(
                        labelText: 'Paste Peer Identity JSON',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _trustPeer,
                      child: const Text('Trust Peer'),
                    ),
                    const SizedBox(height: 16),
                    const Text('Trusted Peers:'),
                    if (trustedPeers.isEmpty)
                      const Text('No trusted peers yet.')
                    else
                      ...trustedPeers.map(
                        (p) => ListTile(
                          title: Text(p.peerId),
                          leading: const Icon(Icons.person),
                          onTap: () {
                            setState(() {
                              _selectedPeer = p;
                            });
                          },
                          tileColor: _selectedPeer?.peerId == p.peerId
                              ? Theme.of(context).colorScheme.primaryContainer
                              : null,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Messaging Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Messaging',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    if (_selectedPeer == null)
                      const Text(
                        'Select a trusted peer from the list above to verify.',
                        style: TextStyle(fontStyle: FontStyle.italic),
                      )
                    else ...[
                      Text('Sending to: ${_selectedPeer!.peerId}'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          labelText: 'Message',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _encryptMessage,
                        child: const Text('Encrypt Message'),
                      ),
                      if (_lastEncryptedPayload != null) ...[
                        const SizedBox(height: 16),
                        const Text('Encrypted Payload (JSON):'),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: SelectableText(_lastEncryptedPayload!),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _copyEncryptedPayload,
                          icon: const Icon(Icons.copy),
                          label: const Text('Copy Payload'),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Decrypt Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Decryption Simulation',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _encryptedPayloadController,
                      decoration: const InputDecoration(
                        labelText: 'Paste Encrypted Payload JSON',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _decryptPayload,
                      child: const Text('Decrypt'),
                    ),
                    const SizedBox(height: 16),
                    if (_decryptedMessage != null) ...[
                      Text(
                        'Decrypted Message:',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _decryptedMessage!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
