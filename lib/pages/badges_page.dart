import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/badge_data.dart';

class BadgesPage extends StatefulWidget {
  final List<MissionBadge> missionBadges;
  final int completedMissionsCount;
  final Map<String, int> badgeCounts;
  final String? selectedBadgeId;
  final bool canEdit;
  final String? userId;

  const BadgesPage({
    super.key,
    required this.missionBadges,
    required this.completedMissionsCount,
    required this.badgeCounts,
    this.selectedBadgeId,
    this.canEdit = false,
    this.userId,
  });

  @override
  State<BadgesPage> createState() => _BadgesPageState();
}

class _BadgesPageState extends State<BadgesPage> {
  late String? _selectedBadgeId;

  @override
  void initState() {
    super.initState();
    _selectedBadgeId = widget.selectedBadgeId;
  }

  int _totalEarned() {
    int total = 0;
    for (final value in widget.badgeCounts.values) {
      total += value;
    }
    return total;
  }

  int _uniqueEarned() {
    int total = 0;
    for (final value in widget.badgeCounts.values) {
      if (value > 0) total++;
    }
    return total;
  }

  Future<void> _selectBadge(CollectibleBadge badge) async {
    if (!widget.canEdit || widget.userId == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .set({'selectedBadgeId': badge.id}, SetOptions(merge: true));
      if (!mounted) return;
      setState(() {
        _selectedBadgeId = badge.id;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Избран бадж: ${badge.title}'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Грешка при избор на бадж: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final int completedMissions = widget.completedMissionsCount;
    final int progressToNext = completedMissions % 4;
    final double progress = progressToNext / 4;
    final int activeCount = widget.missionBadges.length;
    final int totalBadges = badgeCatalog.length;
    final int uniqueEarned = _uniqueEarned();
    final int totalEarned = _totalEarned();
    final int remaining = totalBadges - uniqueEarned;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Мисии и баджове'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Прогрес по мисии',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: scheme.surfaceContainerHighest,
                    color: scheme.primary,
                    minHeight: 10,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'За следващ бадж: $progressToNext/4 мисии',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Активни мисии: $activeCount • Общо изпълнени: $completedMissions',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded,
                        size: 18, color: scheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'След 4 изпълнени мисии получаваш случаен бадж.',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                if (widget.canEdit) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Натисни бадж, за да го избереш за профила.',
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Активни мисии',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ...widget.missionBadges.map((badge) {
            final Color accent = badge.earned ? badge.color : scheme.outline;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: badge.earned
                    ? scheme.primaryContainer.withValues(alpha: 0.45)
                    : scheme.surfaceContainerHighest.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: badge.earned
                      ? scheme.primary.withValues(alpha: 0.4)
                      : scheme.outlineVariant,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(badge.icon, color: accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          badge.name,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          badge.description,
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: badge.earned
                          ? scheme.primary.withValues(alpha: 0.16)
                          : scheme.surface.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badge.earned ? 'Отключен' : 'Заключен',
                      style: textTheme.labelSmall?.copyWith(
                        color: badge.earned
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 18),
          Text(
            'Колекционерски албум',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Отключени: $uniqueEarned / $totalBadges • Общo спечелени: $totalEarned • Остават: $remaining',
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: badgeCatalog.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.85,
            ),
            itemBuilder: (context, index) {
              final badge = badgeCatalog[index];
              final int count = widget.badgeCounts[badge.id] ?? 0;
              final bool isUnlocked = count > 0;
              final bool isSelected = badge.id == _selectedBadgeId;
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? scheme.primary
                        : (isUnlocked
                            ? scheme.secondary
                            : scheme.outlineVariant),
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: isUnlocked && widget.canEdit
                      ? () => _selectBadge(badge)
                      : null,
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          Expanded(
                            child: Opacity(
                              opacity: isUnlocked ? 1.0 : 0.25,
                              child: Image.asset(
                                badge.assetPath,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            badge.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isUnlocked
                                  ? scheme.onSurface
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      if (!isUnlocked)
                        Align(
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.lock_rounded,
                            color: scheme.outline,
                            size: 22,
                          ),
                        ),
                      if (isSelected)
                        Positioned(
                          left: 4,
                          top: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Избран',
                              style: textTheme.labelSmall?.copyWith(
                                color: scheme.onPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      if (count > 1)
                        Positioned(
                          right: 4,
                          top: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'x$count',
                              style: textTheme.labelSmall?.copyWith(
                                color: scheme.onPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
