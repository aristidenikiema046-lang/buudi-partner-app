import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:buudi_shared/buudi_shared.dart';

import 'screens/auth/partner_role_selection_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/driver/driver_navigation_shell.dart';

/// Contournement SSL pour le développement local (certificats auto-signés & HTTP)
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

/// Clé globale pour la navigation via notifications FCM
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Logique de redirection propre à l'app Partenaires quand on tape sur une
/// notification (ex: validation/rejet de dossier chauffeur ou livreur).
void _handlePartnerNotificationClick(
  RemoteMessage message,
  GlobalKey<NavigatorState> navigatorKey,
) {
  final status = message.data['status'];

  if (status == 'approved') {
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
  } else if (status == 'rejected') {
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/role_selection', (route) => false);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  HttpOverrides.global = MyHttpOverrides();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('==================================================');
    debugPrint('⚠️ ERREUR DETECTEE PAR FLUTTER: ${details.exception}');
    debugPrint('📍 SOURCE EXACTE (STACK TRACE):\n${details.stack}');
    debugPrint('==================================================');
  };

  await Firebase.initializeApp();

  await FcmService.init(navigatorKey, onNotificationClick: _handlePartnerNotificationClick);

  runApp(const BuudiPartnerApp());
}

class BuudiPartnerApp extends StatelessWidget {
  const BuudiPartnerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthBloc>(
      create: (context) => AuthBloc()..add(AppStarted()),
      child: MaterialApp(
        title: 'Buudi Partenaires',
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primaryColor: const Color(0xFFFF5722),
          scaffoldBackgroundColor: Colors.white,
          fontFamily: 'Roboto',
        ),

        // Écran initial : choix Chauffeur Pro / Livreur (plus de "Client" ici)
        home: const PartnerRoleSelectionScreen(),

        routes: {
          '/role_selection': (context) => const PartnerRoleSelectionScreen(),
          '/login': (context) => const LoginScreen(),

          // Espace commun Chauffeurs & Livreurs une fois le compte validé
          '/partner_home': (context) => const DriverNavigationShell(),

          '/partner_waiting': (context) => const Scaffold(
                body: Center(
                  child: Text("Compte en attente de validation"),
                ),
              ),
        },
      ),
    );
  }
}
