import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:buudi_shared/buudi_shared.dart';

class DriverService {
  static String get baseUrl => ApiConfig.baseUrlV1;

  /// Récupérer le profil complet du chauffeur
  static Future<Map<String, dynamic>> getDriverProfile(String jwtToken) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/driver/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Erreur lors du chargement du profil.'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Impossible de contacter le serveur.'};
    }
  }

  static Future<Map<String, dynamic>> getDashboard(String jwtToken) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/driver/dashboard'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Erreur lors du chargement des données.'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Impossible de contacter le serveur.'};
    }
  }

  /// Récupérer la course active en cours
  static Future<Map<String, dynamic>> getActiveRide(String jwtToken) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/driver/active-ride'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Aucune course.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur de connexion au serveur.'};
    }
  }

  /// Récupérer les courses en attente à proximité d'une position
  static Future<Map<String, dynamic>> getPendingRides(
    String jwtToken, {
    required double latitude,
    required double longitude,
    double radiusKm = 5,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/driver/rides/pending').replace(
        queryParameters: {
          'lat': latitude.toString(),
          'lng': longitude.toString(),
          'radius_km': radiusKm.toString(),
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Erreur lors du chargement des courses disponibles.'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Impossible de contacter le serveur.'};
    }
  }

  static Future<Map<String, dynamic>> toggleOnlineStatus(String jwtToken) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/toggle-status'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'is_online': data['data']['is_online'],
          'message': data['message'] ?? 'Statut mis à jour.'
        };
      } else if (response.statusCode == 402) {
        return {
          'success': false,
          'code': 'SUBSCRIPTION_REQUIRED',
          'message': data['message'] ?? 'Abonnement requis.'
        };
      } else {
        return {
          'success': false,
          'code': 'ERROR',
          'message': data['message'] ?? 'Une erreur est survenue.'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Impossible de contacter le serveur.'};
    }
  }

  static Future<Map<String, dynamic>> buyDailyPass(String jwtToken) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/buy-pass'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Pass acheté avec succès !'
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Échec de l\'achat du pass.'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur de connexion.'};
    }
  }

  static Future<Map<String, dynamic>> acceptRide(String jwtToken, String rideId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/rides/$rideId/accept'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message'] ?? 'Course acceptée !',
          'ride': data['ride'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Impossible d\'accepter cette course.'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur de connexion.'};
    }
  }

  /// 1. Signaler l'arrivée au point de prise en charge
  static Future<Map<String, dynamic>> arriveAtPickup(String jwtToken, String rideId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/rides/$rideId/arrive'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
      );
      final data = jsonDecode(response.body);
      return {'success': response.statusCode == 200, 'message': data['message']};
    } catch (e) {
      return {'success': false, 'message': 'Erreur de connexion.'};
    }
  }

  /// 2. Démarrer la course
  static Future<Map<String, dynamic>> startRide(String jwtToken, String rideId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/rides/$rideId/start'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
      );
      final data = jsonDecode(response.body);
      return {'success': response.statusCode == 200, 'message': data['message']};
    } catch (e) {
      return {'success': false, 'message': 'Erreur de connexion.'};
    }
  }

  /// 3. Terminer la course
  static Future<Map<String, dynamic>> completeRide(String jwtToken, String rideId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/rides/$rideId/complete'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
      );
      final data = jsonDecode(response.body);
      return {'success': response.statusCode == 200, 'message': data['message']};
    } catch (e) {
      return {'success': false, 'message': 'Erreur de connexion.'};
    }
  }

  /// 4. Annuler la course (repasse "pending" pour un autre chauffeur, sauf
  /// si elle était déjà "in_progress" : dans ce cas elle passe "cancelled").
  static Future<Map<String, dynamic>> cancelRide(String jwtToken, String rideId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/rides/$rideId/cancel'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
      );
      final data = jsonDecode(response.body);
      return {'success': response.statusCode == 200, 'message': data['message']};
    } catch (e) {
      return {'success': false, 'message': 'Erreur de connexion.'};
    }
  }
}