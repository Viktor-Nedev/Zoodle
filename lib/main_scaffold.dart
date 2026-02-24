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

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Списък с всички страници в приложението - дефиниран в build за реактивност
    final List<Widget> pages = <Widget>[
      const MapScreen(),      
      const ChatPage(),      
      CameraPage(isVisible: _selectedIndex == 2),     
      const EventsPage(),    
      const ProfilePage(),   
    ];

    return Scaffold(
      // IndexedStack за запазване на състоянието на страниците
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      // Долно навигационно меню
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          boxShadow: [
            BoxShadow(
              blurRadius: 20,
              color: scheme.shadow.withOpacity(.12),
            )
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 8),
            child: GNav(
              rippleColor: scheme.surfaceVariant,
              hoverColor: scheme.surfaceVariant,
              gap: 4,
              activeColor: scheme.onPrimary,
              iconSize: 24,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              duration: const Duration(milliseconds: 400),
              tabBackgroundColor: scheme.primary,
              color: scheme.onSurfaceVariant,
              tabs: const [
                 GButton(
                  icon: Icons.map_outlined,
                  text: 'Карта',
                ),
                 GButton(
                  icon: Icons.chat_bubble_outline,
                  text: 'Чат',
                ),
                 GButton(
                  icon: Icons.camera_alt_outlined,
                  text: 'AI Камера',
                ),
                 GButton(
                  icon: Icons.event_outlined,
                  text: 'Събития',
                ),
                 GButton(
                  icon: Icons.person_outline,
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
