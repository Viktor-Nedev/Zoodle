import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              blurRadius: 20,
              color: Colors.black.withOpacity(.1),
            )
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 15.0, vertical: 8.0),
            child: GNav(
              rippleColor: Colors.green[100] ?? Colors.green,
              hoverColor: Colors.green[50] ?? Colors.green,
              gap: 8,
              activeColor: Colors.white,
              iconSize: 24,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              duration: const Duration(milliseconds: 400),
              tabBackgroundColor: Colors.green,
              color: Colors.black,
              tabs: const [
                GButton(
                  icon: Icons.map,
                  text: 'Карта',
                ),
                GButton(
                  icon: Icons.chat_bubble,
                  text: 'Чат',
                ),
                GButton(
                  icon: Icons.camera_alt,
                  text: 'AI Камера',
                ),
                GButton(
                  icon: Icons.event,
                  text: 'Събития',
                ),
                GButton(
                  icon: Icons.person,
                  text: 'Профил',
                ),
              ],
              selectedIndex: _selectedIndex,
              onTabChange: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
            ),
          ),
        ),
      ),
    );
  }
}