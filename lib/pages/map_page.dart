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
import 'package:flutter/services.dart' show rootBundle, Clipboard, ClipboardData;
import 'package:intl/intl.dart';

import '../widgets/pulsing_report_button.dart';
import '../widgets/report_sheet.dart';
import '../widgets/marker_info_sheet.dart';
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

  final String _customStyleUri = "mapbox://styles/vikdev/cmgs0el6h00f101qx22dp3odf";
  final Map<String, Map<String, dynamic>> _firestoreMarkerData = {};
  final Map<String, String> _annotationIdToDocId = {};

  geo.Position? _currentPosition;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _markersSubscription;

  final Set<String> _allAnimalFilters = {'Ранено', 'Болно', 'Изгубено', 'Опасно'};
  Set<String> _activeFilters = {'Ранено', 'Болно', 'Изгубено', 'Опасно'};

  late AnimationController _legendAnimationController;
  late Animation<double> _legendFadeAnimation;
  late Animation<Offset> _legendSlideAnimation;

  Map<String, Uint8List> _markerImages = {};

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadMarkerImages().then((_) {
      _loadUserData().then((_) {
        _initializeMap();
      });
    });
  }

  // Зареждане на изображения за маркерите
  Future<void> _loadMarkerImages() async {
    try {
      _markerImages['Опасно'] = await _loadImage('assets/images/dangerous.png');
      _markerImages['Изгубено'] = await _loadImage('assets/images/lost.png');
      _markerImages['Болно'] = await _loadImage('assets/images/sick.png');
      _markerImages['Ранено'] = await _loadImage('assets/images/injured.png');
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
    _markersSubscription?.cancel();
    _mapCreated = false;
    mapboxMap?.dispose();
    super.dispose();
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    this.mapboxMap = mapboxMap;
    _mapCreated = true;
    _initializeMap();
  }

  // Инициализация на картата
  void _initializeMap() async {
    try {
      print("Започва инициализация на картата...");
      await _initializeWithTimeout();
      _startLocationTracking();
      setState(() {
        _isLoading = false;
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) setState(() => _uiVisible = true);
        });
      });
      print("Mapbox картата е заредена успешно!");
      _setupMarkerManagers();
      _loadMarkersFromFirestore();
    } catch (e) {
      print("Грешка при инициализация на картата: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        _showMessage('Грешка при зареждане на картата. Моля, опитайте отново.');
      }
    }
  }

  Future<void> _initializeWithTimeout() async {
    await Future.any([
      _performInitialization(),
      Future.delayed(const Duration(seconds: 15),
          () => throw TimeoutException('Инициализацията отне твърде много време'))
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
        await mapboxMap!.style.setStyleURI("mapbox://styles/vikdev/cmgs0el6h00f101qx22dp3odf");
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
            _activeFilters = Set.from(_allAnimalFilters);
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
    _markersSubscription?.cancel();

    geo.Geolocator.getPositionStream(
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
  void _setupMarkerManagers() async {
    if (mapboxMap == null) return;
    _myLocationManager = await mapboxMap!.annotations.createCircleAnnotationManager();
    _dataMarkersManager = await mapboxMap!.annotations.createPointAnnotationManager();

    _dataMarkersManager?.addOnPointAnnotationClickListener(
      MyPointAnnotationClickListener(_handleMarkerClick)
    );
  }

  // Обработка на кликване върху маркер
  void _handleMarkerClick(PointAnnotation annotation) {
    print("Натиснат е маркер с ID: ${annotation.id}");
    try {
      final docId = _annotationIdToDocId[annotation.id];
      
      if (docId != null) {
        final data = _firestoreMarkerData[docId];
        if (data != null) {
          print("Намерен маркер: $docId - ${data['status']}");
          _showMarkerInfoPanel(docId, data);
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

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('animal_reports');

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
        
        String docId = doc.id;
        _firestoreMarkerData[docId] = data;
        
        final options = _getMarkerOptions(data, location.latitude, location.longitude);
        final annotation = await _dataMarkersManager?.create(options);
        
        if (annotation != null) {
          _annotationIdToDocId[annotation.id] = docId;
          print("Създаден маркер: annotationId=${annotation.id} -> docId=$docId (${data['status']})");
        }
      }
      
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

    String imageUrl = "https://placehold.co/600x400/666666/FFFFFF?text=Няма+Снимка";

    if (imageFile != null) {
      try {
        print("Започва качване на снимка...");

        String fileName = 'reports/${_currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        Reference storageRef = FirebaseStorage.instance.ref().child(fileName);

        UploadTask uploadTask = storageRef.putFile(imageFile);

        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          double progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
          print('Прогрес на качване: ${progress.toStringAsFixed(1)}%');
        });

        TaskSnapshot snapshot = await uploadTask;
        imageUrl = await snapshot.ref.getDownloadURL();
        print('Снимката е качена успешно! URL: $imageUrl');

      } catch (e) {
        print("ГРЕШКА при качване на снимка: $e");
        _showMessage("Грешка при качване на снимка: ${e.toString()}");
        setState(() => _isLoading = false);
        return;
      }
    }

    try {
      DocumentReference docRef = await FirebaseFirestore.instance
          .collection('animal_reports')
          .add({
        'reporterId': _currentUser!.uid,
        'reporterName': _userData?['username'] ?? 'Анонимен',
        'status': status,
        'description': description,
        'imageUrl': imageUrl,
        'location': GeoPoint(lat, lng),
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'animal',
      });

      print('Документът е записан във Firestore с ID: ${docRef.id}');

      final userRef = FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid);
      await userRef.update({'reportsCount': FieldValue.increment(1)});

      _loadMarkersFromFirestore();

      _showMessage("Сигналът е изпратен успешно!");
    } catch (e) {
      print("ГРЕШКА при запис във Firestore: $e");
      _showMessage("Грешка при изпращане на сигнала: ${e.toString()}");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Навигиране до текущата локация
  Future<void> _goToMyLocation() async {
    try {
      geo.LocationPermission permission = await geo.Geolocator.checkPermission();
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
            center: Point(coordinates: Position(position.longitude.toDouble(), position.latitude.toDouble())),
            zoom: 14.0,
          ),
          MapAnimationOptions(duration: 1500),
        );
        _addMyLocationMarker(position.latitude, position.longitude);
      }

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
    
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message), 
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
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                _showMessage("Текущата локация е неизвестна. Моля, активирайте GPS.");
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Филтри", style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 20),
                  ..._allAnimalFilters.map((status) {
                    return CheckboxListTile(
                      title: Text(status),
                      value: tempFilters.contains(status),
                      onChanged: (bool? isChecked) {
                        setModalState(() {
                          if (isChecked == true) {
                            tempFilters.add(status);
                          } else {
                            tempFilters.remove(status);
                          }
                        });
                      },
                      activeColor: Colors.green,
                    );
                  }).toList(),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _activeFilters = Set.from(tempFilters);
                        });
                        _loadMarkersFromFirestore();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: const Text("Приложи", style: TextStyle(color: Colors.white)),
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
  void _showMarkerInfoPanel(String docId, Map<String, dynamic> data) {
    String reporterId = data['reporterId'] ?? '';
    String reporterName = data['reporterName'] ?? 'Неизвестен';
    
    final canDelete = _userRole == 'zoologist' || reporterId == _currentUser?.uid;
    bool showChatButton = reporterId != _currentUser?.uid && reporterId.isNotEmpty;

    print("Права за изтриване: $canDelete (Роля: $_userRole, Reporter: $reporterId, Current: ${_currentUser?.uid})");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MarkerInfoSheet(
                data: data,
                isRescueTeam: _userRole == 'zoologist',
                onNavigate: () {
                  GeoPoint location = data['location'];
                  _launchNavigation(context, location.latitude, location.longitude);
                },
                onRemove: () => _removeMarker(context, docId),
                canDelete: canDelete,
                showChatButton: showChatButton,
                onChat: () {
                  Navigator.pop(context);
                  _navigateToChat(reporterId, reporterName);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
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
      final canDelete = _userRole == 'zoologist' || reporterId == _currentUser?.uid;
      
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
      
      await FirebaseFirestore.instance
          .collection('animal_reports')
          .doc(docId)
          .delete();

      print("Документът е изтрит успешно: $docId");
      
      _loadMarkersFromFirestore();
      
      Navigator.pop(context);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Сигналът е премахнат успешно.'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      
    } catch (e) {
      print("Грешка при изтриване: $e");
      
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Грешка при премахване на сигнала: ${e.toString()}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // Навигиране към чат
  void _navigateToChat(String reporterId, String reporterName) async {
    if (_currentUser == null || reporterId.isEmpty) return;

    String myId = _currentUser!.uid;
    String myName = _userData?['username'] ?? 'Потребител';

    if (myId == reporterId) {
      _showMessage("Не можете да започнете чат със себе си.");
      return;
    }

    String chatId = myId.compareTo(reporterId) > 0 ? '${myId}_$reporterId' : '${reporterId}_$myId';

    try {
      await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
        'members': [myId, reporterId],
        'memberNames': {myId: myName, reporterId: reporterName},
        'lastMessage': '',
        'lastMessageTimestamp': Timestamp.now(),
        'createdAt': Timestamp.now(),
      }, SetOptions(merge: true));

      print("Чат създаден успешно: $chatId (без автоматично съобщение)");

      if (!mounted) return;
      
      Navigator.pop(context);
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatDetailPage(
            channel: ChatChannel(
              id: chatId,
              name: reporterName,
              members: 2,
              lastMessage: '',
              time: DateFormat('HH:mm').format(DateTime.now()),
              unread: 0,
              isOnline: true,
              otherUserId: reporterId,
              otherUserName: reporterName,
            ),
            collectionPath: 'chats',
          ),
        ),
      );
    } catch (e) {
      print("Грешка при създаване на чат: $e");
      _showMessage("Неуспешно стартиране на чат. Моля, проверете правилата за достъп.");
    }
  }

  // Стартиране на навигация
  void _launchNavigation(BuildContext context, double latitude, double longitude) async {
    try {
      final coordinates = '$latitude,$longitude';
      await Clipboard.setData(ClipboardData(text: coordinates));
      
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
        uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=driving&dir_action=navigate');
      } else if (Platform.isIOS) {
        uri = Uri.parse('https://maps.apple.com/?daddr=$latitude,$longitude&dirflg=d&t=m');
      } else {
        uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=driving');
      }

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }

      Uri fallbackUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude');
      if (await canLaunchUrl(fallbackUri)) {
        await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
        return;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Неуспешно стартиране на навигация. Координатите са копирани: $coordinates'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      print("Грешка при навигация: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Грешка при стартиране на навигацията: ${e.toString()}'),
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
      builder: (context) => AlertDialog(
        title: const Text('Изберете стил на картата'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.map, color: Colors.green[700]),
              title: const Text('Стандартен'),
              onTap: () {
                _changeMapStyle("mapbox://styles/vikdev/cmgs0el6h00f101qx22dp3odf");
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.satellite, color: Colors.green[700]),
              title: const Text('Сателитен'),
              onTap: () {
                _changeMapStyle(MapboxStyles.SATELLITE);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.dark_mode, color: Colors.green[700]),
              title: const Text('Тъмен'),
              onTap: () {
                _changeMapStyle(MapboxStyles.DARK);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Изграждане на елемент от легендата
  Widget _buildLegendItem(Color color, String text) {
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
              border: Border.all(color: Colors.white, width: 2),
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
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Бутон за меню на картата
  Widget _buildMapMenuButton() {
    return PopupMenuButton<String>(
      icon: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.green[700],
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(Icons.menu, color: Colors.white),
      ),
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
        const PopupMenuItem<String>(
          value: 'filter',
          child: ListTile(
            leading: Icon(Icons.filter_list_rounded, color: Colors.green),
            title: Text('Филтри'),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'location',
          child: ListTile(
            leading: Icon(Icons.my_location_rounded, color: Colors.green),
            title: Text('Моята Локация'),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'call',
          child: ListTile(
            leading: Icon(Icons.call, color: Colors.green),
            title: Text('Спешен номер'),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'legend',
          child: ListTile(
            leading: Icon(Icons.legend_toggle_rounded, color: Colors.green),
            title: Text('Легенда'),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'style',
          child: ListTile(
            leading: Icon(Icons.style, color: Colors.green),
            title: Text('Смени стил на картата'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Карта на Сигналите"),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 0,
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
              color: Colors.white.withOpacity(0.9),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.green),
                    SizedBox(height: 20),
                    Text(
                      'Зареждане на картата...',
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            top: 30,
            left: 10,
            child: _buildMapMenuButton(),
          ),
          _buildBottomUI(),
          _buildLegend(),
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
        child: Column(
          children: [
            PulsingReportButton(onPressed: _showReportPanel),
          ],
        ),
      ),
    );
  }

  // Легенда за типовете маркери
  Widget _buildLegend() {
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
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(16),
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
                const Text(
                  'Легенда',
                  style: TextStyle(
                    color: Colors.white,
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