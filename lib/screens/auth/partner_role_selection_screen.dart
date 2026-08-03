import 'package:flutter/material.dart';
import 'driver_register_screen.dart';
import 'delivery_register_screen.dart';
import 'login_screen.dart';

/// Écran d'accueil de l'app Partenaires.
///
/// Contrairement à `RoleSelectionScreen` du prototype d'origine (qui
/// proposait aussi "Client"), cette version ne propose que les deux
/// rôles pertinents pour cette app externe : Chauffeur Pro et Livreur.
class PartnerRoleSelectionScreen extends StatelessWidget {
  const PartnerRoleSelectionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Center(
              child: Image.asset(
                'assets/branding/logo_with_tagline_partner_merchant.png',
                width: MediaQuery.of(context).size.width * 0.72,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Rejoindre Buudi",
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Choisissez votre activité\npour commencer à gagner",
                      style: TextStyle(fontSize: 15, color: Colors.grey[600], height: 1.3, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 30),

                    // CHAUFFEUR PRO
                    _buildRoleCard(
                      title: "Chauffeur Pro",
                      subtitle: "Proposez vos services de transport et gagnez plus.",
                      icon: Icons.directions_car_rounded,
                      iconColor: const Color(0xFF2E7D32),
                      bgColor: const Color(0xFFE8F5E9),
                      arrowColor: const Color(0xFF2E7D32),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const DriverRegisterScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 14),

                    // LIVREUR
                    _buildRoleCard(
                      title: "Livreur",
                      subtitle: "Livrez des colis et des repas et augmentez vos revenus.",
                      icon: Icons.two_wheeler_rounded,
                      iconColor: const Color(0xFF007AFF),
                      bgColor: const Color(0xFFE3F2FD),
                      arrowColor: const Color(0xFF007AFF),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const DeliveryRegisterScreen()),
                        );
                      },
                    ),

                    const SizedBox(height: 30),
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.verified_user_rounded, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text("Sécurisé et 100% fiable", style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),
                  ],
                ),
              ),
            ),

            _buildBottomLoginBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color arrowColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF2F2F5), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: TextStyle(fontSize: 11.5, color: Colors.grey[500], height: 1.3)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(color: arrowColor, shape: BoxShape.circle),
              child: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomLoginBar(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      decoration: const BoxDecoration(
        color: Color(0xFFFFF6F1),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Déjà un compte ?",
            style: TextStyle(color: Colors.grey[700], fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5722),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Spacer(),
                Text(
                  "Se connecter",
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                Spacer(),
                Icon(Icons.chevron_right_rounded, color: Colors.white, size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
