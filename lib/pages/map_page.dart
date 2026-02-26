import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_storage/firebase_storage.dart';
<<<<<<< HEAD
import 'package:flutter/services.dart'
    show rootBundle, Clipboard, ClipboardData;
import 'package:intl/intl.dart';

import '../config/app_config.dart';
import '../main_scaffold.dart';
=======
import 'package:flutter/services.dart' show rootBundle, Clipboard, ClipboardData;
import 'package:intl/intl.dart';

>>>>>>> daf5cffc7dddbd691e91900be77907b2d13a96f9
import '../widgets/pulsing_report_button.dart';
import '../widgets/report_sheet.dart';
import '../widgets/animal_details_sheet.dart';
import 'chat_page.dart';

// Модел за данните на маркера
class MarkerData {
  final String id;
  final String type;
  final String status;
  final String description;
  final String imageUrl;
  final double latitude;
  final double longitude;
  final String reportedBy;
  final DateTime reportedAt;

  MarkerData({
    required this.id,
    required this.type,
    required this.status,
    required this.description,
    required this.imageUrl,
    required this.latitude,
    required this.longitude,
    required this.reportedBy,
    required this.reportedAt,
  });
}

// Основен екран на картата
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  MapboxMap? mapboxMap;
  CircleAnnotationManager? _myLocationManager;
  PointAnnotationManager? _dataMarkersManager;
  bool _isLoading = true;
  bool _mapCreated = false;
  bool _uiVisible = false;
  bool _legendVisible = false;
  User? _currentUser;
  String _userRole = 'user';
  Map<String, dynamic>? _userData;
<<<<<<< HEAD

=======
  
>>>>>>> daf5cffc7dddbd691e91900be77907b2d13a96f9
  // Данни за избрания маркер (за страничния панел)
  Map<String, dynamic>? _selectedMarkerData;
  String? _selectedMarkerDocId;

<<<<<<< HEAD
  final String _customStyleUri =
      "mapbox://styles/vikdev/cmgs0el6h00f101qx22dp3odf";
=======
  final String _customStyleUri = "mapbox://styles/vikdev/cmgs0el6h00f101qx22dp3odf";
>>>>>>> daf5cffc7dddbd691e91900be77907b2d13a96f9
  final Map<String, Map<String, dynamic>> _firestoreMarkerData = {};
  final Map<String, String> _annotationIdToDocId = {};

  geo.Position? _currentPosition;
  StreamSubscription<geo.Position>? _locationSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _markersSubscription;

<<<<<<< HEAD
  final Set<String> _allAnimalFilters = {
    'Ранено',
    'Болно',
    'Изгубено',
    'Опасно'
  };
=======
  final Set<String> _allAnimalFilters = {'Ранено', 'Болно', 'Изгубено', 'Опасно'};
