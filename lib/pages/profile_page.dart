import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

import '../auth/login_screen.dart';
import 'events_page.dart' as events_model;

// Модел за мисии и баджове
class BadgeMission {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final String statKey;
  final int goal;

  const BadgeMission({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.statKey,
    required this.goal,
  });
}

// Дефиниране на всички мисии
final List<BadgeMission> allMissions = [
  BadgeMission(
    id: 'report1',
    name: 'Подай 1 сигнал',
    description: 'Първа стъпка към промяната.',
    icon: Icons.flag,
    color: Colors.blue,
    statKey: 'reportsCount',
    goal: 1,
  ),
  BadgeMission(
    id: 'report5',
    name: 'Картограф',
    description: 'Докладвай 5 животни',
    icon: Icons.map,
    color: Colors.green,
    statKey: 'reportsCount',
    goal: 5,
  ),
  BadgeMission(
    id: 'event1',
    name: 'Включи се в събитие',
    description: 'Доброволческа активност.',
    icon: Icons.people,
    color: Colors.purple,
    statKey: 'eventsCount',
    goal: 1,
  ),
  BadgeMission(
    id: 'scan1',
    name: 'Изследовател',
    description: 'Сканирай 1 животно с AI',
    icon: Icons.camera_alt,
    color: Colors.amber,
    statKey: 'scansCount',
    goal: 1,
  ),
];

// Основна страница за профил
class ProfilePage extends StatefulWidget {
  final String? userId;
  const ProfilePage({super.key, this.userId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int _selectedIndex = 0;
  List<Badge> _earnedBadges = [];
  String _profileImageUrl = 'https://picsum.photos/200/200?random=5';
  User? _currentUser;
  Map<String, dynamic>? _userData;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<events_model.Event>> _myEvents = {};
  List<events_model.Event> _selectedEvents = [];
  bool _isLoading = true;

  // Контролери за контакт формата
  final _contactNameController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _contactMessageController = TextEditingController();
  bool _isSendingMessage = false;

  @override
  void initState() {
    super.initState();
    _loadUserDataAndEvents();
  }

  @override
  void dispose() {
    _contactNameController.dispose();
    _contactEmailController.dispose();
    _contactMessageController.dispose();
    super.dispose();
  }

  // Зареждане на потребителски данни и събития
  Future<void> _loadUserDataAndEvents() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    String targetUserId = widget.userId ?? FirebaseAuth.instance.currentUser?.uid ?? '';
    if (targetUserId.isEmpty) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    if (widget.userId == null) {
      _currentUser = FirebaseAuth.instance.currentUser;
    } else {
      _currentUser = null;
    }

    Map<String, dynamic>? loadedUserData;
    Map<DateTime, List<events_model.Event>> fetchedEvents = {};
    List<Badge> badgesToShow = [];

    try {
      // Зареждане на потребителски данни
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUserId)
          .get(const GetOptions(source: Source.server));

      if (userDoc.exists) {
        loadedUserData = userDoc.data() as Map<String, dynamic>?;
      }

      // Зареждане на събития само за собствения профил
      if (widget.userId == null) {
        QuerySnapshot eventSnapshot = await FirebaseFirestore.instance
            .collection('events')
            .where('attendees', arrayContains: targetUserId)
            .get();

        for (var doc in eventSnapshot.docs) {
          var event = events_model.Event.fromFirestore(doc);
          DateTime eventDate =
              DateTime(event.date.year, event.date.month, event.date.day);
          if (fetchedEvents[eventDate] == null) {
            fetchedEvents[eventDate] = [];
          }
          fetchedEvents[eventDate]!.add(event);
        }
      }

      // Обработка на мисии и баджове
      if (loadedUserData != null) {
        int reportsCount = loadedUserData['reportsCount'] ?? 0;
        int scansCount = loadedUserData['scansCount'] ?? 0;
        int eventsCount = loadedUserData['eventsCount'] ?? 0;
        Map<String, int> userStats = {
          'reportsCount': reportsCount,
          'scansCount': scansCount,
          'eventsCount': eventsCount,
        };

        for (var mission in allMissions) {
          int userProgress = userStats[mission.statKey] ?? 0;
          bool isEarned = userProgress >= mission.goal;
          badgesToShow.add(Badge(
            name: mission.name,
            description: mission.description,
            icon: mission.icon,
            color: mission.color,
            earned: isEarned,
          ));
        }
      }

    } catch (e) {
      print("Грешка при зареждане на профил: $e");
    } finally {
      if (mounted) {
        setState(() {
          _userData = loadedUserData;
          _myEvents = fetchedEvents;
          _selectedDay = _focusedDay;
          _selectedEvents = _getEventsForDay(_selectedDay!);
          _earnedBadges = badgesToShow;
          _isLoading = false;
        });
      }
    }
  }

