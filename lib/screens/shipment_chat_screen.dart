import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../utils/backend_auth_service.dart';
import '../utils/backend_config.dart';

class ShipmentChatScreen extends StatefulWidget {
  final String threadId;
  final String peerId;
  final String peerLabel;

  const ShipmentChatScreen({
    super.key,
    required this.threadId,
    required this.peerId,
    required this.peerLabel,
  });

  @override
  State<ShipmentChatScreen> createState() => _ShipmentChatScreenState();
}

class _ChatMessage {
  final String id;
  final String senderId;
  final String? receiverId;
  final String text;
  final DateTime createdAt;

  _ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.createdAt,
  });

  factory _ChatMessage.fromMap(Map<String, dynamic> map) {
    final createdRaw = map['createdAt']?.toString();
    final createdAt = createdRaw == null
        ? DateTime.now()
        : DateTime.tryParse(createdRaw) ?? DateTime.now();

    return _ChatMessage(
      id: (map['id'] ?? '').toString(),
      senderId: (map['senderId'] ?? '').toString(),
      receiverId: map['receiverId']?.toString(),
      text: (map['text'] ?? '').toString(),
      createdAt: createdAt,
    );
  }
}

class _ShipmentChatScreenState extends State<ShipmentChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final BackendAuthService _authService = BackendAuthService();

  bool _sending = false;
  bool _loading = true;
  String? _error;
  String? _currentUserId;
  List<_ChatMessage> _messages = const [];
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final userId = await _authService.getCurrentUserId();
    if (!mounted) return;

    if (userId == null || userId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'You are not signed in.';
      });
      return;
    }

    setState(() {
      _currentUserId = userId;
    });

    await _loadMessages(showLoader: true);

    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _loadMessages(showLoader: false);
    });
  }

  Future<Map<String, dynamic>> _authedRequest({
    required String path,
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not signed in');
    }

    final uri = Uri.parse('${BackendConfig.baseUrl}$path');
    final client = HttpClient();
    try {
      final req = await client.openUrl(method, uri);
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');

      if (body != null) {
        req.add(utf8.encode(jsonEncode(body)));
      }

      final res = await req.close();
      final raw = await utf8.decoder.bind(res).join();
      final data = raw.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(raw) as Map<String, dynamic>;

      if (res.statusCode < 200 || res.statusCode >= 300 || data['ok'] == false) {
        throw Exception((data['error'] ?? 'Request failed').toString());
      }

      return data;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _loadMessages({required bool showLoader}) async {
    if (showLoader && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final data = await _authedRequest(path: '/api/threads/${widget.threadId}/chat');
      final dynamic messagesRaw = data['messages'];
      final parsed = (messagesRaw is List ? messagesRaw : const [])
          .whereType<Map<String, dynamic>>()
          .map(_ChatMessage.fromMap)
          .toList();

      if (!mounted) return;
      setState(() {
        _messages = parsed;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_sending) return;
    final text = _messageController.text.trim();
    if ((_currentUserId == null || _currentUserId!.isEmpty) || text.isEmpty) {
      return;
    }

    setState(() => _sending = true);
    try {
      await _authedRequest(
        path: '/api/threads/${widget.threadId}/chat',
        method: 'POST',
        body: {
          'receiverId': widget.peerId,
          'text': text,
        },
      );

      _messageController.clear();
      await _loadMessages(showLoader: false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: Text('Chat • ${widget.peerLabel}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _messages.isEmpty
                        ? const Center(
                            child: Text('No messages yet. Start the conversation.'),
                          )
                        : ListView.builder(
                            reverse: true,
                            padding: const EdgeInsets.all(12),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final message = _messages[index];
                              final isMine = message.senderId == _currentUserId;

                              return Align(
                                alignment: isMine
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  constraints: const BoxConstraints(maxWidth: 280),
                                  decoration: BoxDecoration(
                                    color: isMine
                                        ? Colors.blue.shade600
                                        : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    message.text,
                                    style: TextStyle(
                                        color: isMine
                                            ? Colors.white
                                            : Colors.black87),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Type message...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _sending ? null : _sendMessage,
                    child: _sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Send'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
