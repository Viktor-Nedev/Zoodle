import 'package:flutter/material.dart';
import 'dart:math';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isScanning = false;
  bool _showResult = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _startScanning() async {
    setState(() {
      _isScanning = true;
    });
    
    _animationController.reset();
    _animationController.forward();

    // Симулиране на AI анализ (3 секунди)
    await Future.delayed(const Duration(seconds: 3));

    setState(() {
      _isScanning = false;
      _showResult = true;
    });

    // Показване на резултатите
    _showAnimalInfo();
  }

  void _showAnimalInfo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AnimalInfoSheet(
        onSave: () {
          setState(() {
            _showResult = false;
          });
          Navigator.pop(context);
          _showSuccessSnackbar();
        },
      ),
    );
  }

  void _showSuccessSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green[400],
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('Снимката е запазена в албума!', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[50],
      appBar: AppBar(
        title: const Text(
          'AI Камера',
          style: TextStyle(
            color: Colors.green,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.green),
      ),
      body: Stack(
        children: [
          // Камера преглед (симулиран)
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.green[100]!,
                  Colors.green[50]!,
                  Colors.white,
                ],
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 40),
                
                // Рамка на камерата
                Container(
                  width: 300,
                  height: 400,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.black,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Симулирана камера
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.pets,
                              size: 80,
                              color: Colors.green[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Насочете камерата към животното',
                              style: TextStyle(
                                color: Colors.green[200],
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      
                      // Анимация за сканиране
                      if (_isScanning) _buildScanAnimation(),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Информация за сканиране
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: _isScanning ? 1.0 : 0.0,
                  child: Column(
                    children: [
                      _buildScanningAnimation(),
                      const SizedBox(height: 16),
                      Text(
                        'AI анализира животното...',
                        style: TextStyle(
                          color: Colors.green[800],
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Бутон за снимане
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.5),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                    border: Border.all(
                      color: Colors.green,
                      width: 3,
                    ),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.camera_alt,
                      size: 32,
                      color: Colors.green,
                    ),
                    onPressed: _isScanning ? null : _startScanning,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Натиснете за сканиране',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanAnimation() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return CustomPaint(
          painter: ScanPainter(_animationController.value),
          size: const Size(300, 400),
        );
      },
    );
  }

  Widget _buildScanningAnimation() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.green[100],
        shape: BoxShape.circle,
      ),
      child: Stack(
        children: [
          Center(
            child: Icon(
              Icons.pets,
              size: 40,
              color: Colors.green,
            ),
          ),
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return CircularProgressIndicator(
                value: _animationController.value,
                backgroundColor: Colors.green[100],
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                strokeWidth: 3,
              );
            },
          ),
        ],
      ),
    );
  }
}

class ScanPainter extends CustomPainter {
  final double progress;
  
  ScanPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // Сканираща линия
    final scanLineY = size.height * progress;
    canvas.drawLine(
      Offset(0, scanLineY),
      Offset(size.width, scanLineY),
      paint,
    );

    // Пулсиращи ъгли
    final cornerPaint = Paint()
      ..color = Colors.green.withOpacity(0.8)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    final cornerLength = 20.0;
    final pulse = (sin(progress * 4 * pi) * 0.5 + 0.5) * 10;

    // Горен ляв ъгъл
    canvas.drawLine(Offset(0, pulse), Offset(cornerLength, pulse), cornerPaint);
    canvas.drawLine(Offset(pulse, 0), Offset(pulse, cornerLength), cornerPaint);

    // Горен десен ъгъл
    canvas.drawLine(Offset(size.width - cornerLength, pulse), Offset(size.width, pulse), cornerPaint);
    canvas.drawLine(Offset(size.width - pulse, 0), Offset(size.width - pulse, cornerLength), cornerPaint);

    // Долен ляв ъгъл
    canvas.drawLine(Offset(0, size.height - pulse), Offset(cornerLength, size.height - pulse), cornerPaint);
    canvas.drawLine(Offset(pulse, size.height - cornerLength), Offset(pulse, size.height), cornerPaint);

    // Долен десен ъгъл
    canvas.drawLine(Offset(size.width - cornerLength, size.height - pulse), Offset(size.width, size.height - pulse), cornerPaint);
    canvas.drawLine(Offset(size.width - pulse, size.height - cornerLength), Offset(size.width - pulse, size.height), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class AnimalInfoSheet extends StatelessWidget {
  final VoidCallback onSave;

  const AnimalInfoSheet({super.key, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заглавие
          Center(
            child: Text(
              'Резултат от анализ',
              style: TextStyle(
                color: Colors.green[800],
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Информация за животното
          Row(
            children: [
              // Снимка на животното
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: Colors.green[100],
                  image: const DecorationImage(
                    image: NetworkImage('https://images.unsplash.com/photo-1552053831-71594a27632d?w=400'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              
              const SizedBox(width: 20),
              
              // Детайли
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Златен ретрийвър',
                      style: TextStyle(
                        color: Colors.green[800],
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Вид: Куче',
                      style: TextStyle(
                        color: Colors.green[600],
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Порода: Golden Retriever',
                      style: TextStyle(
                        color: Colors.green[600],
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Увереност: 94%',
                      style: TextStyle(
                        color: Colors.green[600],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Описание
          Text(
            'Златният ретрийвър е дружелюбно, интелигентно и послушно куче. Известен е със своята златна козина и любяща природа.',
            style: TextStyle(
              color: Colors.green[700],
              fontSize: 14,
              height: 1.4,
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Бутони за действие
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: const BorderSide(color: Colors.green),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Затвори'),
                ),
              ),
              
              const SizedBox(width: 16),
              
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: onSave,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.save_alt, size: 20),
                      SizedBox(width: 8),
                      Text('Запази в албум'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
