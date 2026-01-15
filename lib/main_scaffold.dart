import 'package:flutter/material.dart';
import 'pages/map_page.dart';
import 'pages/events_page.dart';
import 'pages/camera_page.dart';
import 'pages/chat_page.dart' hide ProfilePage;
import 'pages/profile_page.dart';

// Основен scaffold с навигационно меню
class MainScaffold extends StatefulWidget {
  final int initialIndex;
  const MainScaffold({super.key, this.initialIndex = 0});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;

  // Списък с всички страници в приложението
  final List<Widget> _pages = <Widget>[
    const MapScreen(),      
    const ChatPage(),      
    const CameraPage(),     
    const EventsPage(),    
    const ProfilePage(),   
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack за запазване на състоянието на страниците
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      // Долно навигационно меню
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        selectedIndex: _selectedIndex,
        destinations: const <Widget>[
          NavigationDestination(
            selectedIcon: Icon(Icons.map),
            icon: Icon(Icons.map_outlined),
            label: 'Карта',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.chat_bubble),
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Чат',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.camera_alt),
            icon: Icon(Icons.camera_alt_outlined),
            label: 'AI Камера',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.event),
            icon: Icon(Icons.event_outlined),
            label: 'Събития',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.person),
            icon: Icon(Icons.person_outline),
            label: 'Профил',
          ),
        ],
      ),
    );
  }
}