>>>>>>> daf5cffc7dddbd691e91900be77907b2d13a96f9
  Set<String> _activeFilters = {'Ранено', 'Болно', 'Изгубено', 'Опасно'};
  bool _isMapInitialized = false;
  bool _managersReady = false;

  late AnimationController _legendAnimationController;
  late Animation<double> _legendFadeAnimation;
  late Animation<Offset> _legendSlideAnimation;

  Map<String, Uint8List> _markerImages = {};
  bool _markerImagesLoaded = false;

  @override
  void initState() {
    super.initState();
    _activeFilters = Set.from(_allAnimalFilters);
    _initializeAnimations();
    _loadMarkerImages().then((_) {
      _loadUserData();
    });
  }

  // Зареждане на изображения за маркерите
  Future<void> _loadMarkerImages() async {
    if (_markerImagesLoaded) return;
    try {
      _markerImages['Опасно'] = await _loadImage('assets/images/dangerous.png');
      _markerImages['Изгубено'] = await _loadImage('assets/images/lost.png');
      _markerImages['Болно'] = await _loadImage('assets/images/sick.png');
      _markerImages['Ранено'] = await _loadImage('assets/images/injured.png');
      _markerImagesLoaded = true;
      print("Маркерните снимки са заредени успешно");
    } catch (e) {
      print("Грешка при зареждане на маркерни снимки: $e");
    }
  }

  Future<Uint8List> _loadImage(String path) async {
    final byteData = await rootBundle.load(path);
    return byteData.buffer.asUint8List();
  }

  // Инициализация на анимации
  void _initializeAnimations() {
    _legendAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _legendFadeAnimation = CurvedAnimation(
      parent: _legendAnimationController,
      curve: Curves.easeInOut,
    );

    _legendSlideAnimation = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _legendAnimationController,
      curve: Curves.easeOutBack,
    ));
  }

  // Превключване на легендата
  void _toggleLegend() {
    setState(() {
      _legendVisible = !_legendVisible;
    });
    if (_legendVisible) {
      _legendAnimationController.forward();
    } else {
      _legendAnimationController.reverse();
    }
  }

  @override
  void dispose() {
    _legendAnimationController.dispose();
    _locationSubscription?.cancel();
    _markersSubscription?.cancel();
    _mapCreated = false;
    mapboxMap?.dispose();
    super.dispose();
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    this.mapboxMap = mapboxMap;
    _mapCreated = true;
    _activeFilters = Set.from(_allAnimalFilters);
    _initializeMap();
  }

  // Инициализация на картата
  void _initializeMap() async {
    if (!_mapCreated || mapboxMap == null || _isMapInitialized) return;
    _isMapInitialized = true;
    try {
      await _loadMarkerImages();
      print("Започва инициализация на картата...");
      await _setupMarkerManagers();
      await _initializeWithTimeout();
      _startLocationTracking();
      setState(() {
        _isLoading = false;
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) setState(() => _uiVisible = true);
        });
      });
      print("Mapbox картата е заредена успешно!");
      _loadMarkersFromFirestore();
    } catch (e) {
      print("Грешка при инициализация на картата: $e");
      _isMapInitialized = false;
      if (mounted) {
        setState(() => _isLoading = false);
        _showMessage('Грешка при зареждане на картата. Моля, опитайте отново.');
      }
    }
  }

  Future<void> _initializeWithTimeout() async {
    await Future.any([
      _performInitialization(),
<<<<<<< HEAD
      Future.delayed(
          const Duration(seconds: 15),
          () =>
              throw TimeoutException('Инициализацията отне твърде много време'))
=======
      Future.delayed(const Duration(seconds: 15),
          () => throw TimeoutException('Инициализацията отне твърде много време'))
>>>>>>> daf5cffc7dddbd691e91900be77907b2d13a96f9
    ]);
  }

  Future<void> _performInitialization() async {
    try {
      if (_mapCreated && mapboxMap != null) {
        await mapboxMap!.style.setStyleURI(_customStyleUri);
        print("Стилът е зареден успешно!");
      }
      await _goToMyLocation();
    } catch (e) {
      print("Грешка в _performInitialization: $e");
      if (e.toString().contains('style') || e.toString().contains('404')) {
        await _fallbackToStandardStyle();
      } else {
        rethrow;
      }
    }
  }

  Future<void> _fallbackToStandardStyle() async {
    try {
      if (_mapCreated && mapboxMap != null) {
<<<<<<< HEAD
        await mapboxMap!.style
            .setStyleURI("mapbox://styles/vikdev/cmgs0el6h00f101qx22dp3odf");
=======
        await mapboxMap!.style.setStyleURI("mapbox://styles/vikdev/cmgs0el6h00f101qx22dp3odf");
>>>>>>> daf5cffc7dddbd691e91900be77907b2d13a96f9
        await _goToMyLocation();
      }
    } catch (e) {
      print("Грешка и със стандартния стил: $e");
      rethrow;
    }
  }

  // Зареждане на потребителски данни
  Future<void> _loadUserData() async {
    _currentUser = FirebaseAuth.instance.currentUser;
    if (mounted) {
      setState(() {
        _activeFilters = Set.from(_allAnimalFilters);
      });
    }
    if (_currentUser != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid)
            .get();
        if (mounted) {
          setState(() {
            _userData = userDoc.data() as Map<String, dynamic>?;
            _userRole = _userData?['role'] ?? 'user';
            print("Потребителски данни заредени: $_userRole");
            print("Всички филтри са активни по подразбиране: $_activeFilters");
          });
        }
      } catch (e) {
        print("Грешка при зареждане на потребителски данни: $e");
      }
    }
  }

  // Стартиране на проследяване на локацията
  void _startLocationTracking() {
    _locationSubscription?.cancel();

    _locationSubscription = geo.Geolocator.getPositionStream(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.best,
        distanceFilter: 5,
      ),
    ).listen((geo.Position position) {
      if (mounted && _mapCreated) {
        setState(() {
          _currentPosition = position;
        });
        _updateMyLocationMarker(position.latitude, position.longitude);
      }
    });
  }

  // Настройка на мениджъри за маркери
  Future<void> _setupMarkerManagers() async {
    if (mapboxMap == null) return;
    if (_managersReady &&
        _myLocationManager != null &&
        _dataMarkersManager != null) {
      return;
    }
<<<<<<< HEAD
    _myLocationManager =
        await mapboxMap!.annotations.createCircleAnnotationManager();
    _dataMarkersManager =
        await mapboxMap!.annotations.createPointAnnotationManager();

    _dataMarkersManager?.addOnPointAnnotationClickListener(
        MyPointAnnotationClickListener(_handleMarkerClick));
=======
    _myLocationManager = await mapboxMap!.annotations.createCircleAnnotationManager();
    _dataMarkersManager = await mapboxMap!.annotations.createPointAnnotationManager();

    _dataMarkersManager?.addOnPointAnnotationClickListener(
      MyPointAnnotationClickListener(_handleMarkerClick)
    );
>>>>>>> daf5cffc7dddbd691e91900be77907b2d13a96f9
    _managersReady = true;
  }

  // Обработка на кликване върху маркер
  void _handleMarkerClick(PointAnnotation annotation) {
    print("Натиснат е маркер с ID: ${annotation.id}");
    try {
      final docId = _annotationIdToDocId[annotation.id];
<<<<<<< HEAD

=======
      
>>>>>>> daf5cffc7dddbd691e91900be77907b2d13a96f9
      if (docId != null) {
        final data = _firestoreMarkerData[docId];
        if (data != null) {
          print("Намерен маркер: $docId - ${data['status']}");
          _updateMarkerSelection(docId, data);
        } else {
          print("Няма данни за docId: $docId");
        }
      } else {
        print("Маркерът не е намерен в mapping: ${annotation.id}");
      }
    } catch (e) {
      print("Грешка при обработка на кликване: $e");
    }
  }

  // Зареждане на маркери от Firestore
  void _loadMarkersFromFirestore() {
    if (_dataMarkersManager == null) return;

<<<<<<< HEAD
    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection('animal_reports');
=======
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('animal_reports');
>>>>>>> daf5cffc7dddbd691e91900be77907b2d13a96f9

    if (_activeFilters.isNotEmpty) {
      query = query.where('status', whereIn: _activeFilters.toList());
    }

    _markersSubscription?.cancel();
    _markersSubscription = query.snapshots().listen((snapshot) async {
      if (!mounted) return;

      await _dataMarkersManager?.deleteAll();
      _firestoreMarkerData.clear();
      _annotationIdToDocId.clear();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final location = data['location'] as GeoPoint?;
        if (location == null) continue;
<<<<<<< HEAD

        String docId = doc.id;
        _firestoreMarkerData[docId] = data;

        final options =
            _getMarkerOptions(data, location.latitude, location.longitude);
        final annotation = await _dataMarkersManager?.create(options);

        if (annotation != null) {
          _annotationIdToDocId[annotation.id] = docId;
          print(
              "Създаден маркер: annotationId=${annotation.id} -> docId=$docId (${data['status']})");
        }
      }

=======
        
        String docId = doc.id;
        _firestoreMarkerData[docId] = data;
        
        final options = _getMarkerOptions(data, location.latitude, location.longitude);
        final annotation = await _dataMarkersManager?.create(options);
        
        if (annotation != null) {
          _annotationIdToDocId[annotation.id] = docId;
          print("Създаден маркер: annotationId=${annotation.id} -> docId=$docId (${data['status']})");
        }
      }
      
>>>>>>> daf5cffc7dddbd691e91900be77907b2d13a96f9
      print("Заредени ${_firestoreMarkerData.length} маркера от Firestore");
      print("Annotation mapping size: ${_annotationIdToDocId.length}");
    }, onError: (error) {
      print("Грешка при зареждане на маркери: $error");
    });
  }

  // Създаване на опции за маркер
  PointAnnotationOptions _getMarkerOptions(
      Map<String, dynamic> data, double lat, double lng) {
    String status = data['status'] ?? 'Опасно';
<<<<<<< HEAD

=======
    
>>>>>>> daf5cffc7dddbd691e91900be77907b2d13a96f9
    return PointAnnotationOptions(
      geometry: Point(coordinates: Position(lng.toDouble(), lat.toDouble())),
      image: _markerImages[status],
      iconSize: 0.5,
      iconAnchor: IconAnchor.BOTTOM,
    );
  }

  // Добавяне на нов доклад
  void _addReportedMarker(String status, String description, File? imageFile,
      double lat, double lng) async {
    if (_currentUser == null) {
      _showMessage("Моля, влезте в профила си първо!");
      return;
    }

    setState(() {
      _isLoading = true;
    });

<<<<<<< HEAD
    String imageUrl =
        "https://placehold.co/600x400/666666/FFFFFF?text=Няма+Снимка";

    if (imageFile != null) {
      try {
        print(
            "Започва качване на снимка... Баскет: zoodle-be9c3.firebasestorage.app");

        String fileName =
            'reports/${_currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';

=======
    String imageUrl = "https://placehold.co/600x400/666666/FFFFFF?text=Няма+Снимка";

    if (imageFile != null) {
      try {
        print("Започва качване на снимка... Баскет: zoodle-be9c3.firebasestorage.app");

        String fileName = 'reports/${_currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        
>>>>>>> daf5cffc7dddbd691e91900be77907b2d13a96f9
        // Опростяване на инициализацията - използваме стандартната инстанция
        Reference storageRef = FirebaseStorage.instance.ref().child(fileName);

        print("Път на съхранение: $fileName");

        UploadTask uploadTask = storageRef.putFile(imageFile);

        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          if (mounted) {
<<<<<<< HEAD
            double progress =
                (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
            print(
                'Прогрес на качване: ${progress.toStringAsFixed(1)}% (State: ${snapshot.state})');
=======
            double progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
            print('Прогрес на качване: ${progress.toStringAsFixed(1)}% (State: ${snapshot.state})');
>>>>>>> daf5cffc7dddbd691e91900be77907b2d13a96f9
          }
        }, onError: (e) {
          print("ГРЕШКА по време на стрийм на качване: $e");
        });

        TaskSnapshot snapshot = await uploadTask;
        imageUrl = await snapshot.ref.getDownloadURL();
        print('Снимката е качена успешно! URL: $imageUrl');
<<<<<<< HEAD
=======

>>>>>>> daf5cffc7dddbd691e91900be77907b2d13a96f9
      } catch (e) {
        print("ГРЕШКА при качване на снимка: $e");
        if (mounted) {
          _showMessage("Грешка при качване на снимка: ${e.toString()}");
          setState(() => _isLoading = false);
        }
        return;
      }
    }

    try {
<<<<<<< HEAD
      DocumentReference docRef =
          await FirebaseFirestore.instance.collection('animal_reports').add({
        'reporterId': _currentUser!.uid,
        'userId': _currentUser!.uid,
=======
      DocumentReference docRef = await FirebaseFirestore.instance
          .collection('animal_reports')
          .add({
        'reporterId': _currentUser!.uid,
>>>>>>> daf5cffc7dddbd691e91900be77907b2d13a96f9
        'reporterName': _userData?['username'] ?? 'Анонимен',
        'status': status,
        'description': description,
        'imageUrl': imageUrl,
        'location': GeoPoint(lat, lng),
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'animal',
      });

      print('Документът е записан във Firestore с ID: ${docRef.id}');

<<<<<<< HEAD
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid);
=======
      final userRef = FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid);
>>>>>>> daf5cffc7dddbd691e91900be77907b2d13a96f9
      await userRef.update({'reportsCount': FieldValue.increment(1)});

      if (mounted) {
        _loadMarkersFromFirestore();
        _showMessage("Сигналът е изпратен успешно!");
      }
    } catch (e) {
      print("ГРЕШКА при запис във Firestore: $e");
      if (mounted) {
        _showMessage("Грешка при изпращане на сигнала: ${e.toString()}");
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Навигиране до текущата локация
  Future<void> _goToMyLocation() async {
    try {
<<<<<<< HEAD
      geo.LocationPermission permission =
          await geo.Geolocator.checkPermission();
=======
      geo.LocationPermission permission = await geo.Geolocator.checkPermission();
>>>>>>> daf5cffc7dddbd691e91900be77907b2d13a96f9
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }
      if (permission == geo.LocationPermission.denied ||
          permission == geo.LocationPermission.deniedForever) {
        _goToDefaultLocation();
        return;
      }

      geo.Position position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      ).timeout(const Duration(seconds: 15));

      setState(() {
        _currentPosition = position;
      });

      if (_mapCreated && mapboxMap != null) {
        mapboxMap!.flyTo(
          CameraOptions(
<<<<<<< HEAD
            center: Point(
                coordinates: Position(position.longitude.toDouble(),
                    position.latitude.toDouble())),
=======
            center: Point(coordinates: Position(position.longitude.toDouble(), position.latitude.toDouble())),
>>>>>>> daf5cffc7dddbd691e91900be77907b2d13a96f9
            zoom: 14.0,
          ),
          MapAnimationOptions(duration: 1500),
        );
        _addMyLocationMarker(position.latitude, position.longitude);
      }
<<<<<<< HEAD
=======

>>>>>>> daf5cffc7dddbd691e91900be77907b2d13a96f9
    } catch (e) {
      print("Грешка при вземане на локация: $e");
      _goToDefaultLocation();
    }
  }

  void _goToDefaultLocation() {
    if (!_mapCreated || mapboxMap == null) return;
    mapboxMap?.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(23.3219, 42.6977)),
        zoom: 12.0,
      ),
      MapAnimationOptions(duration: 1500),
    );
  }

  // Добавяне на маркер за текущата локация
  void _addMyLocationMarker(double lat, double lng) {
    _myLocationManager?.deleteAll();
    final options = CircleAnnotationOptions(
      geometry: Point(coordinates: Position(lng.toDouble(), lat.toDouble())),
      circleColor: const Color.fromARGB(255, 255, 61, 200).value,
      circleRadius: 10.0,
      circleStrokeColor: Colors.white.value,
      circleStrokeWidth: 3.0,
      circleBlur: 0.0,
    );
    _myLocationManager?.create(options);
  }

  void _updateMyLocationMarker(double lat, double lng) {
    _myLocationManager?.deleteAll();
    final options = CircleAnnotationOptions(
      geometry: Point(coordinates: Position(lng.toDouble(), lat.toDouble())),
      circleColor: const Color.fromARGB(255, 255, 61, 200).value,
      circleRadius: 8.0,
      circleStrokeColor: Colors.white.value,
      circleStrokeWidth: 2.0,
    );
    _myLocationManager?.create(options);
  }

  void _showMessage(String message) {
    if (!mounted) return;
<<<<<<< HEAD

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
=======
    
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message), 
>>>>>>> daf5cffc7dddbd691e91900be77907b2d13a96f9
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Показване на панел за докладване
  void _showReportPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
