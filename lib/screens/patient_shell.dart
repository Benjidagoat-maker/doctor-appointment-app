import 'package:flutter/material.dart';

import 'appointments_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

class PatientShell extends StatefulWidget {
  const PatientShell({super.key});

  @override
  State<PatientShell> createState() => _PatientShellState();
}

class _PatientShellState extends State<PatientShell> {
  static const _pages = [HomeScreen(), AppointmentsScreen(), ProfileScreen()];

  int _selectedIndex = 0;

  void _selectPage(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final destinations = const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Appointments',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ];

        if (constraints.maxWidth >= 800) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _selectPage,
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home_rounded),
                      label: Text('Home'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.calendar_month_outlined),
                      selectedIcon: Icon(Icons.calendar_month_rounded),
                      label: Text('Appointments'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.person_outline_rounded),
                      selectedIcon: Icon(Icons.person_rounded),
                      label: Text('Profile'),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: _pages[_selectedIndex]),
              ],
            ),
          );
        }

        return Scaffold(
          body: _pages[_selectedIndex],
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _selectPage,
            destinations: destinations,
          ),
        );
      },
    );
  }
}
