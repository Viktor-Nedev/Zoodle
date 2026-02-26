import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// Форма за подаване на нов сигнал
class ReportAnimalSheet extends StatefulWidget {
  final Function(String status, String description, File? image) onSubmit;

  const ReportAnimalSheet({super.key, required this.onSubmit});

  @override
  State<ReportAnimalSheet> createState() => _ReportAnimalSheetState();
}

class _ReportAnimalSheetState extends State<ReportAnimalSheet> {
  String? _selectedStatus;
  final _descriptionController = TextEditingController();
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  final List<String> _statuses = ['Ранено', 'Болно', 'Изгубено', 'Опасно'];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source, imageQuality: 82);
      if (pickedFile == null) return;
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    } catch (e) {
      print('Грешка при избор на снимка: $e');
    }
  }

  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Избери от галерия'),
              onTap: () {
                _pickImage(ImageSource.gallery);
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Направи снимка'),
              onTap: () {
                _pickImage(ImageSource.camera);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _handleSubmit() {
    if (_selectedStatus == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Избери състояние на животното.')),
      );
      return;
    }
    widget.onSubmit(_selectedStatus!, _descriptionController.text.trim(), _imageFile);
  }

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
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Подай сигнал за животно',
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Избери състояние, добави снимка и кратко описание.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 560 ? 4 : 2;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _statuses.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 3.2,
                ),
                itemBuilder: (context, index) {
                  final status = _statuses[index];
                  final selected = _selectedStatus == status;
                  final color = _statusColor(status);
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedStatus = status;
                      });
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: selected ? color : color.withOpacity(0.13),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected ? color : color.withOpacity(0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _statusIcon(status),
                            size: 16,
                            color: selected ? Colors.white : color,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              status,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: selected ? Colors.white : color,
                                fontWeight: FontWeight.w700,
                              ),
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
          const SizedBox(height: 14),
          InkWell(
            onTap: () => _showImageSourceActionSheet(context),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 148,
              width: double.infinity,
              decoration: BoxDecoration(
                color: scheme.surfaceVariant.withOpacity(0.55),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: scheme.outlineVariant),
                image: _imageFile != null
                    ? DecorationImage(
                        image: FileImage(_imageFile!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _imageFile == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined, color: scheme.primary, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          'Добави снимка',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.black54,
                          child: IconButton(
                            onPressed: () {
                              setState(() {
                                _imageFile = null;
                              });
                            },
                            padding: EdgeInsets.zero,
                            iconSize: 14,
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(
<<<<<<< HEAD
              labelText: 'Кратко описание',
=======
              labelText: 'Кратко описание (по желание)',
>>>>>>> daf5cffc7dddbd691e91900be77907b2d13a96f9
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _handleSubmit,
              icon: const Icon(Icons.send_rounded),
              label: const Text('Изпрати сигнал'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
