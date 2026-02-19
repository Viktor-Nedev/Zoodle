// marker_info_sheet.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'full_screen_image_viewer.dart';

// Панел с информация за маркер на картата
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

  // Определяне на цвят според статуса на животното
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Опасно':
        return Colors.red;
      case 'Изгубено':
        return Colors.blue;
      case 'Болно':
        return Colors.yellow;
      case 'Ранено':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Извличане на данни от маркера
    String status = data['status'] ?? 'Неизвестен';
    String description = data['description'] ?? 'Няма описание';
    String reporterName = data['reporterName'] ?? 'Неизвестен';
    String imageUrl = data['imageUrl'] ?? '';
    DateTime? timestamp = data['timestamp']?.toDate();

    Color statusColor = _getStatusColor(status);
    bool hasImage = imageUrl.isNotEmpty && !imageUrl.contains('placehold');
    String formattedDate = timestamp != null 
        ? DateFormat('dd.MM, HH:mm').format(timestamp) 
        : 'Сега';

    // Помощен метод за изграждане на малки бутони
    Widget buildActionButton({
      required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onPressed,
      bool isFullWidth = false,
    }) {
      return ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          minimumSize: Size(isFullWidth ? double.infinity : 0, 28),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
        icon: Icon(icon, size: 14),
        label: Text(label),
      );
    }

    final buttons = [
      buildActionButton(
        icon: Icons.navigation,
        label: 'Навигация',
        color: Colors.green,
        onPressed: onNavigate,
      ),
      if (showChatButton) ...[
        const SizedBox(width: 4, height: 4),
        buildActionButton(
          icon: Icons.chat,
          label: 'Чат',
          color: Colors.blue,
          onPressed: onChat,
        ),
      ],
    ];

    return Container(
      constraints: const BoxConstraints(maxWidth: 240),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заглавие със статус и Close бутон
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: statusColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onClose,
                  child: Icon(Icons.close, size: 18, color: Colors.grey[400]),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Основно съдържание
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              reporterName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            formattedDate,
                            style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                if (hasImage)
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FullScreenImageViewer(imageUrl: imageUrl),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        height: 54,
                        width: 54,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 54,
                          height: 54,
                          color: Colors.grey[50],
                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 54,
                          height: 54,
                          color: Colors.grey[50],
                          child: const Icon(Icons.broken_image, size: 16, color: Colors.grey),
                        ),
                      ),
                    ),
                  )
                else
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: buttons,
                  ),
              ],
            ),

            // Бутони отдолу, ако има снимка
            if (hasImage) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  for (int i = 0; i < buttons.length; i++) ...[
                    if (buttons[i] is! SizedBox) Expanded(child: buttons[i]),
                    if (i < buttons.length - 1 && buttons[i+1] is! SizedBox) const SizedBox(width: 4),
                  ],
                ],
              ),
            ],

            // Бутон за изтриване
            if (canDelete) ...[
              const SizedBox(height: 4),
              buildActionButton(
                icon: Icons.delete_outline,
                label: 'Премахни сигнала',
                color: Colors.red[400]!,
                onPressed: onRemove,
                isFullWidth: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}