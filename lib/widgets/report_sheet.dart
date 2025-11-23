import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// Форма за докладване на животно
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
  final List<String> _statuses = ["Ранено", "Болно", "Изгубено", "Опасно"];

  // Избор на снимка от галерия или камера
  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source, imageQuality: 80);
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      print("Грешка при избор на снимка: $e");
    }
  }

  // Показване на избор за източник на снимка
  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Галерия'),
              onTap: () {
                _pickImage(ImageSource.gallery);
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Камера'),
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

  // Обработка на изпращане на формата
  void _handleSubmit() {
    if (_selectedStatus == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Моля, изберете състояние на животното."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    widget.onSubmit(_selectedStatus!, _descriptionController.text, _imageFile);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заглавие
          Text(
            "Докладвай за животно",
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          
          // Избор на състояние
          Text("Състояние:", style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10.0,
            children: _statuses.map((status) {
              return ChoiceChip(
                label: Text(status),
                selected: _selectedStatus == status,
                onSelected: (selected) {
                  setState(() {
                    _selectedStatus = status;
                  });
                },
                selectedColor: theme.primaryColor,
                labelStyle: TextStyle(
                  color: _selectedStatus == status ? Colors.white : Colors.black,
                ),
                backgroundColor: Colors.grey[200],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: _selectedStatus == status
                            ? theme.primaryColor
                            : Colors.grey[300] ?? Colors.grey,
                  )
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          
          // Поле за снимка
          GestureDetector(
            onTap: () => _showImageSourceActionSheet(context),
            child: Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[400] ?? Colors.grey),
                image: _imageFile != null
                  ? DecorationImage(
                      image: FileImage(_imageFile!),
                      fit: BoxFit.cover
                    )
                  : null,
              ),
              child: _imageFile == null
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt, color: Colors.grey, size: 40),
                        Text("Добави снимка", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : null,
            ),
          ),
          const SizedBox(height: 20),
          
          // Поле за описание
          TextField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: "Кратко описание (незадължително)",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: theme.primaryColor, width: 2),
              ),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 20),
          
          // Бутон за изпращане
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _handleSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                "Изпрати сигнал",
                style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}