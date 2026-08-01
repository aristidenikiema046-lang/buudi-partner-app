import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/driver_service.dart';
import '../delivery_completed_screen.dart';

const Color _primaryColor = Color(0xFFFF5722);

/// Libellés de la timeline à 4 points du cycle de livraison. Les statuts
/// backend ("accepted", "arrived", "in_progress", "completed") sont les
/// mêmes que côté chauffeur - seul le libellé affiché change.
const List<String> _timelineSteps = [
  "Commande acceptée",
  "Récupérer le colis",
  "Livrer au client",
  "Livraison terminée",
];

class DeliveryOrdersTab extends StatefulWidget {
  const DeliveryOrdersTab({Key? key}) : super(key: key);

  @override
  State<DeliveryOrdersTab> createState() => _DeliveryOrdersTabState();
}

class _DeliveryOrdersTabState extends State<DeliveryOrdersTab> {
  bool _isLoading = true;
  Map<String, dynamic>? _activeRide;

  @override
  void initState() {
    super.initState();
    _loadActiveRide();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token') ?? prefs.getString('token');
  }

  Future<void> _loadActiveRide() async {
    setState(() => _isLoading = true);
    try {
      final token = await _getToken();
      if (token != null) {
        final result = await DriverService.getActiveRide(token);
        if (result['success'] == true) {
          setState(() => _activeRide = result['data']);
        }
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  /// Nombre d'étapes de la timeline déjà validées selon le statut de la course.
  int _doneStepsForStatus(String? status) {
    switch (status) {
      case 'accepted':
        return 1;
      case 'arrived':
        return 2;
      case 'in_progress':
        return 3;
      default:
        return 0;
    }
  }

  Future<void> _handleRideAction(String actionType, String rideId) async {
    final token = await _getToken();
    if (token == null) return;

    setState(() => _isLoading = true);

    Map<String, dynamic> result = {'success': false};

    if (actionType == 'arrive') {
      result = await DriverService.arriveAtPickup(token, rideId);
    } else if (actionType == 'start') {
      result = await DriverService.startRide(token, rideId);
    } else if (actionType == 'complete') {
      // Le résumé "Livraison effectuée" a besoin des infos de la course
      // (prix, distance, adresses...) : on les garde localement avant l'appel,
      // car DriverService.completeRide() ne renvoie que success/message.
      final rideBeforeCompletion = Map<String, dynamic>.from(_activeRide ?? {});
      result = await DriverService.completeRide(token, rideId);

      if (result['success'] == true && mounted) {
        // push() et non pushReplacement() : cet écran peut être atteint soit
        // via un push explicite (après acceptation depuis l'accueil), soit
        // en tant qu'onglet affiché directement par DeliveryNavigationShell
        // (pas de route poussée dans ce cas) - pushReplacement remplacerait
        // alors la coquille entière (barre de navigation comprise).
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DeliveryCompletedScreen(ride: rideBeforeCompletion),
          ),
        );
        return;
      }
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

  Future<void> _openNavigation() async {
    if (_activeRide == null) return;

    final bool goingToPickup = _activeRide!['status'] != 'in_progress';
    final double? lat = double.tryParse(
      (goingToPickup ? _activeRide!['pickup_latitude'] : _activeRide!['destination_latitude'])?.toString() ?? '',
    );
    final double? lng = double.tryParse(
      (goingToPickup ? _activeRide!['pickup_longitude'] : _activeRide!['destination_longitude'])?.toString() ?? '',
    );

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Coordonnées indisponibles pour la navigation."), backgroundColor: Colors.red),
      );
      return;
    }

    final googleNavUri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    final fallbackUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');

    if (await canLaunchUrl(googleNavUri)) {
      await launchUrl(googleNavUri);
    } else {
      await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _callNumber(String? phone, String missingMessage) async {
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(missingMessage), backgroundColor: Colors.red),
      );
      return;
    }
    final telUri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(telUri)) {
      await launchUrl(telUri);
    }
  }

  Future<void> _cancelDelivery() async {
    if (_activeRide == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Annuler la livraison ?"),
        content: const Text(
          "L'expéditeur sera informé et la commande sera remise à disposition d'un autre livreur si elle n'est pas encore en cours.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Retour"),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text("Annuler la livraison", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final token = await _getToken();
      final rideId = _activeRide?['id'];
      if (token == null || rideId == null) return;

      setState(() => _isLoading = true);
      final result = await DriverService.cancelRide(token, rideId.toString());

      if (!mounted) return;
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Livraison annulée.'), backgroundColor: Colors.green),
        );
        _loadActiveRide();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Une erreur est survenue.'), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Livraison en cours",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primaryColor))
          : _activeRide == null
              ? RefreshIndicator(
                  onRefresh: _loadActiveRide,
                  color: _primaryColor,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.local_shipping_outlined, size: 60, color: Colors.grey),
                              SizedBox(height: 12),
                              Text("Aucune livraison en cours.", style: TextStyle(color: Colors.grey, fontSize: 14)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : _buildActiveDeliveryView(),
    );
  }

  Widget _buildActiveDeliveryView() {
    final ride = _activeRide!;
    final String? status = ride['status']?.toString();
    final int doneSteps = _doneStepsForStatus(status);
    final bool goingToPickup = status != 'in_progress';

    return Stack(
      children: [
        // 1. Carte en arrière-plan (placeholder décoratif - navigation réelle
        // déléguée à Google Maps externe via le bouton "Navigation").
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
                    "Trajet vers ${goingToPickup ? 'le point de retrait' : 'le client'}",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),

        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildTimeline(doneSteps),
                const SizedBox(height: 12),
                _buildContactsCard(ride, goingToPickup),
                const SizedBox(height: 12),
                _buildAddressesCard(ride),
                if (ride['package_type'] != null || ride['package_weight_kg'] != null) ...[
                  const SizedBox(height: 12),
                  _buildPackageCard(ride),
                ],
              ],
            ),
          ),
        ),

        // Panneau inférieur : montant & bouton d'action
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, -5))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Gain de la livraison", style: TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(height: 2),
                        Text(
                          "${ride['price'] ?? '0'}F",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: _primaryColor),
                        ),
                      ],
                    ),
                    OutlinedButton.icon(
                      onPressed: _openNavigation,
                      icon: const Icon(Icons.navigation_outlined, size: 16),
                      label: const Text("Navigation", style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (status == 'accepted')
                  _buildActionButton(
                    "J'ai récupéré le colis",
                    _primaryColor,
                    () => _handleRideAction('arrive', ride['id'].toString()),
                  )
                else if (status == 'arrived')
                  _buildActionButton(
                    "En route vers le client",
                    Colors.black87,
                    () => _handleRideAction('start', ride['id'].toString()),
                  )
                else if (status == 'in_progress')
                  _buildActionButton(
                    "Terminer la livraison",
                    Colors.green,
                    () => _handleRideAction('complete', ride['id'].toString()),
                  ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _cancelDelivery,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Annuler la livraison", style: TextStyle(fontSize: 14, color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(String label, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildTimeline(int doneSteps) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, spreadRadius: 2)],
      ),
      child: Row(
        children: List.generate(_timelineSteps.length, (index) {
          final bool done = index < doneSteps;
          final bool active = index == doneSteps;
          final Color dotColor = done ? Colors.green : (active ? _primaryColor : Colors.grey.shade300);

          return Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    if (index > 0)
                      Expanded(
                        child: Container(height: 2, color: index <= doneSteps ? Colors.green : Colors.grey.shade300),
                      ),
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: dotColor,
                      ),
                      child: done ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
                    ),
                    if (index < _timelineSteps.length - 1)
                      Expanded(
                        child: Container(height: 2, color: index < doneSteps ? Colors.green : Colors.grey.shade300),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _timelineSteps[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                    color: active ? _primaryColor : Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildContactsCard(Map<String, dynamic> ride, bool goingToPickup) {
    final passenger = ride['passenger'];
    final senderName = passenger?['name'] ?? "Expéditeur";
    final senderPhone = passenger?['phone']?.toString();
    final recipientName = ride['recipient_name'] ?? "Destinataire";
    final recipientPhone = ride['recipient_phone']?.toString();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildContactRow(
            label: "Expéditeur (retrait)",
            name: senderName.toString(),
            highlighted: goingToPickup,
            onCall: () => _callNumber(senderPhone, "Numéro de l'expéditeur indisponible."),
          ),
          const Divider(color: Colors.white24, height: 20),
          _buildContactRow(
            label: "Destinataire (livraison)",
            name: recipientName.toString(),
            highlighted: !goingToPickup,
            onCall: () => _callNumber(recipientPhone, "Numéro du destinataire indisponible."),
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow({
    required String label,
    required String name,
    required bool highlighted,
    required VoidCallback onCall,
  }) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: highlighted ? _primaryColor : Colors.grey[700],
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
              Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: highlighted ? _primaryColor : Colors.grey[700],
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.phone, color: Colors.white, size: 18),
            onPressed: onCall,
          ),
        ),
      ],
    );
  }

  Widget _buildAddressesCard(Map<String, dynamic> ride) {
    final pickup = ride['pickup_address'] ?? 'Point de retrait';
    final dropoff = ride['destination_address'] ?? 'Point de livraison';
    final distance = ride['distance_km'];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, spreadRadius: 2)],
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
                    const Text("Point de retrait", style: TextStyle(color: Colors.grey, fontSize: 10)),
                    Text(pickup.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
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
              const Icon(Icons.location_on, color: _primaryColor, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Point de livraison", style: TextStyle(color: Colors.grey, fontSize: 10)),
                    Text(dropoff.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
              if (distance != null)
                Text("$distance km", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPackageCard(Map<String, dynamic> ride) {
    final packageType = ride['package_type'];
    final packageWeight = ride['package_weight_kg'];
    final instructions = ride['delivery_instructions'];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2_outlined, size: 18, color: Colors.black54),
              const SizedBox(width: 8),
              Text(
                [
                  if (packageType != null) packageType.toString(),
                  if (packageWeight != null) "$packageWeight kg",
                ].join(" • "),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          if (instructions != null && instructions.toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(instructions.toString(), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ],
      ),
    );
  }
}
