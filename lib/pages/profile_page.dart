import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';
import '../models/badge_data.dart';
import '../pages/badges_page.dart';
import 'events_page.dart' as events_model;
import '../widgets/full_screen_image_viewer.dart';

// Основна страница за профил
class ProfilePage extends StatefulWidget {
  final String? userId;
  const ProfilePage({super.key, this.userId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const int _activeMissionsTarget = 4;

  List<MissionBadge> _earnedBadges = [];
  User? _currentUser;
  Map<String, dynamic>? _userData;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<events_model.Event>> _myEvents = {};
  List<events_model.Event> _selectedEvents = [];
  bool _isLoading = true;
  Map<String, int> _badgeCounts = {};
  String? _selectedBadgeId;
  List<String> _activeMissionIds = [];
  int _completedMissionsCount = 0;

  // Контролери за контакт формата
  final _contactNameController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _contactMessageController = TextEditingController();
  bool _isSendingMessage = false;
  bool _isProfilePhotoSheetOpen = false;

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

    String targetUserId = '';
    if (widget.userId == null) {
      final user = await _getCurrentUserWithRetry();
      if (user == null) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }
      _currentUser = user;
      targetUserId = user.uid;
    } else {
      _currentUser = null;
      targetUserId = widget.userId ?? '';
    }

    if (targetUserId.isEmpty) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    Map<String, dynamic>? loadedUserData;
    Map<DateTime, List<events_model.Event>> fetchedEvents = {};
    List<MissionBadge> badgesToShow = [];
    Map<String, int> badgeCounts = {};
    String? selectedBadgeId;
    List<String> activeMissionIds = List<String>.from(_activeMissionIds);
    int completedMissionsCount = _completedMissionsCount;

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
        final QuerySnapshot attendingSnapshot = await FirebaseFirestore.instance
            .collection('events')
            .where('attendees', arrayContains: targetUserId)
            .get();

        final QuerySnapshot interestedSnapshot = await FirebaseFirestore.instance
            .collection('events')
            .where('interested', arrayContains: targetUserId)
            .get();

        final Map<String, events_model.Event> uniqueEvents = {};
        for (final doc in attendingSnapshot.docs) {
          try {
            final event = events_model.Event.fromFirestore(doc);
            uniqueEvents[event.id] = event;
          } catch (_) {}
        }
        for (final doc in interestedSnapshot.docs) {
          try {
            final event = events_model.Event.fromFirestore(doc);
            uniqueEvents[event.id] = event;
          } catch (_) {}
        }

        for (final event in uniqueEvents.values) {
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
        final int reportsCount =
            (loadedUserData['reportsCount'] as num?)?.toInt() ?? 0;
        final int scansCount =
            (loadedUserData['scansCount'] as num?)?.toInt() ?? 0;
        final int eventsCount =
            (loadedUserData['eventsCount'] as num?)?.toInt() ?? 0;
        final Map<String, int> userStats = {
          'reportsCount': reportsCount,
          'scansCount': scansCount,
          'eventsCount': eventsCount,
        };

        final bool isOwner = widget.userId == null;
        activeMissionIds =
            _extractStringList(loadedUserData['activeMissionIds']);
        activeMissionIds = activeMissionIds
            .where((id) => _findMissionById(id) != null)
            .toSet()
            .toList();
        List<String> completedMissionIds =
            _extractStringList(loadedUserData['completedMissionIds']);
        completedMissionIds = completedMissionIds.toSet().toList();
        completedMissionsCount =
            (loadedUserData['completedMissionsCount'] as num?)?.toInt() ?? 0;

        bool missionStateChanged = false;
        final Set<String> activeSet = activeMissionIds.toSet();
        final Set<String> completedSet = completedMissionIds.toSet();
        final Random random = Random();

        if (activeSet.isEmpty && allMissions.isNotEmpty) {
          if (isOwner) {
            while (activeSet.length < _activeMissionsTarget &&
                activeSet.length < allMissions.length) {
              final List<BadgeMission> candidates = allMissions
                  .where((mission) => !activeSet.contains(mission.id))
                  .toList();
              if (candidates.isEmpty) break;
              final List<BadgeMission> notCompleted = candidates
                  .where((mission) =>
                      (userStats[mission.statKey] ?? 0) < mission.goal)
                  .toList();
              final List<BadgeMission> pool =
                  notCompleted.isNotEmpty ? notCompleted : candidates;
              final BadgeMission mission =
                  pool[random.nextInt(pool.length)];
              activeSet.add(mission.id);
            }
            activeMissionIds = activeSet.toList();
            missionStateChanged = true;
          } else {
            activeMissionIds = allMissions
                .take(_activeMissionsTarget)
                .map((mission) => mission.id)
                .toList();
            activeSet
              ..clear()
              ..addAll(activeMissionIds);
          }
        }

        if (isOwner) {
          for (final missionId in List<String>.from(activeMissionIds)) {
            final mission = _findMissionById(missionId);
            if (mission == null) {
              activeMissionIds.remove(missionId);
              activeSet.remove(missionId);
              missionStateChanged = true;
              continue;
            }
            final int userProgress = userStats[mission.statKey] ?? 0;
            if (userProgress >= mission.goal) {
              if (!completedSet.contains(mission.id)) {
                completedMissionsCount += 1;
                completedSet.add(mission.id);
              }
              activeMissionIds.remove(mission.id);
              activeSet.remove(mission.id);
              missionStateChanged = true;
            }
          }

          while (activeMissionIds.length < _activeMissionsTarget &&
              allMissions.isNotEmpty) {
            List<BadgeMission> pool = allMissions
                .where((mission) =>
                    !activeSet.contains(mission.id) &&
                    !completedSet.contains(mission.id))
                .toList();

            if (pool.isEmpty) {
              if (completedSet.isEmpty) break;
              completedSet.clear();
              missionStateChanged = true;
              pool = allMissions
                  .where((mission) => !activeSet.contains(mission.id))
                  .toList();
            }

            if (pool.isEmpty) break;

            final List<BadgeMission> notCompleted = pool
                .where((mission) =>
                    (userStats[mission.statKey] ?? 0) < mission.goal)
                .toList();
            final List<BadgeMission> choicePool =
                notCompleted.isNotEmpty ? notCompleted : pool;
            final BadgeMission mission =
                choicePool[random.nextInt(choicePool.length)];
            activeMissionIds.add(mission.id);
            activeSet.add(mission.id);
            missionStateChanged = true;
          }
        }

        badgesToShow = _buildMissionBadges(activeMissionIds, userStats);

        if (isOwner && missionStateChanged) {
          await FirebaseFirestore.instance.collection('users').doc(targetUserId).set({
            'activeMissionIds': activeMissionIds,
            'completedMissionIds': completedSet.toList(),
            'completedMissionsCount': completedMissionsCount,
            'missionsUpdatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      badgeCounts = _extractBadgeCounts(loadedUserData?['badgeCounts']);
      selectedBadgeId = loadedUserData?['selectedBadgeId']?.toString();

      if (widget.userId == null && loadedUserData != null) {
        await _awardBadgesIfEligible(
          userId: targetUserId,
          badgeCounts: badgeCounts,
          completedMissionsCount: completedMissionsCount,
        );
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
          _badgeCounts = badgeCounts;
          _selectedBadgeId = selectedBadgeId;
          _activeMissionIds = activeMissionIds;
          _completedMissionsCount = completedMissionsCount;
          _isLoading = false;
        });
      }
    }
  }

  Future<User?> _getCurrentUserWithRetry() async {
    var user = FirebaseAuth.instance.currentUser;
    if (user != null) return user;
    try {
      user = await FirebaseAuth.instance
          .authStateChanges()
          .firstWhere((candidate) => candidate != null)
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      return null;
    }
    return user;
  }

  Map<String, int> _extractBadgeCounts(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw.map(
        (key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0),
      );
    }
    return {};
  }

