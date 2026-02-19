import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:Zoodle/data/animal_repository.dart';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:Zoodle/services/gemini_service.dart';

class CameraPage extends StatefulWidget {
  final bool isVisible;
  const CameraPage({super.key, this.isVisible = false});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  CameraController? _controller;
  late AnimationController _animationController;
  bool _isScanning = false;
  bool _isProcessing = false;
  
  // Gemini Service
  final GeminiService _geminiService = GeminiService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    if (widget.isVisible) {
      _initializeCamera();
    }
  }

  @override
  void didUpdateWidget(CameraPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !oldWidget.isVisible) {
      _initializeCamera();
    } else if (!widget.isVisible && oldWidget.isVisible) {
      _disposeCamera();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _disposeCamera();
    } else if (state == AppLifecycleState.resumed) {
      if (widget.isVisible) {
        _initializeCamera();
      }
    }
  }

  Future<void> _initializeCamera() async {
    if (_controller != null) return; // Already initialized

    final status = await Permission.camera.request();
    if (status.isGranted) {
      try {
        final cameras = await availableCameras();
        if (cameras.isNotEmpty) {
          _controller = CameraController(
            cameras.first,
            ResolutionPreset.high,
            enableAudio: false,
          );
          await _controller!.initialize();
          if (mounted) setState(() {});
        }
      } catch (e) {
        debugPrint('Error initializing camera: $e');
      }
    }
  }

  void _disposeCamera() {
    _controller?.dispose();
    _controller = null;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeCamera();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _takePictureAndAnalyze() async {
    if (_controller == null || !_controller!.value.isInitialized || _isProcessing) return;

    setState(() {
      _isScanning = true;
      _isProcessing = true;
    });
    _animationController.reset();
    _animationController.repeat(); 

    try {
      final XFile image = await _controller!.takePicture();
      final File imageFile = File(image.path);

      // Analyze with Gemini
      final animalData = await _geminiService.analyzeImage(imageFile);
      
      _animationController.stop();
      _animationController.value = 1.0; 

      if (mounted) {
        if (animalData != null) {
           _showResult(imageFile, animalData);
           _incrementScanCount();
        } else {
           _showErrorSnackBar('Не разпознахме животно на снимката. Опитайте пак!');
        }
      }

    } catch (e) {
       debugPrint('Error: $e');
       _animationController.stop();
       if (mounted) {
        _showErrorSnackBar('Грешка: $e');
       }
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _isProcessing = false;
        });
      }
    }
  }

  void _showResult(File imageFile, AnimalData animalData) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AnimalInfoSheet(
        imageFile: imageFile,
        animalData: animalData,
        onSave: () => _saveToProfile(imageFile, animalData),
      ),
    );
  }

  Future<void> _incrementScanCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'scansCount': FieldValue.increment(1)});
        debugPrint('Scan count incremented');
      } catch (e) {
        debugPrint('Error incrementing scan count: $e');
      }
    }
  }


  Future<void> _saveToProfile(File imageFile, AnimalData data) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          _showErrorSnackBar('Моля влезте в профила си, за да запазите.');
        }
        return;
      }

      // Record messenger before any async gap or pop if possible, 
      // but showing snackbar BEFORE pop is usually safer.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Записване...')),
        );
        Navigator.pop(context); 
      }
      
      print("Започва качване в албум...");
      final uuid = const Uuid().v4();
      final filePath = 'users/${user.uid}/animals/$uuid.jpg';
      
      // Опростяване на инициализацията - използваме стандартната инстанция
      final storageRef = FirebaseStorage.instance.ref().child(filePath);

      print("Път на съхранение: $filePath");

      UploadTask uploadTask = storageRef.putFile(imageFile);

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        if (mounted) {
          double progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
          print('Прогрес на качване в албум: ${progress.toStringAsFixed(1)}% (State: ${snapshot.state})');
        }
      }, onError: (e) {
        print("ГРЕШКА по време на стрийм на качване в албум: $e");
      });

      await uploadTask;
      final downloadUrl = await storageRef.getDownloadURL();
      print('Снимката е качена в албума! URL: $downloadUrl');

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('album')
          .add({
            'imageUrl': downloadUrl,
            'animalType': data.localName,
            'breed': data.breed,
            'timestamp': FieldValue.serverTimestamp(),
            'isRedBook': data.isRedBook,
            'description': data.description,
          });

      if (mounted) {
        _showSuccessSnackbar();
      }

    } catch (e) {
      print("ГРЕШКА при запис в албум: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Грешка при запис: $e')),
        );
      }
    }
  }

  void _showSuccessSnackbar() {
    if (!mounted) return;
    try {
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
    } catch (e) {
      debugPrint('Snackbar error: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      debugPrint('Snackbar error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview (Full Screen)
          if (_controller != null && _controller!.value.isInitialized)
            SizedBox.expand(
               child: CameraPreview(_controller!),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.green)),

          // Overlay Elements
          SafeArea(
            child: Stack(
              children: [
                 // Header (Zoodle AI) - Top Center
                 Align(
                   alignment: Alignment.topCenter,
                   child: Padding(
                     padding: const EdgeInsets.only(top: 16.0),
                     child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.greenAccent.withOpacity(0.5)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome, color: Colors.greenAccent, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Zoodle AI',
                              style: TextStyle(
                                color: Colors.white, 
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 1.2
                              ),
                            ),
                          ],
                        ),
                      ),
                   ),
                 ),

                // Controls
                Align(
                   alignment: Alignment.bottomCenter,
                   child: Padding(
                     padding: const EdgeInsets.only(bottom: 50),
                     child: GestureDetector(
                       onTap: _takePictureAndAnalyze,
                       child: Container(
                         width: 80,
                         height: 80,
                         decoration: BoxDecoration(
                           shape: BoxShape.circle,
                           border: Border.all(color: Colors.white, width: 4),
                           color: Colors.white24,
                           boxShadow: [
                             BoxShadow(
                               color: Colors.black26,
                               blurRadius: 10,
                               spreadRadius: 2,
                             )
                           ]
                         ),
                         child: Center(
                           child: Container(
                             width: 60,
                             height: 60,
                             decoration: const BoxDecoration(
                               shape: BoxShape.circle,
                               color: Colors.white,
                             ),
                             child: _isProcessing 
                               ? const Padding(
                                   padding: EdgeInsets.all(16.0),
                                   child: CircularProgressIndicator(color: Colors.green, strokeWidth: 2),
                                 )
                               : const Icon(Icons.camera_alt, color: Colors.white, size: 30),
                           ),
                         ),
                       ),
                     ),
                   ),
                ),
              ],
            ),
          ),
          
           // Full Screen Scanning Animation Overlay (On top of everything)
           if (_isScanning)
             Positioned.fill(
               child: IgnorePointer( // Allow clicks to pass through if needed, though usually we want to block
                 child: CustomPaint(
                   painter: ScanPainter(_animationController.value),
                 ),
               ),
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
    if (progress == 0) return;

    final paint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 3 // Thicker for visibility
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4); // Glow

    final scanY = size.height * progress;
    
    // Scan line
    canvas.drawLine(
      Offset(0, scanY),
      Offset(size.width, scanY),
      paint,
    );
    
    // Glow effect
    final glowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
           Colors.greenAccent.withOpacity(0.0),
           Colors.greenAccent.withOpacity(0.5),
        ],
      ).createShader(Rect.fromLTWH(0, scanY - 50, size.width, 50));
    
    canvas.drawRect(Rect.fromLTWH(0, scanY - 50, size.width, 50), glowPaint);
  }

  @override
  bool shouldRepaint(covariant ScanPainter oldDelegate) => oldDelegate.progress != progress;
}

class AnimalInfoSheet extends StatelessWidget {
  final File imageFile;
  final AnimalData animalData;
  final VoidCallback onSave;

  const AnimalInfoSheet({
    super.key, 
    required this.imageFile, 
    required this.animalData, 
    required this.onSave
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.file(
                  imageFile,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      animalData.localName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.green
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      animalData.breed,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500
                      ),
                    ),
                    if (animalData.isRedBook) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          border: Border.all(color: Colors.red),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                             Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16),
                             SizedBox(width: 4),
                             Text(
                               'Червена книга',
                               style: TextStyle(
                                 color: Colors.red,
                                 fontSize: 12,
                                 fontWeight: FontWeight.bold
                               ),
                             ),
                          ],
                        ),
                      ),
                    ]
                  ],
                ),
              )
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Interesting Fact
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: Colors.green[700], size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Знаете ли че?',
                      style: TextStyle(
                        color: Colors.green[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  animalData.description,
                  style: TextStyle(
                    color: Colors.green[900],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: 32),
          
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: Colors.green),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Отказ', style: TextStyle(color: Colors.green)),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onSave,
                  icon: Icon(Icons.save_alt, color: Colors.white),
                  label: Text('Запази в Албум', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.green,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
