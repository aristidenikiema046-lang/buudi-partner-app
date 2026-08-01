import 'package:flutter/material.dart';
import 'tabs/delivery_home_tab.dart';
import 'tabs/delivery_orders_tab.dart';
import '../driver/tabs/driver_earnings_tab.dart';
import '../driver/tabs/driver_messages_tab.dart';
import '../driver/tabs/driver_profile_tab.dart';

class DeliveryNavigationShell extends StatefulWidget {
  const DeliveryNavigationShell({Key? key}) : super(key: key);

  @override
  State<DeliveryNavigationShell> createState() => _DeliveryNavigationShellState();
}

class _DeliveryNavigationShellState extends State<DeliveryNavigationShell> {
  int _currentIndex = 0;

  final List<Widget> _tabs = [
    const DeliveryHomeTab(),
    const DeliveryOrdersTab(),
    // Même endpoint /driver/dashboard que le chauffeur : seul le libellé change.
    const DriverEarningsTab(activityLabel: 'livraisons'),
    const DriverMessagesTab(),
    const DriverProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _tabs[_currentIndex],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFFF5722),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping_outlined),
            activeIcon: Icon(Icons.local_shipping),
            label: 'Livraisons',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet),
            label: 'Gains',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