  List<events_model.Event> _getEventsForDay(DateTime day) {
    return _myEvents[DateTime(day.year, day.month, day.day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.userId != null ? 'Профил' : 'Моят Профил'),
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userId != null ? 'Профил' : 'Моят Профил'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: widget.userId == null
            ? [
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: _openSettings,
                ),
              ]
            : null,
      ),
      body: Column(
        children: [
          // Табове за навигация
          Container(
            decoration: BoxDecoration(
              color: Colors.green[50],
              border: Border(
                bottom: BorderSide(color: Colors.green[100] ?? Colors.green),
              ),
            ),
            child: Row(
              children: [
                _buildTab('Основно', 0),
                _buildTab('Сигнали', 1),
                if (widget.userId == null) _buildTab('Контакт', 2),
              ],
            ),
          ),
          Expanded(
            child: _buildCurrentPage(),
          ),
        ],
      ),
    );
  }

  // Изграждане на таб
  Widget _buildTab(String text, int index) {
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: _selectedIndex == index
                    ? Colors.green[700] ?? Colors.green
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color:
                  _selectedIndex == index ? Colors.green[700] ?? Colors.green : Colors.grey[600],
              fontWeight:
                  _selectedIndex == index ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  // Изграждане на текущата страница
  Widget _buildCurrentPage() {
    switch (_selectedIndex) {
      case 0:
        return _buildProfilePage();
      case 1:
        return _buildReportsPage();
      case 2:
        return _buildContactPage();
      default:
        return _buildProfilePage();
    }
  }

  // Основна профилна страница
  Widget _buildProfilePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildProfileInfo(),
          const SizedBox(height: 24),
          if (widget.userId == null) _buildMissionsSection(),
          if (widget.userId == null) const SizedBox(height: 24),
          if (widget.userId == null) _buildCalendarSection(),
        ],
      ),
    );
  }

  // Информация за профила
  Widget _buildProfileInfo() {
    int earnedBadges = _earnedBadges.where((badge) => badge.earned).length;
    String userTitle = _getUserTitle(earnedBadges);
    String username = _userData?['username'] ?? 'Няма име';
    int reportsCount = _userData?['reportsCount'] ?? 0;
    int scansCount = _userData?['scansCount'] ?? 0;
    int eventsCount = _userData?['eventsCount'] ?? 0;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.green[100],
                  backgroundImage: _userData?['profilePictureUrl'] != null &&
                          _userData!['profilePictureUrl'].isNotEmpty
                      ? NetworkImage(_userData!['profilePictureUrl'])
                      : null,
                  child: _userData?['profilePictureUrl'] == null ||
                          _userData!['profilePictureUrl'].isEmpty
                      ? Icon(
                          Icons.person,
                          size: 60,
                          color: Colors.green[700],
                        )
                      : null,
                ),
                if (widget.userId == null)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.green[700],
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt,
                            size: 16, color: Colors.white),
                        onPressed: _changeProfilePicture,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              username,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                userTitle,
                style: TextStyle(
                  color: Colors.green[800],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Докладвани', reportsCount.toString(), Icons.flag),
                _buildStatItem('Сканирани', scansCount.toString(), Icons.camera_alt),
                _buildStatItem('Събития', eventsCount.toString(), Icons.event),
                _buildStatItem('Баджове', earnedBadges.toString(), Icons.emoji_events),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Определяне на потребителска титла
  String _getUserTitle(int earnedBadges) {
    if (earnedBadges >= 6) return 'Майстор Зоолог';
    if (earnedBadges >= 4) return 'Експерт по животни';
    if (earnedBadges >= 2) return 'Активен фотограф';
    return 'Начинаещ';
  }

  // Статистически елемент
  Widget _buildStatItem(String label, String value, IconData icon) {
    if (label == 'Докладвани') {
      return StreamBuilder<DocumentSnapshot>(
        stream: _currentUser != null 
            ? FirebaseFirestore.instance
                .collection('users')
                .doc(_currentUser!.uid)
                .snapshots()
            : null,
        builder: (context, snapshot) {
          String displayValue = value;
          if (snapshot.hasData && snapshot.data!.exists) {
            var userData = snapshot.data!.data() as Map<String, dynamic>?;
            displayValue = (userData?['reportsCount'] ?? 0).toString();
          }
          
          return Column(
            children: [
              Icon(icon, size: 24, color: Colors.green[700]),
              const SizedBox(height: 4),
              Text(
                displayValue,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          );
        },
      );
    }
    
    return Column(
      children: [
        Icon(icon, size: 24, color: Colors.green[700]),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.green[700],
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  // Секция с мисии и баджове
  Widget _buildMissionsSection() {
    int earnedCount = _earnedBadges.where((b) => b.earned).length;
    int totalBadges = allMissions.length;
    double progress = totalBadges > 0 ? earnedCount / totalBadges : 0;
    String userTitle = _getUserTitle(earnedCount);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Мисии',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Твоята титла: $userTitle',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.green[700],
              ),
            ),
            const SizedBox(height: 8),
            // Прогрес бар
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green[600] ?? Colors.green),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 4),
            Text(
              '$earnedCount/$totalBadges изпълнени',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            // Списък с мисии
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _earnedBadges.length,
              itemBuilder: (context, index) {
                var badge = _earnedBadges[index];
                return CheckboxListTile(
                  title: Text(badge.name,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(badge.description),
                  value: badge.earned,
                  onChanged: null,
                  secondary: Icon(badge.icon,
                      color: badge.earned ? badge.color : Colors.grey),
                  activeColor: badge.color,
                  controlAffinity: ListTileControlAffinity.leading,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Секция с календар
  Widget _buildCalendarSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Моят Календар',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
            ),
            const SizedBox(height: 16),
            TableCalendar<events_model.Event>(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              eventLoader: _getEventsForDay,
              selectedDayPredicate: (day) {
                return isSameDay(_selectedDay, day);
              },
              onDaySelected: (selectedDay, focusedDay) {
                if (!isSameDay(_selectedDay, selectedDay)) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                    _selectedEvents = _getEventsForDay(selectedDay);
                  });
                }
              },
              onFormatChanged: (format) {
                if (_calendarFormat != format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                }
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: Colors.green[300],
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Colors.green[700],
                  shape: BoxShape.circle,
                ),
                markerDecoration: BoxDecoration(
                  color: Colors.orange[700],
                  shape: BoxShape.circle,
                ),
              ),
              headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: TextStyle(
                    color: Colors.green[800],
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  )),
            ),
            const SizedBox(height: 16),
            Text(
              'Събития на този ден',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
            const SizedBox(height: 8),
            if (_selectedEvents.isEmpty)
              const Text('Няма събития за избрания ден.')
            else
              ..._selectedEvents.map(_buildCalendarEvent).toList(),
          ],
        ),
      ),
    );
  }

  // Елемент от календара за събитие
  Widget _buildCalendarEvent(events_model.Event event) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.event, size: 20, color: Colors.green[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${event.date.day}.${event.date.month}.${event.date.year}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Ще участвам',
              style: TextStyle(
                fontSize: 10,
                color: Colors.green[800],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Страница с подадени сигнали
  Widget _buildReportsPage() {
    if (widget.userId != null) {
      return const Center(
        child: Text(
          "Сигналите са видими само в собствения профил.",
          style: TextStyle(fontSize: 16, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (_currentUser == null) return const Center(child: Text("Не сте логнати."));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('animal_reports')
          .where('reporterId', isEqualTo: _currentUser!.uid)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.report_off, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'Все още нямате подадени сигнали',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        var reports = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reports.length,
          itemBuilder: (context, index) {
            var data = reports[index].data() as Map<String, dynamic>;
            var timestamp = (data['timestamp'] as Timestamp?)?.toDate();

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: Image.network(
                        data['imageUrl'] ?? 'https://placehold.co/100',
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['status'] ?? 'Неизвестен статус',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[800],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            data['description'] ?? 'Няма описание',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            timestamp != null
                                ? '${timestamp.day}.${timestamp.month}.${timestamp.year}'
                                : 'Няма дата',
                            style:
                                TextStyle(fontSize: 12, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Страница за контакт
  Widget _buildContactPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Свържете се с нас',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Имате въпрос или нужда от помощ? Изпратете ни съобщение!',
                    style: TextStyle(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildContactForm(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildContactInfo(),
        ],
      ),
    );
  }

  // Контактна форма
  Widget _buildContactForm() {
    return Form(
      child: Column(
        children: [
          TextFormField(
            controller: _contactNameController,
            decoration: InputDecoration(
              labelText: 'Име',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.green[700] ?? Colors.green),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _contactEmailController,
            decoration: InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.green[700] ?? Colors.green),
              ),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _contactMessageController,
            decoration: InputDecoration(
              labelText: 'Съобщение',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.green[700] ?? Colors.green),
              ),
              alignLabelWithHint: true,
            ),
            maxLines: 5,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSendingMessage ? null : _sendMessage,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSendingMessage
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Изпрати съобщение',
                      style: TextStyle(color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // Контактна информация
  Widget _buildContactInfo() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(
              leading: Icon(Icons.email, color: Colors.green[700]),
              title: const Text('Email'),
              subtitle: const Text('viktornedev08@gmail.com'),
              onTap: () async {
                final Uri uri = Uri.parse('mailto:viktornedev08@gmail.com');
                if (await canLaunchUrl(uri)) await launchUrl(uri);
              },
            ),
            ListTile(
              leading: Icon(Icons.phone, color: Colors.green[700]),
              title: const Text('Телефон'),
              subtitle: const Text('0889533397'),
              onTap: () async {
                final Uri uri = Uri.parse('tel:0889533397');
                if (await canLaunchUrl(uri)) await launchUrl(uri);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Смяна на профилна снимка
  void _changeProfilePicture() {
    if (widget.userId != null) {
      _showMessage("Можете да сменяте само собствения си профил.");
      return;
    }

    if (_currentUser == null) {
      _showMessage("Моля, влезте в профила си.");
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height: 200,
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Смяна на профилна снимка',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildImageOption(Icons.photo_library, 'Галерия', _pickFromGallery),
                _buildImageOption(Icons.photo_camera, 'Камера', _takePhoto),
                _buildImageOption(Icons.delete, 'Премахни', _removePhoto),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Опция за снимка
  Widget _buildImageOption(IconData icon, String text, VoidCallback onTap) {
    return Column(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: Colors.green[100],
          child: IconButton(
            icon: Icon(icon, color: Colors.green[700]),
            onPressed: onTap,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          text,
          style: TextStyle(
            color: Colors.green[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Качване на профилна снимка
  Future<void> _uploadProfilePicture(ImageSource source) async {
    if (_currentUser == null) return;
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source, imageQuality: 85);
    if (image == null) return;

    File imageFile = File(image.path);
    try {
      String filePath = 'profile_pictures/${_currentUser!.uid}.jpg';
      Reference storageRef = FirebaseStorage.instance.ref().child(filePath);

      await storageRef.putFile(imageFile);
      String downloadURL = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .update({'profilePictureUrl': downloadURL});

      setState(() {
        _userData?['profilePictureUrl'] = downloadURL;
      });

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Профилната снимка е обновена!')),
      );

    } catch (e) {
      print("Грешка при качване на снимка: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Грешка: $e')),
      );
    }
  }

  void _pickFromGallery() {
    _uploadProfilePicture(ImageSource.gallery);
  }

  void _takePhoto() {
    _uploadProfilePicture(ImageSource.camera);
  }

  // Премахване на профилна снимка
  void _removePhoto() async {
    if (_currentUser == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.uid)
        .update({'profilePictureUrl': ''});
    try {
      String filePath = 'profile_pictures/${_currentUser!.uid}.jpg';
      await FirebaseStorage.instance.ref().child(filePath).delete();
    } catch (e) {
      print("Файлът в Storage не съществува: $e");
    }

    setState(() {
      _userData?['profilePictureUrl'] = '';
    });

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Профилната снимка е премахната!')),
    );
  }

  // Отваряне на настройки
  void _openSettings() {
    if (widget.userId != null) {
      _showMessage("Настройките са достъпни само за собствения ви профил.");
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 400,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Настройки',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                ),
              ),
              const SizedBox(height: 24),
              _buildSettingsOption(
                  Icons.person, 'Редактирай профил', _editProfile),
              _buildSettingsOption(
                  Icons.language, 'Смени език', _changeLanguage),
              _buildSettingsOption(
                  Icons.notifications, 'Известия', _notificationSettings),
              _buildSettingsOption(
                  Icons.security, 'Поверителност', _privacySettings),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _logout,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Изход от профила'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Опция в настройките
  Widget _buildSettingsOption(IconData icon, String text, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.green[700]),
      title: Text(text),
      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[500]),
      onTap: onTap,
    );
  }

  // Редактиране на профил
  void _editProfile() {
    final nameController =
        TextEditingController(text: _userData?['username'] ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Редактирай профил'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Потребителско име'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отказ'),
          ),
          TextButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty && _currentUser != null) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(_currentUser!.uid)
                    .update({'username': nameController.text.trim()});
                setState(() {
                  _userData?['username'] = nameController.text.trim();
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Запази'),
          ),
        ],
      ),
    );
  }

  void _changeLanguage() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Смени език'),
        content:
            const Text('Функционалността за смяна на език ще бъде добавена скоро.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _notificationSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Настройки на известията'),
        content: const Text(
            'Функционалността за настройки на известията ще бъде добавена скоро.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _privacySettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Настройки за поверителност'),
        content: const Text(
            'Функционалността за настройки на поверителността ще бъде добавена скоро.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Изход от профила
 void _logout() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Изход от профила'),
      content:
          const Text('Сигурни ли сте, че искате да излезете от профила си?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Отказ', style: TextStyle(color: Colors.green[700])),
        ),
        TextButton(
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
          child: const Text('Изход', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}

  // Изпращане на съобщение
  void _sendMessage() async {
    if (_contactNameController.text.isEmpty ||
        _contactEmailController.text.isEmpty ||
        _contactMessageController.text.isEmpty) {
      _showMessage("Моля, попълнете всички полета.");
      return;
    }

    setState(() {
      _isSendingMessage = true;
    });

    try {
      await FirebaseFirestore.instance.collection('contact_messages').add({
        'name': _contactNameController.text,
        'email': _contactEmailController.text,
        'message': _contactMessageController.text,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': _currentUser?.uid ?? 'anonymous',
        'username': _userData?['username'] ?? 'anonymous',
      });

      _contactNameController.clear();
      _contactEmailController.clear();
      _contactMessageController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Съобщението е изпратено успешно!'),
            backgroundColor: Colors.green[700],
          ),
        );
      }
    } catch (e) {
      _showMessage("Грешка при изпращане: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isSendingMessage = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

// Модел за бадж
class Badge {
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final bool earned;

  const Badge({
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.earned,
  });
}