  List<String> _extractStringList(dynamic raw) {
    if (raw is Iterable) {
      return raw
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return [];
  }

  int _totalBadgeCount(Map<String, int> counts) {
    int total = 0;
    for (final value in counts.values) {
      total += value;
    }
    return total;
  }

  CollectibleBadge? _findBadgeById(String? badgeId) {
    if (badgeId == null || badgeId.isEmpty) return null;
    for (final badge in badgeCatalog) {
      if (badge.id == badgeId) return badge;
    }
    return null;
  }

  BadgeMission? _findMissionById(String missionId) {
    for (final mission in allMissions) {
      if (mission.id == missionId) return mission;
    }
    return null;
  }

  List<MissionBadge> _buildMissionBadges(
    List<String> missionIds,
    Map<String, int> userStats,
  ) {
    final List<MissionBadge> badges = [];
    for (final missionId in missionIds) {
      final mission = _findMissionById(missionId);
      if (mission == null) continue;
      final int userProgress = userStats[mission.statKey] ?? 0;
      badges.add(
        MissionBadge(
          name: mission.name,
          description: mission.description,
          icon: mission.icon,
          color: mission.color,
          earned: userProgress >= mission.goal,
        ),
      );
    }
    return badges;
  }

  Future<void> _awardBadgesIfEligible({
    required String userId,
    required Map<String, int> badgeCounts,
    required int completedMissionsCount,
  }) async {
    final int awardTarget = completedMissionsCount ~/ 4;
    final int currentAwards = _totalBadgeCount(badgeCounts);

    if (awardTarget <= currentAwards || badgeCatalog.isEmpty) return;

    final Random random = Random();
    final int toAward = awardTarget - currentAwards;
    final List<CollectibleBadge> available = badgeCatalog
        .where((badge) => (badgeCounts[badge.id] ?? 0) == 0)
        .toList();
    for (int i = 0; i < toAward; i++) {
      final List<CollectibleBadge> pool =
          available.isNotEmpty ? available : badgeCatalog;
      final badge = pool[random.nextInt(pool.length)];
      badgeCounts[badge.id] = (badgeCounts[badge.id] ?? 0) + 1;
      available.removeWhere((item) => item.id == badge.id);
    }

    await FirebaseFirestore.instance.collection('users').doc(userId).set({
      'badgeCounts': badgeCounts,
      'badgesLastAwardedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  List<events_model.Event> _getEventsForDay(DateTime day) {
    return _myEvents[DateTime(day.year, day.month, day.day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          title: Text(widget.userId != null ? 'Профил' : 'Моят Профил'),
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(widget.userId != null ? 'Профил' : 'Моят Профил'),
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
      body: _buildProfilePage(),
    );
  }

  // Настройки
  void _openSettings() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Настройки',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0B8457),
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading:
                    const Icon(Icons.mail_outline, color: Color(0xFF0B8457)),
                title: const Text('Свържи се с нас'),
                onTap: () {
                  Navigator.pop(context);
                  _showContactDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.person, color: Color(0xFF0B8457)),
                title: const Text('Редактирай профил'),
                onTap: () {
                  Navigator.pop(context);
                  _editProfile();
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.brightness_6_outlined,
                    color: Color(0xFF0B8457)),
                title: const Text('Тъмна тема'),
                value: AnimalRescueApp.of(context).themeMode == ThemeMode.dark,
                onChanged: (value) {
                  AnimalRescueApp.of(context)
                      .setThemeMode(value ? ThemeMode.dark : ThemeMode.light);
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.amber),
                title:
                    const Text('Изход', style: TextStyle(color: Colors.amber)),
                onTap: () async {
                  Navigator.pop(context);
                  await FirebaseAuth.instance.signOut();
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  // Основна профилна страница
  Widget _buildProfilePage() {
    return RefreshIndicator(
      onRefresh: _loadUserDataAndEvents,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 26),
        children: [
          _buildProfileInfo(),
          const SizedBox(height: 18),
          _buildMissionsSummaryCard(),
          if (widget.userId == null) ...[
            const SizedBox(height: 18),
            _buildAlbumSection(),
            const SizedBox(height: 18),
            _buildCalendarSection(),
          ],
        ],
      ),
    );
  }

  // Информация за профила
  Widget _buildProfileInfo() {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final int uniqueBadges =
        _badgeCounts.values.where((value) => value > 0).length;
    final String username = _userData?['username'] ?? 'Няма име';
    final int reportsCount = _userData?['reportsCount'] ?? 0;
    final int scansCount = _userData?['scansCount'] ?? 0;
    final int eventsCount = _userData?['eventsCount'] ?? 0;
    final String profilePictureUrl =
        (_userData?['profilePictureUrl'] ?? '').toString();
    final bool hasProfilePicture = profilePictureUrl.isNotEmpty;
    final String userEmail =
        (_userData?['email'] ?? _currentUser?.email ?? '').toString();
    final selectedBadge = _findBadgeById(_selectedBadgeId);
    final String userTitle =
        selectedBadge?.title ?? _getUserTitle(uniqueBadges);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer,
            scheme.secondaryContainer,
            scheme.tertiaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(
              alpha: scheme.brightness == Brightness.dark ? 0.3 : 0.1,
            ),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: scheme.primary.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 44,
                        backgroundColor: scheme.surface,
                        backgroundImage: hasProfilePicture
                            ? CachedNetworkImageProvider(profilePictureUrl)
                            : null,
                        child: hasProfilePicture
                            ? null
                            : Icon(
                                Icons.person_rounded,
                                size: 50,
                                color: scheme.primary,
                              ),
                      ),
                    ),
                    if (widget.userId == null)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Material(
                          color: scheme.primary,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _changeProfilePicture,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                Icons.camera_alt_rounded,
                                size: 16,
                                color: scheme.onPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      if (userEmail.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          userEmail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surface.withValues(
                            alpha: scheme.brightness == Brightness.dark
                                ? 0.16
                                : 0.78,
                          ),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.workspace_premium_rounded,
                              size: 16,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                userTitle,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ),
                            if (selectedBadge != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: scheme.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: scheme.outlineVariant),
                                ),
                                padding: const EdgeInsets.all(4),
                                child: Image.asset(selectedBadge.assetPath),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final double tileWidth = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: tileWidth,
                      child: _buildStatItem(
                        'Докладвани',
                        reportsCount.toString(),
                        Icons.flag_rounded,
                      ),
                    ),
                    SizedBox(
                      width: tileWidth,
                      child: _buildStatItem(
                        'Сканирани',
                        scansCount.toString(),
                        Icons.camera_alt_rounded,
                      ),
                    ),
                    SizedBox(
                      width: tileWidth,
                      child: _buildStatItem(
                        'Събития',
                        eventsCount.toString(),
                        Icons.event_rounded,
                      ),
                    ),
                    SizedBox(
                      width: tileWidth,
                      child: _buildStatItem(
                        'Баджове',
                        uniqueBadges.toString(),
                        Icons.emoji_events_rounded,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumSection() {
    final user = _currentUser;
    if (user == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [scheme.primaryContainer, scheme.tertiaryContainer],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.auto_awesome_rounded, color: scheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Zoodle AI Албум',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Разгледай запазените AI снимки в профила.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.tonalIcon(
              onPressed: _openAlbumPage,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Отвори'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionsSummaryCard() {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final int progressToNext = _completedMissionsCount % 4;
    final double progress = progressToNext / 4;
    final int activeCount = _activeMissionIds.length;
    final int totalBadges = badgeCatalog.length;
    final int uniqueEarned =
        _badgeCounts.values.where((value) => value > 0).length;
    final int totalEarned = _totalBadgeCount(_badgeCounts);
    final int remaining = totalBadges - uniqueEarned;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: _openBadgesPage,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Мисии и баджове',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Icon(Icons.arrow_forward_rounded, color: scheme.primary),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: scheme.surfaceContainerHighest,
                color: scheme.primary,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'За следващ бадж: $progressToNext/4 мисии',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Активни мисии: $activeCount • Общо изпълнени: $_completedMissionsCount',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Баджове: $uniqueEarned / $totalBadges • Общо спечелени: $totalEarned • Остават: $remaining',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openBadgesPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BadgesPage(
          missionBadges: _earnedBadges,
          completedMissionsCount: _completedMissionsCount,
          badgeCounts: Map<String, int>.from(_badgeCounts),
          selectedBadgeId: _selectedBadgeId,
          canEdit: widget.userId == null,
          userId: _currentUser?.uid,
        ),
      ),
    );
    await _loadUserDataAndEvents();
  }

  void _openAlbumPage() {
    final user = _currentUser;
    if (user == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileAlbumPage(userId: user.uid),
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
    if (label == 'Докладвани' &&
        _currentUser != null &&
        widget.userId == null) {
      return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          String displayValue = value;
          if (snapshot.hasData && snapshot.data!.exists) {
            var userData = snapshot.data!.data() as Map<String, dynamic>?;
            displayValue = (userData?['reportsCount'] ?? 0).toString();
          }
          return _buildStatCard(label, displayValue, icon);
        },
      );
    }

    return _buildStatCard(label, value, icon);
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(
          alpha: scheme.brightness == Brightness.dark ? 0.24 : 0.72,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: scheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Секция с календар
  Widget _buildCalendarSection() {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Моят календар',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${_selectedEvents.length} събития',
                    style: textTheme.labelLarge?.copyWith(
                      color: scheme.onSecondaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(
                  alpha: scheme.brightness == Brightness.dark ? 0.35 : 0.6,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: TableCalendar<events_model.Event>(
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
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: textTheme.bodySmall!.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  weekendStyle: textTheme.bodySmall!.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                calendarStyle: CalendarStyle(
                  defaultTextStyle: textTheme.bodyMedium!,
                  weekendTextStyle: textTheme.bodyMedium!,
                  outsideTextStyle: textTheme.bodyMedium!.copyWith(
                    color: scheme.outline,
                  ),
                  todayDecoration: BoxDecoration(
                    color: scheme.tertiary.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                  selectedTextStyle: textTheme.bodyMedium!.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  markerDecoration: BoxDecoration(
                    color: scheme.secondary,
                    shape: BoxShape.circle,
                  ),
                ),
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  leftChevronIcon: Icon(
                    Icons.chevron_left_rounded,
                    color: scheme.primary,
                  ),
                  rightChevronIcon: Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.primary,
                  ),
                  titleTextStyle: textTheme.titleMedium!.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Събития на избраната дата',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            if (_selectedEvents.isEmpty)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'Няма събития за избрания ден.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              ..._selectedEvents.map(_buildCalendarEvent),
          ],
        ),
      ),
    );
  }

  // Елемент от календара за събитие
  Widget _buildCalendarEvent(events_model.Event event) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final userId = _currentUser?.uid;
    final isAttending = userId != null && event.attendees.contains(userId);
    final statusText = isAttending ? 'Ще участвам' : 'Имам интерес';
    final statusBackground =
        isAttending ? scheme.primaryContainer : scheme.secondaryContainer;
    final statusForeground = isAttending
        ? scheme.onPrimaryContainer
        : scheme.onSecondaryContainer;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.surfaceContainerHighest.withValues(
              alpha: scheme.brightness == Brightness.dark ? 0.45 : 0.75,
            ),
            scheme.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.event_rounded, size: 20, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                Text(
                  '${event.date.day}.${event.date.month}.${event.date.year}',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusBackground,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              statusText,
              style: textTheme.labelSmall?.copyWith(
                color: statusForeground,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Диалог за контакт
  void _showContactDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) {
              return SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
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
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildContactForm(),
                    const SizedBox(height: 24),
                    _buildContactInfo(),
                  ],
                ),
              );
            });
      },
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
                borderSide:
                    BorderSide(color: Colors.green[700] ?? Colors.green),
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
                borderSide:
                    BorderSide(color: Colors.green[700] ?? Colors.green),
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
                borderSide:
                    BorderSide(color: Colors.green[700] ?? Colors.green),
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

    _isProfilePhotoSheetOpen = true;
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
                _buildImageOption(
                    Icons.photo_library, 'Галерия', _pickFromGallery),
                _buildImageOption(Icons.photo_camera, 'Камера', _takePhoto),
                _buildImageOption(Icons.delete, 'Премахни', _removePhoto),
              ],
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      _isProfilePhotoSheetOpen = false;
    });
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
    final XFile? image =
        await picker.pickImage(source: source, imageQuality: 85);
    if (image == null) return;

    File imageFile = File(image.path);
    try {
      debugPrint('Започва качване на профилна снимка...');
      String filePath = 'profile_pictures/${_currentUser!.uid}.jpg';

      // Опростяване на инициализацията - използваме стандартната инстанция
      Reference storageRef = FirebaseStorage.instance.ref().child(filePath);

      debugPrint('Път на съхранение: $filePath');

      UploadTask uploadTask = storageRef.putFile(imageFile);

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        if (mounted) {
          double progress =
              (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
          debugPrint(
            'Прогрес на качване: ${progress.toStringAsFixed(1)}% (State: ${snapshot.state})',
          );
        }
      }, onError: (e) {
        debugPrint('ГРЕШКА по време на стрийм на качване: $e');
      });

      TaskSnapshot snapshot = await uploadTask;
      String downloadURL = await snapshot.ref.getDownloadURL();
      debugPrint('Снимката е качена успешно! URL: $downloadURL');

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .update({'profilePictureUrl': downloadURL});

      if (mounted) {
        setState(() {
          _userData?['profilePictureUrl'] = downloadURL;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Профилната снимка е обновена!')),
        );
        if (_isProfilePhotoSheetOpen && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    } on FirebaseException catch (e) {
      debugPrint('Грешка при качване на снимка: ${e.code} ${e.message}');
      if (mounted) {
        _showMessage(_toUserFriendlyStorageError(e));
      }
    } catch (e) {
      debugPrint('Грешка при качване на снимка: $e');
      if (mounted) {
        _showMessage('Грешка: $e');
      }
    }
  }

  String _toUserFriendlyStorageError(FirebaseException e) {
    final rawMessage = (e.message ?? '').toLowerCase();
    final bool isServiceAccountOrSessionIssue =
        rawMessage.contains('service account') ||
            rawMessage.contains('httpresult: 412') ||
            rawMessage.contains('code: 412') ||
            rawMessage.contains('upload session');

    if (isServiceAccountOrSessionIssue) {
      return 'Firebase Storage не е коректно конфигуриран (HTTP 412). '
          'Отвори Firebase Console > Storage и направи re-link на bucket-а, '
          'след което изчакай няколко минути.';
    }

    if (rawMessage.contains('app check')) {
      return 'Липсва App Check provider. Добави App Check за Android или '
          'използвай Debug provider по време на разработка.';
    }

    if (e.code == 'unauthenticated' || e.code == 'unauthorized') {
      return 'Нямаш достъп за качване. Провери входа и Storage правилата.';
    }

    return 'Неуспешно качване към Firebase Storage: ${e.code}.';
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

    if (mounted) {
      setState(() {
        _userData?['profilePictureUrl'] = '';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Профилната снимка е премахната!')),
      );
      if (_isProfilePhotoSheetOpen && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
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

class ProfileAlbumPage extends StatelessWidget {
  final String userId;
  const ProfileAlbumPage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zoodle AI Албум'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('album')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Нямате достъп до албума или има проблем с правилата.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('Неуспешно зареждане на албума.'));
          }

          final docs = snapshot.data!.docs.toList()
            ..sort((a, b) {
              final ta =
                  (a['timestamp'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
              final tb =
                  (b['timestamp'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
              return tb.compareTo(ta);
            });

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_library_outlined,
                      size: 56, color: scheme.outline),
                  const SizedBox(height: 12),
                  Text(
                    'Все още нямате запазени AI снимки.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(14),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.78,
            ),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final imageUrl = (data['imageUrl'] ?? '').toString();
              final animalType = (data['animalType'] ?? 'Животно').toString();
              final breed = (data['breed'] ?? '').toString();
              final isRedBook = data['isRedBook'] == true;

              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: imageUrl.isEmpty
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                FullScreenImageViewer(imageUrl: imageUrl),
                          ),
                        );
                      },
                child: Card(
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16)),
                          child: imageUrl.isEmpty
                              ? Container(
                                  color: scheme.surfaceVariant,
                                  child: Center(
                                    child: Icon(
                                      Icons.image_not_supported_outlined,
                                      color: scheme.outline,
                                      size: 34,
                                    ),
                                  ),
                                )
                              : CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              animalType,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (breed.isNotEmpty)
                              Text(
                                breed,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            if (isRedBook)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Червена книга',
                                  style: TextStyle(
                                    color: Colors.red[700],
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
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
      ),
    );
  }
}
