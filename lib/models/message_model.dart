class Message {
  final String id;
  final String rideId;
  final String senderId;
  final String senderRole; // 'client' | 'driver'
  final String content;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.rideId,
    required this.senderId,
    required this.senderRole,
    required this.content,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id']?.toString() ?? '',
        rideId: json['ride_id']?.toString() ?? '',
        senderId: json['sender_id']?.toString() ?? '',
        senderRole: json['sender_role']?.toString() ?? '',
        content: json['content']?.toString() ?? '',
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      );
}
