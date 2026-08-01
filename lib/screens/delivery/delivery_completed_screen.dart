import 'package:flutter/material.dart';

const Color _primaryColor = Color(0xFFFF5722);

/// Résumé affiché juste après complete(). Pas de section évaluation : le
/// système de notation n'existe pas encore côté backend.
class DeliveryCompletedScreen extends StatelessWidget {
  final Map<String, dynamic> ride;

  const DeliveryCompletedScreen({Key? key, required this.ride}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double price = double.tryParse(ride['price']?.toString() ?? '') ?? 0;
    final bool isCash = ride['payment_method'] == 'especes';
    // Même règle que le backend (DriverRideController::completeRide) : la
    // commission de 15% n'est prélevée que sur les livraisons payées en
    // espèces (le livreur la doit à Buudi sous 24h) ; les paiements en ligne
    // créditent le montant plein au wallet, sans commission dans ce code.
    final double fee = isCash ? price * 0.15 : 0;
    final double net = price - fee;

    final double? distanceKm = double.tryParse(ride['distance_km']?.toString() ?? '');
    final String? duration = _computeDuration(ride['started_at']?.toString());

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                child: const Icon(Icons.check, color: Colors.white, size: 48),
              ),
              const SizedBox(height: 20),
              const Text(
                "Livraison terminée !",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                ride['destination_address']?.toString() ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 28),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _buildRow("Gain de la livraison", "${price.toStringAsFixed(0)} F"),
                    const SizedBox(height: 12),
                    _buildRow(
                      isCash ? "Frais de service (15%)" : "Frais de service",
                      isCash ? "- ${fee.toStringAsFixed(0)} F" : "Payé en ligne",
                      valueColor: isCash ? Colors.red : Colors.grey,
                    ),
                    const Divider(height: 28),
                    _buildRow(
                      "Gain net",
                      "${net.toStringAsFixed(0)} F",
                      bold: true,
                      valueColor: Colors.green,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  if (distanceKm != null)
                    Expanded(child: _buildStatTile(Icons.route_outlined, "${distanceKm.toStringAsFixed(1)} km", "Distance")),
                  if (distanceKm != null && duration != null) const SizedBox(width: 12),
                  if (duration != null)
                    Expanded(child: _buildStatTile(Icons.timer_outlined, duration, "Durée")),
                ],
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    "Retour à l'accueil",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  String? _computeDuration(String? startedAt) {
    if (startedAt == null) return null;
    try {
      final start = DateTime.parse(startedAt);
      final elapsed = DateTime.now().difference(start);
      final minutes = elapsed.inMinutes;
      if (minutes < 60) return "$minutes min";
      return "${elapsed.inHours}h${(minutes % 60).toString().padLeft(2, '0')}";
    } catch (_) {
      return null;
    }
  }

  Widget _buildRow(String label, String value, {bool bold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: bold ? 15 : 13, color: bold ? Colors.black : Colors.grey[700])),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 18 : 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ?? Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildStatTile(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: _primaryColor, size: 20),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      ),
    );
  }
}
