import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/driver_service.dart';

class DriverRidesTab extends StatefulWidget {
  const DriverRidesTab({Key? key}) : super(key: key);

  @override
  State<DriverRidesTab> createState() => _DriverRidesTabState();
}

class _DriverRidesTabState extends State<DriverRidesTab> {
  bool _isLoading = true;
  Map<String, dynamic>? _activeRide;

  @override
  void initState() {
    super.initState();
    _loadActiveRide();
  }

  Future<void> _loadActiveRide() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? prefs.getString('token');

      if (token != null) {
        final result = await DriverService.getActiveRide(token);
        if (result['success'] == true) {
          setState(() {
            _activeRide = result['data'];
          });
        }
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _handleRideAction(String actionType, int rideId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? prefs.getString('token');

    if (token == null) return;

    setState(() => _isLoading = true);

    Map<String, dynamic> result = {'success': false};

    if (actionType == 'arrive') {
      result = await DriverService.arriveAtPickup(token, rideId);
    } else if (actionType == 'start') {
      result = await DriverService.startRide(token, rideId);
    } else if (actionType == 'complete') {
      result = await DriverService.completeRide(token, rideId);
    }

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Action réussie !'), backgroundColor: Colors.green),
      );
      _loadActiveRide();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Une erreur est survenue.'), backgroundColor: Colors.red),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFFF5722);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            "Mes Courses",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          bottom: const TabBar(
            labelColor: primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: primaryColor,
            tabs: [
              Tab(text: "En cours / Attente"),
              Tab(text: "Historique"),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: primaryColor))
            : TabBarView(
                children: [
                  _activeRide == null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.directions_car_outlined, size: 60, color: Colors.grey),
                              SizedBox(height: 12),
                              Text("Aucune course en cours active.",
                                  style: TextStyle(color: Colors.grey, fontSize: 14)),
                            ],
                          ),
                        )
                      : Stack(
                          children: [
                            // 1. Simulaion de la carte en arrière-plan (remplaçable par ton widget de carte Google/Flutter Map)
                            Positioned.fill(
                              child: Container(
                                color: Colors.grey[200],
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.map_outlined, size: 80, color: Colors.grey[400]),
                                      const SizedBox(height: 8),
                                      Text(
                                        "Carte interactive de la course\n(${_activeRide!['distance'] ?? '7,2 km'})",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // 2. Panneau supérieur : Infos Client & Trajet
                            SafeArea(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    // Carte du Client (Style sombre élégant)
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.black87,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: primaryColor,
                                            child: Text(
                                              (_activeRide!['client']?['name'] ?? 'C')[0].toUpperCase(),
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _activeRide!['client']?['name'] ?? 'Koffi Jean',
                                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    const Icon(Icons.star, color: Colors.amber, size: 14),
                                                    const SizedBox(width: 4),
                                                    const Text("4.8", style: TextStyle(color: Colors.white70, fontSize: 12)),
                                                    const SizedBox(width: 12),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: Colors.grey[800],
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: const Text("15 courses", style: TextStyle(color: Colors.white70, fontSize: 10)),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Bouton d'appel
                                          Container(
                                            decoration: BoxDecoration(
                                              color: primaryColor,
                                              shape: BoxShape.circle,
                                            ),
                                            child: IconButton(
                                              icon: const Icon(Icons.phone, color: Colors.white, size: 20),
                                              onPressed: () {
                                                // Action d'appel client
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    // Détails Prise en charge & Destination
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.05),
                                            blurRadius: 10,
                                            spreadRadius: 2,
                                          )
                                        ],
                                      ),
                                      child: Column(
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.trip_origin, color: Colors.green, size: 16),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    const Text("Prise en charge", style: TextStyle(color: Colors.grey, fontSize: 10)),
                                                    Text(_activeRide!['pickup_address'] ?? 'Cocody, Riviera 3', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                  ],
                                                ),
                                              ),
                                              OutlinedButton(
                                                onPressed: () {},
                                                style: OutlinedButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                                  minimumSize: const Size(60, 30),
                                                  side: BorderSide(color: Colors.grey.shade300),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                ),
                                                child: const Text("Navigation", style: TextStyle(fontSize: 11, color: Colors.black87)),
                                              ),
                                            ],
                                          ),
                                          const Padding(
                                            padding: EdgeInsets.only(left: 7.0),
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: SizedBox(height: 12, child: VerticalDivider(color: Colors.grey, thickness: 2)),
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              const Icon(Icons.location_on, color: primaryColor, size: 16),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    const Text("Destination", style: TextStyle(color: Colors.grey, fontSize: 10)),
                                                    Text(_activeRide!['dropoff_address'] ?? 'Plateau, Immeuble SCIAM', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                  ],
                                                ),
                                              ),
                                              Text(
                                                _activeRide!['distance'] ?? '7,2 km',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // 3. Panneau inférieur : Montant & Boutons d'action
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 15,
                                      offset: Offset(0, -5),
                                    )
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Montant et mode de paiement
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text("Montant de la course", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                            const SizedBox(height: 2),
                                            Text(
                                              "${_activeRide!['price'] ?? '2 500'}F",
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: primaryColor),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[100],
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: Colors.grey.shade300),
                                          ),
                                          child: Row(
                                            children: const [
                                              Icon(Icons.wallet, size: 16, color: Colors.black54),
                                              SizedBox(width: 6),
                                              Text("Espèces", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),

                                    // Bouton d'action dynamique selon le statut
                                    if (_activeRide!['status'] == 'accepted')
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: () => _handleRideAction('arrive', _activeRide!['id']),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: primaryColor,
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          child: const Text("Arriver au point de prise en charge", style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold)),
                                        ),
                                      )
                                    else if (_activeRide!['status'] == 'arrived')
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: () => _handleRideAction('start', _activeRide!['id']),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.black87,
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          child: const Text("Démarrer la course", style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold)),
                                        ),
                                      )
                                    else if (_activeRide!['status'] == 'in_progress')
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: () => _handleRideAction('complete', _activeRide!['id']),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          child: const Text("Terminer la course", style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                    const SizedBox(height: 10),

                                    // Bouton Annuler
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton(
                                        onPressed: () {
                                          // Logique d'annulation de course si nécessaire
                                        },
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          side: const BorderSide(color: Colors.red),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        child: const Text("Annuler la course", style: TextStyle(fontSize: 14, color: Colors.red, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                  // Historique tab
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.history, size: 60, color: Colors.grey),
                        SizedBox(height: 12),
                        Text("Historique des courses vide.",
                            style: TextStyle(color: Colors.grey, fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}