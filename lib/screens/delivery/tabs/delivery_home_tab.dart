import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import '../../../services/driver_service.dart';
import '../../../services/background_service.dart';
import 'delivery_orders_tab.dart';

class DeliveryHomeTab extends StatefulWidget {
  const DeliveryHomeTab({Key? key}) : super(key: key);

  @override
  State<DeliveryHomeTab> createState() => _DeliveryHomeTabState();
}

class _DeliveryHomeTabState extends State<DeliveryHomeTab> {
  static const int _offerSecondsTotal = 25;

  bool _isLoading = true;
  bool _isOnline = false;
  Map<String, dynamic> _dashboardData = {};
  String? _errorMessage;

  List _pendingDeliveries = [];
  bool _isLoadingDeliveries = false;

  Timer? _offerTimer;
  int _secondsLeft = _offerSecondsTotal;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  @override
  void dispose() {
    _offerTimer?.cancel();
    super.dispose();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token') ?? prefs.getString('token');
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception("Token introuvable. Veuillez vous reconnecter.");
      }

      final result = await DriverService.getDashboard(token);

      if (result['success'] == true) {
        final rawData = result['data'];
        setState(() {
          _dashboardData = rawData is Map<String, dynamic> ? rawData : {};
          _isOnline = _dashboardData['is_online'] == true ||
              _dashboardData['driver_status'] == 'online';
          _isLoading = false;
        });
        if (_isOnline) _loadPendingDeliveries();
      } else {
        setState(() {
          _errorMessage = result['message'] ?? "Erreur inconnue du serveur";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleOnlineStatus(bool value) async {
    setState(() => _isOnline = value);

    try {
      final token = await _getToken();
      if (token == null) return;

      final result = await DriverService.toggleOnlineStatus(token);

      if (result['success'] == true) {
        final newStatus = result['is_online'] ?? value;
        setState(() => _isOnline = newStatus);

        final String? driverId = _dashboardData['id']?.toString() ?? _dashboardData['driver_id']?.toString();

        if (newStatus == true) {
          if (driverId != null) {
            final hasLocationPermission = await _ensureLocationPermission();
            if (hasLocationPermission) {
              await BackgroundServiceManager().startTracking(driverId);
              _loadPendingDeliveries();
            } else if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Autorisez la localisation pour recevoir des commandes."),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        } else {
          await BackgroundServiceManager().stopTracking();
          _offerTimer?.cancel();
          setState(() => _pendingDeliveries = []);
        }
      } else if (result['code'] == 'SUBSCRIPTION_REQUIRED' ||
          (result['message'] != null && result['message'].toString().toLowerCase().contains('pass'))) {
        setState(() => _isOnline = !value);
        _showSubscriptionDialog(result['message'] ?? "Votre pass journalier a expiré. Veuillez l'acheter pour vous mettre en ligne.");
      } else {
        setState(() => _isOnline = !value);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? "Erreur"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      setState(() => _isOnline = !value);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erreur de connexion"), backgroundColor: Colors.red),
      );
    }
  }

  Future<bool> _ensureLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Récupère les livraisons en attente (le backend filtre déjà par
  /// vehicle_type : un compte Moto/Vélo ne voit que le service "Livraison").
  Future<void> _loadPendingDeliveries() async {
    setState(() => _isLoadingDeliveries = true);

    try {
      final token = await _getToken();
      if (token == null) {
        setState(() => _isLoadingDeliveries = false);
        return;
      }

      if (!await _ensureLocationPermission()) {
        setState(() => _isLoadingDeliveries = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final result = await DriverService.getPendingRides(
        token,
        latitude: position.latitude,
        longitude: position.longitude,
        radiusKm: 5,
      );

      if (result['success'] == true) {
        final rawData = result['data'];
        setState(() {
          _pendingDeliveries = rawData is List
              ? rawData
              : (rawData is Map && rawData['rides'] is List ? rawData['rides'] : []);
          _isLoadingDeliveries = false;
        });
        _startOfferCountdown();
      } else {
        setState(() => _isLoadingDeliveries = false);
      }
    } catch (e) {
      setState(() => _isLoadingDeliveries = false);
    }
  }

  /// Compte à rebours purement local pour la carte de réception affichée à
  /// l'écran. Le backend n'a pas de notion d'expiration d'offre par
  /// chauffeur : à 0, on passe simplement à la commande suivante côté UI.
  void _startOfferCountdown() {
    _offerTimer?.cancel();
    if (_pendingDeliveries.isEmpty) return;

    setState(() => _secondsLeft = _offerSecondsTotal);
    _offerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        _skipCurrentOffer();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  /// "Refuser" : aucun endpoint backend ne permet de décliner une commande
  /// encore "pending" (non assignée) - on passe juste à la suivante côté UI.
  void _skipCurrentOffer() {
    _offerTimer?.cancel();
    if (_pendingDeliveries.isEmpty) return;

    setState(() {
      _pendingDeliveries = _pendingDeliveries.sublist(1);
    });

    if (_pendingDeliveries.isNotEmpty) {
      _startOfferCountdown();
    } else {
      _loadPendingDeliveries();
    }
  }

  Future<void> _acceptDelivery(dynamic rideId) async {
    _offerTimer?.cancel();

    final token = await _getToken();
    if (token == null || rideId == null) return;

    final result = await DriverService.acceptRide(token, rideId.toString());
    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Livraison acceptée !'), backgroundColor: Colors.green),
      );
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const DeliveryOrdersTab()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? "Impossible d'accepter cette livraison."), backgroundColor: Colors.red),
      );
      // La commande a probablement été prise par un autre livreur entre-temps.
      _loadPendingDeliveries();
    }
  }

  void _showSubscriptionDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Pass journalier requis"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5722)),
            onPressed: () async {
              Navigator.pop(context);
              final token = await _getToken();
              if (token != null) {
                final res = await DriverService.buyDailyPass(token);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message'] ?? "Opération effectuée"),
                    backgroundColor: res['success'] == true ? Colors.green : Colors.red,
                  ),
                );
                if (res['success'] == true) _loadDashboard();
              }
            },
            child: const Text("Acheter le pass (2000 FCFA)", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFF5722)));
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              const Text("Erreur de chargement", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadDashboard,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5722)),
                child: const Text("Réessayer", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    final wallet = _dashboardData['wallet'] is Map ? _dashboardData['wallet'] : {};
    final balance = wallet['balance'] ?? _dashboardData['balance'] ?? "0 F";
    final todayDeliveries = _dashboardData['today_rides_count'] ?? _dashboardData['today_rides'] ?? 0;
    final todayEarnings = _dashboardData['today_earnings'] ?? wallet['earnings'] ?? "0 F";
    final driverName = _dashboardData['driver_name'] ?? _dashboardData['name'] ?? "Livreur";

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      color: const Color(0xFFFF5722),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Entête Profil & Switch
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 22,
                      backgroundColor: Color(0xFFF7F7F9),
                      child: Icon(Icons.two_wheeler, color: Colors.black54),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Bonjour, $driverName 👋",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isOnline ? Colors.green : Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isOnline ? "Livreur - En ligne" : "Livreur - Hors ligne",
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                Switch(
                  value: _isOnline,
                  activeColor: const Color(0xFFFF5722),
                  onChanged: _toggleOnlineStatus,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Carte Solde Dynamique
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF5722), Color(0xFFFF8A65)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Solde disponible", style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 8),
                  Text(
                    balance.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Aujourd'hui", style: TextStyle(color: Colors.white70, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text("$todayDeliveries livraisons", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Gains du jour", style: TextStyle(color: Colors.white70, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(todayEarnings.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text("Réception d'une commande", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            if (!_isOnline)
              Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                child: Text("Passez en ligne pour recevoir des commandes.", style: TextStyle(color: Colors.grey[500])),
              )
            else if (_isLoadingDeliveries)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator(color: Color(0xFFFF5722))),
              )
            else if (_pendingDeliveries.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                child: Text("Aucune livraison disponible pour le moment.", style: TextStyle(color: Colors.grey[500])),
              )
            else
              _buildOrderReceptionCard(_pendingDeliveries.first),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderReceptionCard(dynamic ride) {
    final pickup = ride['pickup_address'] ?? "Point de retrait";
    final dropoff = ride['destination_address'] ?? "Point de livraison";
    final driverDistance = ride['distance_km_from_driver'] ?? ride['distance_km'];
    final distance = driverDistance != null ? "$driverDistance km" : "";
    final price = ride['price'];
    final packageType = ride['package_type'];
    final packageWeight = ride['package_weight_kg'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF5722), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, spreadRadius: 2),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Nouvelle livraison", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5722).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "$_secondsLeft s",
                  style: const TextStyle(color: Color(0xFFFF5722), fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            price != null ? "${price}F" : "",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.green),
          ),
          if (distance.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(distance, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.trip_origin, color: Colors.green, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(pickup.toString(), style: const TextStyle(fontSize: 13))),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(left: 7.0),
            child: SizedBox(height: 10, child: VerticalDivider(color: Colors.grey, thickness: 2)),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, color: Color(0xFFFF5722), size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(dropoff.toString(), style: const TextStyle(fontSize: 13))),
            ],
          ),
          if (packageType != null || packageWeight != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 16, color: Colors.black54),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      [
                        if (packageType != null) packageType.toString(),
                        if (packageWeight != null) "$packageWeight kg",
                      ].join(" • "),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _skipCurrentOffer,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Refuser", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _acceptDelivery(ride['id']),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5722),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Accepter", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
