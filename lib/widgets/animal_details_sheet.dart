import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'full_screen_image_viewer.dart';

// Модерен панел с детайли за сигнал от картата
class AnimalDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isRescueTeam;
  final VoidCallback onNavigate;
  final VoidCallback onRemove;
  final bool canDelete;
  final VoidCallback onChat;
  final bool showChatButton;
  final VoidCallback onClose;

  const AnimalDetailsSheet({
    super.key,
    required this.data,
    required this.isRescueTeam,
    required this.onNavigate,
    required this.onRemove,
    required this.canDelete,
    required this.onChat,
    required this.showChatButton,
    required this.onClose,
  });

  Color _statusColor(String status) {
    switch (status) {
      case 'Опасно':
        return const Color(0xFFE45757);
      case 'Изгубено':
        return const Color(0xFF318CE7);
      case 'Болно':
        return const Color(0xFFE2A72E);
      case 'Ранено':
        return const Color(0xFFE7772E);
      default:
        return const Color(0xFF7D8A95);
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Опасно':
        return Icons.warning_amber_rounded;
      case 'Изгубено':
        return Icons.search_rounded;
      case 'Болно':
        return Icons.healing_rounded;
      case 'Ранено':
        return Icons.health_and_safety_rounded;
      default:
        return Icons.pets_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = (data['status'] ?? 'Неизвестно').toString();
    final description = (data['description'] ?? 'Няма описание').toString();
    final reporterName = (data['reporterName'] ?? 'Неизвестен').toString();
    final imageUrl = (data['imageUrl'] ?? '').toString();
    final timestamp = data['timestamp']?.toDate();
    final hasImage = imageUrl.isNotEmpty && !imageUrl.contains('placehold');
    final statusColor = _statusColor(status);
    final formattedDate = timestamp != null
        ? DateFormat('dd.MM.yyyy • HH:mm').format(timestamp)
        : 'Преди малко';

    Widget actionButton({
      required IconData icon,
      required String text,
      required VoidCallback onTap,
      Color? background,
      Color? foreground,
      bool expanded = true,
    }) {
      final child = ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 17),
        label: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12),
          backgroundColor: background ?? scheme.primary,
          foregroundColor: foreground ?? scheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      if (!expanded) return child;
      return Expanded(child: child);
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, scheme.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon(status), size: 15, color: statusColor),
                      const SizedBox(width: 6),
                      Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (isRescueTeam)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Екип',
                      style: TextStyle(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.person_outline, size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    reporterName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              formattedDate,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.surfaceVariant.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                description,
                style: TextStyle(color: scheme.onSurface, height: 1.35),
              ),
            ),
            if (hasImage) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          FullScreenImageViewer(imageUrl: imageUrl),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: double.infinity,
                    height: 145,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: scheme.surfaceVariant,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: scheme.surfaceVariant,
                      child: Icon(Icons.broken_image, color: scheme.outline),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                actionButton(
                  icon: Icons.route_rounded,
                  text: 'Навигация',
                  onTap: onNavigate,
                ),
                if (showChatButton) ...[
                  const SizedBox(width: 8),
                  actionButton(
                    icon: Icons.chat_bubble_outline_rounded,
                    text: 'Чат',
                    onTap: onChat,
                    background: const Color(0xFF2C7BE5),
                    foreground: Colors.white,
                  ),
                ],
              ],
            ),
            if (canDelete) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Премахни сигнала'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE45757),
                    side: const BorderSide(color: Color(0xFFE45757)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
