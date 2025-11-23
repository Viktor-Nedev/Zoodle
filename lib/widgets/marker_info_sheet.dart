// marker_info_sheet.dart
import 'package:flutter/material.dart';

// Панел с информация за маркер на картата
class MarkerInfoSheet extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isRescueTeam;
  final VoidCallback onNavigate;
  final VoidCallback onRemove;
  final bool canDelete;
  final VoidCallback onChat;
  final bool showChatButton;

  const MarkerInfoSheet({
    super.key,
    required this.data,
    required this.isRescueTeam,
    required this.onNavigate,
    required this.onRemove,
    required this.canDelete,
    required this.onChat,
    required this.showChatButton,
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

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заглавие със статус
            Row(
              children: [
                // Индикатор за статус
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            
            // Описание на случая
            if (description.isNotEmpty && description != 'Няма описание')
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Описание:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 15),
                ],
              ),

            // Снимка на животното
            if (imageUrl.isNotEmpty && imageUrl != "https://placehold.co/600x400/666666/FFFFFF?text=Няма+Снимка")
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Снимка:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      image: DecorationImage(
                        image: NetworkImage(imageUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                ],
              ),

            // Информация за репортера
            Text(
              'Докладвано от: $reporterName',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            
            // Дата на докладване
            if (timestamp != null)
              Text(
                'Дата: ${timestamp.toString().substring(0, 16)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            
            const SizedBox(height: 20),

            // Ред с основни бутони за действие
            Row(
              children: [
                // Бутон за навигация
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onNavigate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.navigation, size: 20),
                    label: const Text('Навигация'),
                  ),
                ),
                const SizedBox(width: 10),
                // Бутон за чат (ако е позволен)
                if (showChatButton)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onChat,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.chat, size: 20),
                      label: const Text('Чат'),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 10),

            // Бутон за изтриване (само за позволени потребители)
            if (canDelete)
              ElevatedButton.icon(
                onPressed: onRemove,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  minimumSize: const Size(double.infinity, 48),
                ),
                icon: const Icon(Icons.delete, size: 20),
                label: const Text('Премахни сигнал'),
              ),
          ],
        ),
      ),
    );
  }
}