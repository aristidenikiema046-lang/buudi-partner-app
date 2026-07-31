import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/driver_service.dart';
import '../../../services/background_service.dart';

class DriverHomeTab extends StatefulWidget {
  const DriverHomeTab({Key? key}) : super(key: key);

  @override
  State<DriverHomeTab> createState() => _DriverHomeTabState();
}

class _DriverHomeTabState extends State<DriverHomeTab> {
  bool _isLoading = true;
  bool _isOnline = false;
  Map<String, dynamic> _dashboardData = {};
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
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
      print("📊 DONNÉES REÇUES DU BACKEND : $result");

      if (result['success'] == true) {
        final rawData = result['data'];
        setState(() {
          _dashboardData = rawData is Map<String, dynamic> ? rawData : {};
          // Lecture sécurisée du statut en ligne
          _isOnline = _dashboardData['is_online'] == true || 
                      _dashboardData['driver_status'] == 'online';
          _isLoading = false;
        });
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
        setState(() {
          _isOnline = newStatus;
        });

        // 🚀 GESTION DU TRACKING GPS SELON LE STATUT
        final String? driverId = _dashboardData['id']?.toString() ?? _dashboardData['driver_id']?.toString();

        if (newStatus == true) {
          if (driverId != null) {
            await BackgroundServiceManager().startTracking(driverId);
          } else {
            print("⚠️ Impossible de démarrer le tracking : ID du chauffeur introuvable.");
          }
        } else {
          await BackgroundServiceManager().stopTracking();
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

    // Extraction dynamique sécurisée avec des valeurs par défaut si les clés changent
    final wallet = _dashboardData['wallet'] is Map ? _dashboardData['wallet'] : {};
    final balance = wallet['balance'] ?? _dashboardData['balance'] ?? "0 F";
    final todayRides = _dashboardData['today_rides_count'] ?? _dashboardData['today_rides'] ?? _dashboardData['rides_count'] ?? 0;
    final todayEarnings = _dashboardData['today_earnings'] ?? wallet['earnings'] ?? "0 F";
    final driverName = _dashboardData['driver_name'] ?? _dashboardData['name'] ?? "Chauffeur";
    final nearbyRides = _dashboardData['available_rides'] is List 
        ? _dashboardData['available_rides'] 
        : (_dashboardData['nearby_rides'] is List ? _dashboardData['nearby_rides'] : []);

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
                      child: Icon(Icons.person, color: Colors.black54),
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
                              _isOnline ? "Chauffeur - En ligne" : "Chauffeur - Hors ligne",
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
                          Text("$todayRides courses", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

            // Liste des courses à proximité dynamiques
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Courses à proximité", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: _loadDashboard,
                  child: const Text("Actualiser", style: TextStyle(color: Color(0xFFFF5722))),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (nearbyRides.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                child: Text("Aucune course disponible pour le moment.", style: TextStyle(color: Colors.grey[500])),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: nearbyRides.length,
                itemBuilder: (context, index) {
                  final ride = nearbyRides[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F7F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: Color(0xFFFF5722)),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(ride['pickup_location'] ?? "Départ", style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(ride['distance'] ?? "", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                        Text(
                          ride['price']?.toString() ?? "",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}