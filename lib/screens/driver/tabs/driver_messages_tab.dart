import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/conversation_model.dart';
import '../../../services/conversation_service.dart';
import '../../common/chat_screen.dart';

class DriverMessagesTab extends StatefulWidget {
  const DriverMessagesTab({Key? key}) : super(key: key);

  @override
  State<DriverMessagesTab> createState() => _DriverMessagesTabState();
}

class _DriverMessagesTabState extends State<DriverMessagesTab> {
  static const _orange = Color(0xFFFF5722);

  final ConversationService _conversationService = ConversationService();

  bool _loading = true;
  String? _error;
  List<Conversation> _conversations = [];
  String _token = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('jwt_token') ?? prefs.getString('token') ?? '';
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _conversationService.fetchConversations(_token);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['success'] == true) {
        _conversations = result['data'] as List<Conversation>;
      } else {
        _error = result['message'] as String?;
      }
    });
  }

  Future<void> _openConversation(Conversation conversation) async {
    _conversationService.markConversationRead(conversation.rideId, _token);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatScreen(rideId: conversation.rideId)),
    );
    _load();
  }

  String _formatShortDate(DateTime date) {
    const mois = [
      'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
      'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc',
    ];
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    return '${date.day} ${mois[date.month - 1]} • $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Messages & Support",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _orange));
    }
    if (_error != null) {
      return RefreshIndicator(
        color: _orange,
        onRefresh: _load,
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 100),
              child: Center(child: Text(_error!, style: TextStyle(color: Colors.grey[600]))),
            ),
          ],
        ),
      );
    }
    if (_conversations.isEmpty) {
      return RefreshIndicator(
        color: _orange,
        onRefresh: _load,
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 100),
              child: Center(child: Text("Aucune conversation pour l'instant.", style: TextStyle(color: Colors.grey[600]))),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: _orange,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _conversations.length,
        itemBuilder: (context, index) => _buildTile(_conversations[index]),
      ),
    );
  }

  Widget _buildTile(Conversation conversation) {
    final name = conversation.otherParticipant?.name ?? "Client";
    final isUnread = conversation.unreadCount > 0;

    return InkWell(
      onTap: () => _openConversation(conversation),
      child: Container(
        color: isUnread ? const Color(0xFFFFF0EE) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFFF1F3F5),
              child: conversation.otherParticipant != null
                  ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.bold))
                  : const Icon(Icons.person_outline_rounded, color: Colors.black45, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: isUnread ? FontWeight.bold : FontWeight.w600, fontSize: 14, color: Colors.black87),
                        ),
                      ),
                      if (conversation.lastMessage != null)
                        Text(
                          _formatShortDate(conversation.lastMessage!.createdAt),
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(color: const Color(0xFFF1F3F5), borderRadius: BorderRadius.circular(6)),
                    child: Text(conversation.serviceType, style: TextStyle(fontSize: 10, color: Colors.grey[700], fontWeight: FontWeight.w600)),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.lastMessage?.content ?? "Aucun message",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: isUnread ? Colors.black87 : Colors.grey[600], fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal),
                        ),
                      ),
                      if (isUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                          decoration: const BoxDecoration(color: _orange, shape: BoxShape.circle),
                          child: Text(
                            conversation.unreadCount > 9 ? '9+' : '${conversation.unreadCount}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
