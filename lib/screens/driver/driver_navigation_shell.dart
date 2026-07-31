import 'package:flutter/material.dart';
import 'tabs/driver_home_tab.dart';
import 'tabs/driver_rides_tab.dart';
import 'tabs/driver_earnings_tab.dart';
import 'tabs/driver_messages_tab.dart';
import 'tabs/driver_profile_tab.dart';

class DriverNavigationShell extends StatefulWidget {
  const DriverNavigationShell({Key? key}) : super(key: key);

  @override
  State<DriverNavigationShell> createState() => _DriverNavigationShellState();
}

class _DriverNavigationShellState extends State<DriverNavigationShell> {
  int _currentIndex = 0;

  final List<Widget> _tabs = [
    const DriverHomeTab(),
    const DriverRidesTab(),
    const DriverEarningsTab(),
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
            icon: Icon(Icons.local_taxi_outlined),
            activeIcon: Icon(Icons.local_taxi),
            label: 'Courses',
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