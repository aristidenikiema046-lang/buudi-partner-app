import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';

class BackgroundServiceManager {
  static final BackgroundServiceManager _instance = BackgroundServiceManager._internal();
  factory BackgroundServiceManager() => _instance;
  BackgroundServiceManager._internal();

  final FlutterBackgroundService _service = FlutterBackgroundService();

  /// Initialise le service d'arrière-plan
  Future<void> initializeService() async {
    await _service.configure(
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'buudi_driver_tracking',
        initialNotificationTitle: 'Buudi Chauffeur',
        initialNotificationContent: 'Le service de localisation est actif en arrière-plan',
        foregroundServiceNotificationId: 888,
      ),
    );
  }

  /// Démarre le tracking en arrière-plan pour un chauffeur spécifique
  Future<void> startTracking(String driverId) async {
    final bool isRunning = await _service.isRunning();
    if (!isRunning) {
      await _service.startService();
    }
    // Envoie l'ID du chauffeur au service en cours d'exécution
    _service.invoke('setDriverId', {'driverId': driverId});
  }

  /// Arrête le tracking
  Future<void> stopTracking() async {
    final bool isRunning = await _service.isRunning();
    if (isRunning) {
      _service.invoke('stopService');
    }
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // S'assure que les bindings et Firebase sont initialisés dans l'isolat d'arrière-plan
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Erreur d'initialisation Firebase en arrière-plan : $e");
  }

  String? driverId;

  // Écoute l'événement pour récupérer l'ID du chauffeur
  service.on('setDriverId').listen((event) {
    if (event != null && event['driverId'] != null) {
      driverId = event['driverId'] as String;
    }
  });

  // Gestion de la notification persistante pour Android
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Boucle de récupération de la position toutes les 5 secondes
  Timer.periodic(const Duration(seconds: 5), (timer) async {
    if (driverId == null) return; // On attend d'avoir le vrai ID du chauffeur

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Mise à jour de la Realtime Database de Firebase
      final DatabaseReference dbRef = FirebaseDatabase.instance.ref();
      await dbRef.child('drivers_location/$driverId').set({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'heading': position.heading,
        'updated_at': ServerValue.timestamp,
      });

      // Met à jour le texte de la notification Android (optionnel)
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "Buudi - En ligne",
          content: "Position actualisée (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})",
        );
      }
    } catch (e) {
      debugPrint("Erreur lors de la récupération GPS en arrière-plan : $e");
    }
  });
}