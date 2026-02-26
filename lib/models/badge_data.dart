import 'package:flutter/material.dart';

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

const List<BadgeMission> allMissions = [
  BadgeMission(
    id: 'report1',
    name: 'Първи сигнал',
    description: 'Първата крачка за помощ.',
    icon: Icons.flag,
    color: Colors.blue,
    statKey: 'reportsCount',
    goal: 1,
  ),
  BadgeMission(
    id: 'report3',
    name: 'Сигнална серия',
    description: 'Подай 3 сигнала за животни.',
    icon: Icons.flag_rounded,
    color: Colors.teal,
    statKey: 'reportsCount',
    goal: 3,
  ),
  BadgeMission(
    id: 'report5',
    name: 'Картограф',
    description: 'Докладвай 5 животни.',
    icon: Icons.map,
    color: Colors.green,
    statKey: 'reportsCount',
    goal: 5,
  ),
  BadgeMission(
    id: 'report10',
    name: 'Теренен наблюдател',
    description: 'Докладвай 10 животни.',
    icon: Icons.travel_explore_rounded,
    color: Colors.lightGreen,
    statKey: 'reportsCount',
    goal: 10,
  ),
  BadgeMission(
    id: 'report20',
    name: 'Голямо сърце',
    description: 'Докладвай 20 животни.',
    icon: Icons.favorite,
    color: Colors.redAccent,
    statKey: 'reportsCount',
    goal: 20,
  ),
  BadgeMission(
    id: 'scan1',
    name: 'Изследовател',
    description: 'Сканирай 1 животно с AI.',
    icon: Icons.camera_alt,
    color: Colors.amber,
    statKey: 'scansCount',
    goal: 1,
  ),
  BadgeMission(
    id: 'scan3',
    name: 'Сканиращ поглед',
    description: 'Сканирай 3 животни с AI.',
    icon: Icons.center_focus_strong_rounded,
    color: Colors.orange,
    statKey: 'scansCount',
    goal: 3,
  ),
  BadgeMission(
    id: 'scan5',
    name: 'AI помощник',
    description: 'Сканирай 5 животни с AI.',
    icon: Icons.auto_awesome_rounded,
    color: Colors.deepOrange,
    statKey: 'scansCount',
    goal: 5,
  ),
  BadgeMission(
    id: 'scan10',
    name: 'AI експерт',
    description: 'Сканирай 10 животни с AI.',
    icon: Icons.hub_rounded,
    color: Colors.brown,
    statKey: 'scansCount',
    goal: 10,
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
    id: 'event3',
    name: 'Екипен доброволец',
    description: 'Участвай в 3 събития.',
    icon: Icons.groups_rounded,
    color: Colors.deepPurple,
    statKey: 'eventsCount',
    goal: 3,
  ),
  BadgeMission(
    id: 'event5',
    name: 'Организатор',
    description: 'Участвай в 5 събития.',
    icon: Icons.event_available_rounded,
    color: Colors.indigo,
    statKey: 'eventsCount',
    goal: 5,
  ),
];

class MissionBadge {
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final bool earned;

  const MissionBadge({
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.earned,
  });
}

class CollectibleBadge {
  final String id;
  final String name;
  final String title;
  final String description;
  final String assetPath;

  const CollectibleBadge({
    required this.id,
    required this.name,
    required this.title,
    required this.description,
    required this.assetPath,
  });
}