<<<<<<< HEAD
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
=======
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
>>>>>>> daf5cffc7dddbd691e91900be77907b2d13a96f9
          child: ReportAnimalSheet(
            onSubmit: (status, description, imageFile) {
              Navigator.pop(context);
              if (_currentPosition != null) {
                _addReportedMarker(
                  status,
                  description,
                  imageFile,
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                );
              } else {
<<<<<<< HEAD
                _showMessage(
                    "Текущата локация е неизвестна. Моля, активирайте GPS.");
=======
                _showMessage("Текущата локация е неизвестна. Моля, активирайте GPS.");
>>>>>>> daf5cffc7dddbd691e91900be77907b2d13a96f9
              }
            },
          ),
        );
      },
    );
  }

  // Показване на панел с филтри
  void _showFilterPanel() {
    Set<String> tempFilters = Set.from(_activeFilters);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: scheme.surface,
<<<<<<< HEAD
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
=======
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
>>>>>>> daf5cffc7dddbd691e91900be77907b2d13a96f9
              ),
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
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
                    'Филтри за сигнали',
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Покажи само типовете, които те интересуват.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _allAnimalFilters.map((status) {
                      final isSelected = tempFilters.contains(status);
                      return FilterChip(
                        label: Text(status),
                        selected: isSelected,
                        onSelected: (selected) {
                          setModalState(() {
                            if (selected) {
                              tempFilters.add(status);
                            } else {
                              tempFilters.remove(status);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _activeFilters = Set.from(tempFilters);
                        });
                        _loadMarkersFromFirestore();
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.done_all_rounded),
                      label: const Text('Приложи филтрите'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Показване на информация за маркер
  void _updateMarkerSelection(String docId, Map<String, dynamic> data) {
    setState(() {
      _selectedMarkerDocId = docId;
      _selectedMarkerData = data;
    });
  }

  void _clearMarkerSelection() {
    setState(() {
      _selectedMarkerDocId = null;
      _selectedMarkerData = null;
    });
  }

  // Премахване на маркер
  void _removeMarker(BuildContext context, String docId) async {
    try {
      final data = _firestoreMarkerData[docId];
      if (data == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Грешка: Данните за маркера не са намерени.'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      final reporterId = data['reporterId'] ?? '';
<<<<<<< HEAD
      final canDelete =
          _userRole == 'zoologist' || reporterId == _currentUser?.uid;

=======
      final canDelete = _userRole == 'zoologist' || reporterId == _currentUser?.uid;
      
>>>>>>> daf5cffc7dddbd691e91900be77907b2d13a96f9
      if (!canDelete) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Нямате права да премахнете този сигнал.'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      print("Опит за изтриване на документ: $docId");
<<<<<<< HEAD

=======
      
>>>>>>> daf5cffc7dddbd691e91900be77907b2d13a96f9
      await FirebaseFirestore.instance
          .collection('animal_reports')
          .doc(docId)
          .delete();

      print("Документът е изтрит успешно: $docId");
<<<<<<< HEAD

      _loadMarkersFromFirestore();

=======
      
      _loadMarkersFromFirestore();
      
>>>>>>> daf5cffc7dddbd691e91900be77907b2d13a96f9
      if (context.mounted) {
        _clearMarkerSelection();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Сигналът е премахнат успешно.'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
<<<<<<< HEAD
    } catch (e) {
      print("Грешка при изтриване: $e");

=======
      
    } catch (e) {
      print("Грешка при изтриване: $e");
      
>>>>>>> daf5cffc7dddbd691e91900be77907b2d13a96f9
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Грешка при премахване на сигнала: ${e.toString()}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
<<<<<<< HEAD

=======
      
>>>>>>> daf5cffc7dddbd691e91900be77907b2d13a96f9
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
  }

  // Навигиране към чат
  void _navigateToChat(String reporterId, String reporterName) async {
<<<<<<< HEAD
    final cleanReporterId = reporterId.trim();
    if (_currentUser == null || cleanReporterId.isEmpty) return;

    String myId = _currentUser!.uid;
    String myName = (_userData?['username'] ?? 'Потребител').toString();
    final cleanReporterName = reporterName.trim().isEmpty
        ? 'Потребител'
        : reporterName.trim();

    if (myId == cleanReporterId) {
=======
    if (_currentUser == null || reporterId.isEmpty) return;

    String myId = _currentUser!.uid;
    String myName = _userData?['username'] ?? 'Потребител';

    if (myId == reporterId) {
>>>>>>> daf5cffc7dddbd691e91900be77907b2d13a96f9
      _showMessage("Не можете да започнете чат със себе си.");
      return;
    }

<<<<<<< HEAD
    String chatId = myId.compareTo(cleanReporterId) > 0
        ? '${myId}_$cleanReporterId'
        : '${cleanReporterId}_$myId';

    try {
      final myRole = _userRole.isNotEmpty ? _userRole : 'user';
      final reporterRole = 'user';

      await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
        'members': [myId, cleanReporterId],
        'memberNames': {myId: myName, cleanReporterId: cleanReporterName},
        'memberRoles': {myId: myRole, cleanReporterId: reporterRole},
=======
    String chatId = myId.compareTo(reporterId) > 0 ? '${myId}_$reporterId' : '${reporterId}_$myId';

    try {
      // Вземане на ролите на двамата потребители
      final myDoc = await FirebaseFirestore.instance.collection('users').doc(myId).get();
      final reporterDoc = await FirebaseFirestore.instance.collection('users').doc(reporterId).get();
      
      final myRole = myDoc.data()?['role'] ?? 'user';
      final reporterRole = reporterDoc.data()?['role'] ?? 'user';

      await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
        'members': [myId, reporterId],
        'memberNames': {myId: myName, reporterId: reporterName},
        'memberRoles': {myId: myRole, reporterId: reporterRole},
>>>>>>> daf5cffc7dddbd691e91900be77907b2d13a96f9
        'lastMessage': '',
        'lastMessageTimestamp': Timestamp.now(),
        'createdAt': Timestamp.now(),
      }, SetOptions(merge: true));

      print("Чат създаден успешно: $chatId (без автоматично съобщение)");

      if (!mounted) return;
<<<<<<< HEAD

      _clearMarkerSelection();

=======
      
      _clearMarkerSelection();
      
>>>>>>> daf5cffc7dddbd691e91900be77907b2d13a96f9
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatDetailPage(
            channel: ChatChannel(
              id: chatId,
<<<<<<< HEAD
              name: cleanReporterName,
=======
              name: reporterName,
>>>>>>> daf5cffc7dddbd691e91900be77907b2d13a96f9
              members: 2,
              lastMessage: '',
              time: DateFormat('HH:mm').format(DateTime.now()),
              unread: 0,
              isOnline: true,
<<<<<<< HEAD
              otherUserId: cleanReporterId,
              otherUserName: cleanReporterName,
=======
              otherUserId: reporterId,
              otherUserName: reporterName,
>>>>>>> daf5cffc7dddbd691e91900be77907b2d13a96f9
            ),
            collectionPath: 'chats',
          ),
        ),
      );
    } catch (e) {
      print("Грешка при създаване на чат: $e");
<<<<<<< HEAD
      _showMessage(
          "Неуспешно стартиране на чат. Моля, проверете правилата за достъп.");
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const MainScaffold(initialIndex: 1),
          ),
        );
      }
=======
      _showMessage("Неуспешно стартиране на чат. Моля, проверете правилата за достъп.");
>>>>>>> daf5cffc7dddbd691e91900be77907b2d13a96f9
    }
  }

  // Стартиране на навигация
<<<<<<< HEAD
  void _launchNavigation(
      BuildContext context, double latitude, double longitude) async {
    try {
      final coordinates = '$latitude,$longitude';
      await Clipboard.setData(ClipboardData(text: coordinates));

=======
  void _launchNavigation(BuildContext context, double latitude, double longitude) async {
    try {
      final coordinates = '$latitude,$longitude';
      await Clipboard.setData(ClipboardData(text: coordinates));
      
>>>>>>> daf5cffc7dddbd691e91900be77907b2d13a96f9
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Координатите са копирани: $coordinates'),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {},
            ),
          ),
        );
      }

      Uri uri;
      if (Platform.isAndroid) {
<<<<<<< HEAD
        uri = Uri.parse(
            'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=driving&dir_action=navigate');
      } else if (Platform.isIOS) {
        uri = Uri.parse(
            'https://maps.apple.com/?daddr=$latitude,$longitude&dirflg=d&t=m');
      } else {
        uri = Uri.parse(
            'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=driving');
=======
        uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=driving&dir_action=navigate');
      } else if (Platform.isIOS) {
        uri = Uri.parse('https://maps.apple.com/?daddr=$latitude,$longitude&dirflg=d&t=m');
      } else {
        uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=driving');
>>>>>>> daf5cffc7dddbd691e91900be77907b2d13a96f9
      }

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }

<<<<<<< HEAD
      Uri fallbackUri = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude');
=======
      Uri fallbackUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude');
>>>>>>> daf5cffc7dddbd691e91900be77907b2d13a96f9
      if (await canLaunchUrl(fallbackUri)) {
        await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
        return;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
<<<<<<< HEAD
            content: Text(
                'Неуспешно стартиране на навигация. Координатите са копирани: $coordinates'),
=======
            content: Text('Неуспешно стартиране на навигация. Координатите са копирани: $coordinates'),
>>>>>>> daf5cffc7dddbd691e91900be77907b2d13a96f9
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      print("Грешка при навигация: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
<<<<<<< HEAD
            content:
                Text('Грешка при стартиране на навигацията: ${e.toString()}'),
=======
            content: Text('Грешка при стартиране на навигацията: ${e.toString()}'),
>>>>>>> daf5cffc7dddbd691e91900be77907b2d13a96f9
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // Стартиране на обаждане
  void _launchCall() async {
    final Uri uri = Uri.parse('tel:112');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showMessage('Не може да се извърши обаждане.');
    }
  }

  // Промяна на стила на картата
  void _changeMapStyle(String styleUri) async {
    try {
      if (_mapCreated && mapboxMap != null) {
        await mapboxMap!.style.setStyleURI(styleUri);
        _loadMarkersFromFirestore();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Стилът на картата е променен')),
        );
      }
    } catch (e) {
      print("Грешка при смяна на стил: $e");
    }
  }

  void _showStyleSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: const Text('Изберете стил на картата'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.map, color: scheme.primary),
                title: const Text('Стандартен'),
                onTap: () {
<<<<<<< HEAD
                  _changeMapStyle(
                      "mapbox://styles/vikdev/cmgs0el6h00f101qx22dp3odf");
=======
                  _changeMapStyle("mapbox://styles/vikdev/cmgs0el6h00f101qx22dp3odf");
>>>>>>> daf5cffc7dddbd691e91900be77907b2d13a96f9
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.satellite, color: scheme.primary),
                title: const Text('Сателитен'),
                onTap: () {
                  _changeMapStyle(MapboxStyles.SATELLITE);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.dark_mode, color: scheme.primary),
                title: const Text('Тъмен'),
                onTap: () {
                  _changeMapStyle(MapboxStyles.DARK);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Изграждане на елемент от легендата
  Widget _buildLegendItem(Color color, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: scheme.surface, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              color: scheme.onInverseSurface,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Бутон за меню на картата
  PopupMenuEntry<String> _buildMapMenuItem({
    required String value,
    required IconData icon,
    required String title,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: scheme.primary),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapMenuButton() {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      tooltip: 'Опции на картата',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: scheme.surface,
      elevation: 8,
      position: PopupMenuPosition.under,
      icon: Icon(Icons.more_vert, color: scheme.primary),
      onSelected: (value) {
        switch (value) {
          case 'filter':
            _showFilterPanel();
            break;
          case 'location':
            _goToMyLocation();
            break;
          case 'call':
            _launchCall();
            break;
          case 'legend':
            _toggleLegend();
            break;
          case 'style':
            _showStyleSelectionDialog();
            break;
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        _buildMapMenuItem(
          value: 'filter',
          icon: Icons.filter_list_rounded,
          title: 'Филтри',
        ),
        _buildMapMenuItem(
          value: 'location',
          icon: Icons.my_location_rounded,
          title: 'Моята локация',
        ),
        _buildMapMenuItem(
          value: 'legend',
          icon: Icons.legend_toggle_rounded,
          title: 'Легенда',
        ),
        _buildMapMenuItem(
          value: 'style',
          icon: Icons.style,
          title: 'Смени стил',
        ),
        _buildMapMenuItem(
          value: 'call',
          icon: Icons.call,
          title: 'Спешен номер',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
<<<<<<< HEAD
    if (!AppConfig.hasMapboxToken) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Карта и сигнали'),
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.map_outlined, size: 52, color: scheme.primary),
                const SizedBox(height: 12),
                Text(
                  'Картата не е активна.',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Добави MAPBOX_ACCESS_TOKEN в .env и пусни приложението отново.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }
=======
>>>>>>> daf5cffc7dddbd691e91900be77907b2d13a96f9
    return Scaffold(
      appBar: AppBar(
        title: const Text("Карта и сигнали"),
        elevation: 0,
        actions: [
          _buildMapMenuButton(),
        ],
      ),
      body: Stack(
        children: [
          MapWidget(
            key: const ValueKey("mapWidget"),
            mapOptions: MapOptions(
              contextMode: ContextMode.UNIQUE,
              pixelRatio: MediaQuery.of(context).devicePixelRatio,
            ),
            cameraOptions: CameraOptions(
              zoom: 10.0,
              center: Point(coordinates: Position(23.3219, 42.6977)),
            ),
            styleUri: _customStyleUri,
            onMapCreated: _onMapCreated,
          ),
          if (_isLoading)
            Container(
              color: scheme.surface.withOpacity(0.88),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: scheme.primary),
                    const SizedBox(height: 20),
                    Text(
                      'Зареждане на картата...',
<<<<<<< HEAD
                      style: TextStyle(
                          fontSize: 16, color: scheme.onSurfaceVariant),
=======
                      style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant),
>>>>>>> daf5cffc7dddbd691e91900be77907b2d13a96f9
                    ),
                  ],
                ),
              ),
            ),
          /* Positioned(
            top: 30,
            left: 10,
            child: _buildMapMenuButton(),
          ), */
          _buildBottomUI(),
          _buildLegend(),
<<<<<<< HEAD

=======
          
>>>>>>> daf5cffc7dddbd691e91900be77907b2d13a96f9
          // Панел с информация (страничен)
          if (_selectedMarkerData != null && _selectedMarkerDocId != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              right: 16,
              bottom: 120, // Оставяме място за долния UI
              child: SingleChildScrollView(
                child: AnimalDetailsSheet(
                  data: _selectedMarkerData!,
                  isRescueTeam: _userRole == 'zoologist',
                  onNavigate: () {
                    GeoPoint location = _selectedMarkerData!['location'];
<<<<<<< HEAD
                    _launchNavigation(
                        context, location.latitude, location.longitude);
=======
                    _launchNavigation(context, location.latitude, location.longitude);
>>>>>>> daf5cffc7dddbd691e91900be77907b2d13a96f9
                  },
                  onRemove: () {
                    final docId = _selectedMarkerDocId!;
                    _clearMarkerSelection();
                    _removeMarker(context, docId);
                  },
<<<<<<< HEAD
                  canDelete: _userRole == 'zoologist' ||
                      ((_selectedMarkerData!['reporterId'] ??
                                  _selectedMarkerData!['userId'] ??
                                  '')
                              .toString() ==
                          _currentUser?.uid),
                  showChatButton: ((_selectedMarkerData!['reporterId'] ??
                                  _selectedMarkerData!['userId'] ??
                                  '')
                              .toString()
                              .isNotEmpty) &&
                      ((_selectedMarkerData!['reporterId'] ??
                                  _selectedMarkerData!['userId'] ??
                                  '')
                              .toString() !=
                          _currentUser?.uid),
                  onChat: () {
                    final reporterId = (_selectedMarkerData!['reporterId'] ??
                            _selectedMarkerData!['userId'] ??
                            '')
                        .toString();
                    final reporterName =
                        (_selectedMarkerData!['reporterName'] ??
                                _selectedMarkerData!['username'] ??
                                'Неизвестен')
                            .toString();
                    if (reporterId.isEmpty) {
                      _showMessage('Липсва идентификатор на подателя.');
                      return;
                    }
=======
                  canDelete: _userRole == 'zoologist' || 
                            (_selectedMarkerData!['reporterId'] == _currentUser?.uid),
                  showChatButton: _selectedMarkerData!['reporterId'] != _currentUser?.uid && 
                                 (_selectedMarkerData!['reporterId'] ?? '').isNotEmpty,
                  onChat: () {
                    final reporterId = _selectedMarkerData!['reporterId'];
                    final reporterName = _selectedMarkerData!['reporterName'] ?? 'Неизвестен';
>>>>>>> daf5cffc7dddbd691e91900be77907b2d13a96f9
                    _clearMarkerSelection();
                    _navigateToChat(reporterId, reporterName);
                  },
                  onClose: _clearMarkerSelection,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Долен UI с бутон за докладване
  Widget _buildBottomUI() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      bottom: 30,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        opacity: _uiVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 500),
        child: Center(
          child: PulsingReportButton(onPressed: _showReportPanel),
        ),
      ),
    );
  }

  // Легенда за типовете маркери
  Widget _buildLegend() {
    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      right: 20,
      top: 80,
      child: SlideTransition(
        position: _legendSlideAnimation,
        child: FadeTransition(
          opacity: _legendFadeAnimation,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.inverseSurface.withOpacity(0.92),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Легенда',
                  style: TextStyle(
                    color: scheme.onInverseSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildLegendItem(Colors.red, 'Опасно'),
                _buildLegendItem(Colors.blue, 'Изгубено'),
                _buildLegendItem(Colors.yellow, 'Болно'),
                _buildLegendItem(Colors.orange, 'Ранено'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => message;
}

// Listener за кликване върху маркери
class MyPointAnnotationClickListener implements OnPointAnnotationClickListener {
  final void Function(PointAnnotation) _onTap;

  MyPointAnnotationClickListener(this._onTap);

  @override
  void onPointAnnotationClick(PointAnnotation annotation) {
    _onTap(annotation);
  }
}
