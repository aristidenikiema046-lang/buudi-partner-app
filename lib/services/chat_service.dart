import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_database/firebase_database.dart';
import 'package:buudi_shared/buudi_shared.dart';
import '../models/message_model.dart';

class ChatService {
  String get baseUrl => ApiConfig.baseUrlV1;

  /// GET /v1/rides/{rideId}/messages — historique trié par created_at asc.
  Future<Map<String, dynamic>> fetchMessages(String rideId, String jwtToken) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/rides/$rideId/messages'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final rawList = data['data'] is List ? data['data'] as List : [];
        final messages = rawList
            .whereType<Map>()
            .map((e) => Message.fromJson(e.cast<String, dynamic>()))
            .toList();
        return {'success': true, 'data': messages};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Impossible de charger les messages.'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Impossible de contacter le serveur.'};
    }
  }

  /// POST /v1/rides/{rideId}/messages — le backend déduit sender_id/sender_role
  /// du JWT et met à jour messages_meta/{rideId}/last_message_at côté RTDB.
  Future<Map<String, dynamic>> sendMessage(String rideId, String content, String jwtToken) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rides/$rideId/messages'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({'content': content}),
      );

      final data = jsonDecode(response.body);

      if ((response.statusCode == 200 || response.statusCode == 201) && data['success'] == true) {
        return {'success': true, 'message': data['message'] ?? 'Message envoyé.'};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? "Impossible d'envoyer le message."
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Impossible de contacter le serveur.'};
    }
  }

  /// Écoute messages_meta/{rideId}/last_message_at sur Firebase Realtime DB,
  /// accès direct sans wrapper (même pattern que GpsTrackerService) : émet un
  /// événement à chaque nouveau message, utilisé comme simple signal pour
  /// déclencher un refetch REST.
  Stream<DateTime> listenForUpdates(String rideId) {
    return FirebaseDatabase.instance.ref('messages_meta/$rideId/last_message_at').onValue.map((event) {
      final value = event.snapshot.value;
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      return DateTime.now();
    });
  }
}
