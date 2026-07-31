import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';

class GpsTrackerService {
  Timer? _timer;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  void startTracking(String driverId) {
    // Envoie la position toutes les 5 secondes
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      bool serviceEnabled;
      LocationPermission permission;

      // Vérifications des permissions GPS
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      
      if (permission == LocationPermission.deniedForever) return;

      // Récupération de la position actuelle
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Mise à jour directe dans Firebase Realtime Database
      await _dbRef.child('drivers_location/$driverId').set({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'heading': position.heading,
        'updated_at': ServerValue.timestamp,
      });
    });
  }

  void stopTracking() {
    _timer?.cancel();
  }
}