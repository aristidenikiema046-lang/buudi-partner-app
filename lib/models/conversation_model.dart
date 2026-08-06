class ConversationParticipant {
  final String id;
  final String name;
  final String role;

  ConversationParticipant({required this.id, required this.name, required this.role});

  factory ConversationParticipant.fromJson(Map<String, dynamic> json) => ConversationParticipant(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        role: json['role']?.toString() ?? '',
      );
}

class ConversationLastMessage {
  final String content;
  final String senderRole;
  final DateTime createdAt;

  ConversationLastMessage({required this.content, required this.senderRole, required this.createdAt});

  factory ConversationLastMessage.fromJson(Map<String, dynamic> json) => ConversationLastMessage(
        content: json['content']?.toString() ?? '',
        senderRole: json['sender_role']?.toString() ?? '',
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      );
}

class Conversation {
  final String rideId;
  final String serviceType;
  final String rideStatus;
  final ConversationParticipant? otherParticipant;
  final ConversationLastMessage? lastMessage;
  final int unreadCount;

  Conversation({
    required this.rideId,
    required this.serviceType,
    required this.rideStatus,
    this.otherParticipant,
    this.lastMessage,
    this.unreadCount = 0,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        rideId: json['ride_id']?.toString() ?? '',
        serviceType: json['service_type']?.toString() ?? '',
        rideStatus: json['ride_status']?.toString() ?? '',
        otherParticipant: json['other_participant'] is Map
            ? ConversationParticipant.fromJson((json['other_participant'] as Map).cast<String, dynamic>())
            : null,
        lastMessage: json['last_message'] is Map
            ? ConversationLastMessage.fromJson((json['last_message'] as Map).cast<String, dynamic>())
            : null,
        unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      );
}
