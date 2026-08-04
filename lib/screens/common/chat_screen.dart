import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/message_model.dart';
import '../../services/chat_service.dart';

/// Messagerie liée à une course (ride_id) entre le client et son
/// chauffeur/livreur. Historique via REST (GET/POST /v1/rides/{id}/messages),
/// Firebase RTDB (messages_meta/{ride_id}/last_message_at) utilisé
/// uniquement comme signal temps réel pour déclencher un refetch — pas de
/// contenu de message stocké côté Firebase.
class ChatScreen extends StatefulWidget {
  final String rideId;

  const ChatScreen({Key? key, required this.rideId}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const _orange = Color(0xFFFF5722);

  final ChatService _chatService = ChatService();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Message> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  String _token = '';

  StreamSubscription<DateTime>? _updatesSub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('jwt_token') ?? prefs.getString('token') ?? '';

    await _loadMessages();

    _updatesSub = _chatService.listenForUpdates(widget.rideId).listen((_) {
      _loadMessages(showLoader: false);
    });
  }

  Future<void> _loadMessages({bool showLoader = true}) async {
    if (showLoader) setState(() => _loading = true);
    final result = await _chatService.fetchMessages(widget.rideId, _token);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['success'] == true) {
        _messages = result['data'] as List<Message>;
        _error = null;
      } else {
        _error = result['message'] as String?;
      }
    });
    _scrollToBottom();
  }

  Future<void> _send() async {
    final content = _inputController.text.trim();
    if (content.isEmpty || _sending) return;

    setState(() => _sending = true);
    final result = await _chatService.sendMessage(widget.rideId, content, _token);
    if (!mounted) return;
    setState(() => _sending = false);

    if (result['success'] == true) {
      _inputController.clear();
      await _loadMessages(showLoader: false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? "Impossible d'envoyer le message.")),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _updatesSub?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text("Messages", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildBody()),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _orange));
    }
    if (_error != null && _messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
        ),
      );
    }
    if (_messages.isEmpty) {
      return Center(
        child: Text("Aucun message pour l'instant.", style: TextStyle(color: Colors.grey[600])),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) => _buildBubble(_messages[index]),
    );
  }

  Widget _buildBubble(Message message) {
    // Cette app ne sert que des comptes role="driver" (Chauffeur ou Livreur) :
    // "driver" est donc toujours "moi", pas besoin de comparer à AuthBloc.
    final isMine = message.senderRole == 'driver';
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? _orange : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMine ? 14 : 2),
            bottomRight: Radius.circular(isMine ? 2 : 14),
          ),
        ),
        child: Text(
          message.content,
          style: TextStyle(color: isMine ? Colors.white : Colors.black87, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, -4))],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: "Écrire un message...",
                filled: true,
                fillColor: const Color(0xFFF7F7F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(color: _orange, shape: BoxShape.circle),
            child: IconButton(
              icon: _sending
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.white),
              onPressed: _sending ? null : _send,
            ),
          ),
        ],
      ),
    );
  }
}