const List<CollectibleBadge> badgeCatalog = [
  CollectibleBadge(
    id: 'badge_1',
    name: 'Бадж 1',
    title: 'Първа стъпка',
    description: 'Колекционерски бадж.',
    assetPath: 'badges/Picture1.png',
  ),
  CollectibleBadge(
    id: 'badge_2',
    name: 'Бадж 2',
    title: 'Следотърсач',
    description: 'Колекционерски бадж.',
    assetPath: 'badges/Picture2.png',
  ),
  CollectibleBadge(
    id: 'badge_3',
    name: 'Бадж 3',
    title: 'Спасител',
    description: 'Колекционерски бадж.',
    assetPath: 'badges/Picture3.png',
  ),
  CollectibleBadge(
    id: 'badge_4',
    name: 'Бадж 4',
    title: 'Пазител',
    description: 'Колекционерски бадж.',
    assetPath: 'badges/Picture4.png',
  ),
  CollectibleBadge(
    id: 'badge_5',
    name: 'Бадж 5',
    title: 'Полеви изследовател',
    description: 'Колекционерски бадж.',
    assetPath: 'badges/Picture5.png',
  ),
  CollectibleBadge(
    id: 'badge_6',
    name: 'Бадж 6',
    title: 'Градски спасител',
    description: 'Колекционерски бадж.',
    assetPath: 'badges/Picture6.png',
  ),
  CollectibleBadge(
    id: 'badge_7',
    name: 'Бадж 7',
    title: 'Доброволец',
    description: 'Колекционерски бадж.',
    assetPath: 'badges/Picture7.png',
  ),
  CollectibleBadge(
    id: 'badge_8',
    name: 'Бадж 8',
    title: 'Ветеринарен помощник',
    description: 'Колекционерски бадж.',
    assetPath: 'badges/Picture8.png',
  ),
  CollectibleBadge(
    id: 'badge_9',
    name: 'Бадж 9',
    title: 'Състрадателен',
    description: 'Колекционерски бадж.',
    assetPath: 'badges/Picture9.png',
  ),
  CollectibleBadge(
    id: 'badge_10',
    name: 'Бадж 10',
    title: 'Наблюдател',
    description: 'Колекционерски бадж.',
    assetPath: 'badges/Picture10.png',
  ),
  CollectibleBadge(
    id: 'badge_11',
    name: 'Бадж 11',
    title: 'Картограф',
    description: 'Колекционерски бадж.',
    assetPath: 'badges/Picture11.png',
  ),
  CollectibleBadge(
    id: 'badge_12',
    name: 'Бадж 12',
    title: 'Екипен играч',
    description: 'Колекционерски бадж.',
    assetPath: 'badges/Picture12.png',
  ),
  CollectibleBadge(
    id: 'badge_13',
    name: 'Бадж 13',
    title: 'Сигналист',
    description: 'Колекционерски бадж.',
    assetPath: 'badges/Picture13.png',
  ),
  CollectibleBadge(
    id: 'badge_14',
    name: 'Бадж 14',
    title: 'Бърз реагиращ',
    description: 'Колекционерски бадж.',
    assetPath: 'badges/Picture14.png',
  ),
  CollectibleBadge(
    id: 'badge_15',
    name: 'Бадж 15',
    title: 'Тих пазител',
    description: 'Колекционерски бадж.',
    assetPath: 'badges/Picture15.png',
  ),
  CollectibleBadge(
    id: 'badge_16',
    name: 'Бадж 16',
    title: 'Еко страж',
    description: 'Колекционерски бадж.',
    assetPath: 'badges/Picture16.png',
  ),
  CollectibleBadge(
    id: 'badge_17',
    name: 'Бадж 17',
    title: 'Нощен патрул',
    description: 'Колекционерски бадж.',
    assetPath: 'badges/Picture17.png',
  ),
  CollectibleBadge(
    id: 'badge_18',
    name: 'Бадж 18',
    title: 'Сребърен спасител',
    description: 'Колекционерски бадж.',
    assetPath: 'badges/Picture18.png',
  ),
  CollectibleBadge(
    id: 'badge_19',
    name: 'Бадж 19',
    title: 'Златен спасител',
    description: 'Колекционерски бадж.',
    assetPath: 'badges/Picture19.png',
  ),
  CollectibleBadge(
    id: 'badge_20',
    name: 'Бадж 20',
    title: 'Горски пазител',
    description: 'Колекционерски бадж.',
    assetPath: 'badges/Picture20.png',
  ),
  CollectibleBadge(
    id: 'badge_21',
    name: 'Бадж 21',
    title: 'Пазител на водите',
    description: 'Колекционерски бадж.',
    assetPath: 'badges/Picture21.png',
  ),
  CollectibleBadge(
    id: 'badge_22',
    name: 'Бадж 22',
    title: 'Хуманен герой',
    description: 'Колекционерски бадж.',
    assetPath: 'badges/Picture22.png',
  ),
  CollectibleBadge(
    id: 'badge_23',
    name: 'Бадж 23',
    title: 'Градски ангел',
    description: 'Колекционерски бадж.',
    assetPath: 'badges/Picture23.png',
  ),
  CollectibleBadge(
    id: 'badge_24',
    name: 'Бадж 24',
    title: 'Герой на квартала',
    description: 'Колекционерски бадж.',
    assetPath: 'badges/Picture24.png',
  ),
  CollectibleBadge(
    id: 'badge_25',
    name: 'Бадж 25',
    title: 'Легенда',
    description: 'Колекционерски бадж.',
    assetPath: 'badges/Picture25.png',
  ),
];
