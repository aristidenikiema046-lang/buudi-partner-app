import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:buudi_shared/buudi_shared.dart';
import '../driver/driver_navigation_shell.dart';
import '../delivery/delivery_navigation_shell.dart';
import '../../services/driver_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _loginController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String _selectedRole = "driver";
  bool _showPasswordField = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Redirection post-login pour l'app Partenaires.
  ///
  /// Une fois le dossier validé, on distingue Chauffeur (Voiture) et Livreur
  /// (Moto/Vélo) : le `vehicle_type` n'est pas présent dans la réponse de
  /// connexion (le endpoint /login ne charge pas la relation driverProfile),
  /// donc on va le chercher via GET /v1/driver/profile - le token JWT est
  /// déjà en mémoire (SharedPreferences) à ce stade, sauvegardé par AuthBloc
  /// avant l'émission de l'état Authenticated.
  Future<void> _handleNavigation(BuildContext context, Authenticated state) async {
    final user = state.user;

    print("🚀 Début de la redirection pour le rôle: ${user.role}");

    final status = user.driverProfile?.status ?? "pending";
    print("📋 Statut du dossier détecté: $status");

    if (status != "approved") {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/partner_waiting',
        (route) => false,
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? prefs.getString('token');

    String? vehicleType;
    if (token != null) {
      final profileResult = await DriverService.getDriverProfile(token);
      if (profileResult['success'] == true) {
        vehicleType = profileResult['data']?['vehicle_type']?.toString();
      }
    }
    print("🚗 vehicle_type détecté: $vehicleType");

    if (!context.mounted) return;

    if (vehicleType == 'Moto' || vehicleType == 'Vélo') {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const DeliveryNavigationShell()),
        (route) => false,
      );
    } else {
      // "Voiture", ou vehicle_type absent/inattendu : espace Chauffeur par
      // défaut plutôt que de bloquer le partenaire avec un écran d'erreur.
      if (vehicleType != 'Voiture') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Type de véhicule non reconnu, ouverture de l'espace Chauffeur par défaut."),
            backgroundColor: Colors.orange,
          ),
        );
      }
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const DriverNavigationShell()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) async {
        if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (state is Authenticated) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Bienvenue, ${state.user.name} !"),
              duration: const Duration(seconds: 2),
            ),
          );

          try {
            await _handleNavigation(context, state);
          } catch (e) {
            print("❌ Erreur de route : $e");
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Erreur de redirection: vérifiez la configuration des routes ($e)"),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;

        return WillPopScope(
          onWillPop: () async {
            if (_showPasswordField) {
              setState(() {
                _showPasswordField = false;
                _passwordController.clear();
              });
              return false;
            }
            return true;
          },
          child: Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.black),
                onPressed: () {
                  if (_showPasswordField) {
                    setState(() {
                      _showPasswordField = false;
                      _passwordController.clear();
                    });
                  } else {
                    Navigator.pop(context);
                  }
                },
              ),
            ),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Text(
                      _showPasswordField ? "Mot de passe" : "Bon retour parmi nous",
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _showPasswordField
                          ? "Entrez votre mot de passe pour accéder à votre espace."
                          : "Connectez-vous pour continuer à utiliser vos services.",
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[600],
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 35),

                    if (!_showPasswordField) ...[
                      const Text(
                        "Je me connecte en tant que :",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildRoleSelector(isLoading),
                      const SizedBox(height: 25),

                      Text(
                        "Numéro de téléphone",
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _loginController,
                        keyboardType: TextInputType.phone,
                        enabled: !isLoading,
                        decoration: InputDecoration(
                          hintText: "+225 07 12 34 56 78",
                          hintStyle: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.phone_android_rounded,
                            color: Colors.grey[400],
                            size: 18,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF7F7F9),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ] else ...[
                      const Text(
                        "Votre mot de passe",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _passwordController,
                        keyboardType: TextInputType.visiblePassword,
                        obscureText: _obscurePassword,
                        enabled: !isLoading,
                        style: const TextStyle(fontSize: 16, color: Colors.black),
                        decoration: InputDecoration(
                          hintText: "Entrez votre mot de passe",
                          hintStyle: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.lock_outline_rounded,
                            color: Colors.grey[400],
                            size: 18,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: Colors.grey[400],
                              size: 18,
                            ),
                            onPressed: () {
                              setState(
                                () => _obscurePassword = !_obscurePassword,
                              );
                            },
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF7F7F9),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: isLoading ? null : () {},
                          child: const Text(
                            "Mot de passe oublié ?",
                            style: TextStyle(
                              color: Color(0xFFFF5722),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],

                    const Spacer(),

                    // --- BOUTON PRINCIPAL ---
                    ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              if (!_showPasswordField) {
                                if (_loginController.text.trim().isNotEmpty) {
                                  setState(() => _showPasswordField = true);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "Veuillez entrer votre numéro de téléphone",
                                      ),
                                    ),
                                  );
                                }
                              } else {
                                if (_passwordController.text.trim().isNotEmpty) {
                                  String? fcmToken = await FcmService.getToken();

                                  if (!mounted) return;
                                  context.read<AuthBloc>().add(
                                        SignInRequested(
                                          phone: _loginController.text.trim(), 
                                          password: _passwordController.text.trim(),
                                          role: _selectedRole,
                                          fcmToken: fcmToken,
                                        ),
                                      );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Veuillez entrer votre mot de passe",
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5722),
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _showPasswordField
                                      ? "Valider et se connecter"
                                      : "Suivant",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 25),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRoleSelector(bool isLoading) {
    List<Map<String, dynamic>> roles = [
      {"label": "Chauffeur", "value": "driver", "color": const Color(0xFF2E7D32)},
      {"label": "Livreur", "value": "delivery", "color": const Color(0xFF007AFF)},
    ];

    return Row(
      children: roles.map((role) {
        bool isSelected = _selectedRole == role["value"];
        return Expanded(
          child: GestureDetector(
            onTap: isLoading
                ? null
                : () => setState(() {
                      _selectedRole = role["value"];
                      _loginController.clear();
                    }),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? role["color"].withOpacity(0.1)
                    : const Color(0xFFF7F7F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? role["color"] : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Text(
                role["label"],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? role["color"] : Colors.grey[600],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}