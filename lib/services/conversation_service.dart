import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:buudi_shared/buudi_shared.dart';
import '../models/conversation_model.dart';
import '../utils/api_error.dart';

class ConversationService {
  String get baseUrl => ApiConfig.baseUrlV1;

  /// GET /v1/conversations — liste des rides avec messages, triée par
  /// dernier message desc (tri déjà fait côté API).
  Future<Map<String, dynamic>> fetchConversations(String jwtToken) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/conversations'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final rawList = data['data'] is List ? data['data'] as List : [];
        final conversations = rawList
            .whereType<Map>()
            .map((e) => Conversation.fromJson(e.cast<String, dynamic>()))
            .toList();
        return {'success': true, 'data': conversations};
      } else {
        return {
          'success': false,
          'message': apiErrorMessage(data, 'Impossible de charger les conversations.'),
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Impossible de contacter le serveur.'};
    }
  }

  /// POST /v1/rides/{rideId}/messages/mark-read
  Future<Map<String, dynamic>> markConversationRead(String rideId, String jwtToken) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rides/$rideId/messages/mark-read'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true};
      } else {
        return {
          'success': false,
          'message': apiErrorMessage(data, 'Impossible de marquer la conversation comme lue.'),
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Impossible de contacter le serveur.'};
    }
  }
}
