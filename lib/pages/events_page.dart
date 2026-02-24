import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../main_scaffold.dart';
import 'chat_page.dart';

// Страница за събития и новини
class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  EventSortType _sortType = EventSortType.newest;
  EventFilterType _filterType = EventFilterType.all;
  User? _currentUser;
  String _userRole = 'user';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Зареждане на данни за текущия потребител
  Future<void> _loadUserData() async {
    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser != null) {
      final user = _currentUser;
      if (user == null) return;
      
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (mounted) {
        setState(() {
          _userRole = (userDoc.data() as Map<String, dynamic>?)?['role'] ?? 'user';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Събития & Новини'),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildHeroHeader(scheme),
          _buildFilterSortRow(scheme),
          Expanded(
            child: _buildEventsList(),
          ),
        ],
      ),
      // Бутон за добавяне само за зоолози
      floatingActionButton: _userRole == 'zoologist'
          ? FloatingActionButton(
              onPressed: () => _addNewEvent(context),
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildHeroHeader(ColorScheme scheme) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primaryContainer,
            scheme.tertiaryContainer.withOpacity(0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.surface.withOpacity(0.8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.campaign_outlined, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Активности и новини',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                Text(
                  'Следи кампании, новини и събития на общността.',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Ред с филтри и сортиране
  Widget _buildFilterSortRow(ColorScheme scheme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          // Филтър по тип
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: scheme.outline),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<EventFilterType>(
                    value: _filterType,
                    isExpanded: true,
                    icon: Icon(Icons.filter_list, color: scheme.primary, size: 20),
                    items: EventFilterType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            type == EventFilterType.all
                                ? 'Всички'
                                : type == EventFilterType.event
                                    ? 'Събития'
                                    : 'Новини',
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _filterType = value!;
                      });
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Сортиране
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<EventSortType>(
                  value: _sortType,
                  isExpanded: false,
                  icon: Icon(Icons.sort, color: scheme.primary, size: 20),
                  items: [
                    DropdownMenuItem(
                      value: EventSortType.newest,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          'Най-нови',
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: EventSortType.oldest,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          'Най-стари',
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: EventSortType.popular,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          'Популярни',
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _sortType = value!;
                    });
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Списък със събития
  Widget _buildEventsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'Няма намерени събития',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        List<Event> allEvents =
            snapshot.data!.docs.map((doc) => Event.fromFirestore(doc)).toList();

        // Прилагане на филтри
        List<Event> filteredEvents = allEvents.where((event) {
          if (_filterType == EventFilterType.all) return true;
          if (_filterType == EventFilterType.event) {
            return event.type == EventType.event;
          }
          if (_filterType == EventFilterType.news) {
            return event.type == EventType.news;
          }
          return true;
        }).toList();

        // Прилагане на сортиране
        List<Event> sortedEvents = _sortEvents(filteredEvents);

        if (sortedEvents.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_busy, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  _filterType == EventFilterType.event
                      ? 'Няма намерени събития'
                      : _filterType == EventFilterType.news
                          ? 'Няма намерени новини'
                          : 'Няма намерени събития',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(8, 2, 8, 92),
          itemCount: sortedEvents.length,
          itemBuilder: (context, index) {
            return _buildEventCard(sortedEvents[index]);
          },
        );
      },
    );
  }

  // Сортиране на събития
  List<Event> _sortEvents(List<Event> events) {
    switch (_sortType) {
      case EventSortType.newest:
        events.sort((a, b) => b.date.compareTo(a.date));
        break;
      case EventSortType.oldest:
        events.sort((a, b) => a.date.compareTo(b.date));
        break;
      case EventSortType.popular:
        events.sort((a, b) => (b.attendingCount + b.interestedCount)
            .compareTo(a.attendingCount + a.interestedCount));
        break;
    }
    return events;
  }

  // Карта за показване на събитие
  Widget _buildEventCard(Event event) {
    final bool isCreator = _currentUser?.uid == event.creatorId;
    final scheme = Theme.of(context).colorScheme;
    final Color accent =
        event.type == EventType.event ? scheme.primary : const Color(0xFF2C7BE5);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openEventDetails(event),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 160,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (event.imageUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: event.imageUrl,
                      fit: BoxFit.cover,
                    )
                  else
                    Container(
                      color: accent.withOpacity(0.14),
                      child: Icon(
                        event.type == EventType.event
                            ? Icons.event_outlined
                            : Icons.article_outlined,
                        color: accent,
                        size: 54,
                      ),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black.withOpacity(0.55), Colors.transparent],
                        begin: Alignment.bottomCenter,
                        end: Alignment.center,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        event.type == EventType.event ? 'Събитие' : 'Новина',
                        style: TextStyle(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 13, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          '${event.date.day}.${event.date.month}.${event.date.year}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isCreator)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: IconButton(
                        icon: const Icon(Icons.edit, color: Colors.white),
                        onPressed: () => _editEvent(event),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withOpacity(0.38),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    event.shortDescription,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 16, color: scheme.primary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${event.interestedCount + event.attendingCount} души',
                          style: TextStyle(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openEventDetails(Event event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventDetailPage(event: event),
      ),
    );
  }

  void _addNewEvent(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddEventForm(
        onEventAdded: (Event newEventData) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Събитието е добавено успешно!'),
              backgroundColor: Colors.green[700],
            ),
          );
        },
      ),
    );
  }

  void _editEvent(Event event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddEventForm(
        event: event,
        onEventAdded: (Event updatedEvent) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Събитието е редактирано успешно!'),
              backgroundColor: Colors.green[700],
            ),
          );
        },
      ),
    );
  }
}

// Форма за добавяне/редактиране на събитие
class AddEventForm extends StatefulWidget {
  final Function(Event) onEventAdded;
  final Event? event;

  const AddEventForm({super.key, required this.onEventAdded, this.event});

  @override
  State<AddEventForm> createState() => _AddEventFormState();
}

class _AddEventFormState extends State<AddEventForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _shortDescController = TextEditingController();
  final TextEditingController _fullDescController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 7));
  EventType _selectedType = EventType.event;
  String _selectedImage = '';
  bool _isUploading = false;
  bool _createGroupChat = true;

  @override
  void initState() {
    super.initState();
    // Попълване на данни при редактиране
    if (widget.event != null) {
      _titleController.text = widget.event!.title;
      _shortDescController.text = widget.event!.shortDescription;
      _fullDescController.text = widget.event!.fullDescription;
      _locationController.text = widget.event!.location;
      _selectedDate = widget.event!.date;
      _selectedType = widget.event!.type;
      _selectedImage = widget.event!.imageUrl;
    }
    _updateDateController();
  }

  void _updateDateController() {
    _dateController.text = '${_selectedDate.day}.${_selectedDate.month}.${_selectedDate.year}';
  }

  // Избор на дата
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _updateDateController();
      });
    }
  }

  // Избор и качване на снимка
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _isUploading = true;
      });
      try {
        print("Започва качване на снимка за събитие...");
        File imageFile = File(image.path);
        String fileName = 'events/${DateTime.now().millisecondsSinceEpoch}.jpg';
        
        // Опростяване на инициализацията - използваме стандартната инстанция
        Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
        
        print("Път на съхранение: $fileName");

        UploadTask uploadTask = storageRef.putFile(imageFile);
        
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          if (mounted) {
            double progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
            print('Прогрес на качване: ${progress.toStringAsFixed(1)}% (State: ${snapshot.state})');
          }
        }, onError: (e) {
          print("ГРЕШКА по време на стрийм на качване: $e");
        });

        TaskSnapshot snapshot = await uploadTask;
        String downloadURL = await snapshot.ref.getDownloadURL();
        print('Снимката е качена успешно! URL: $downloadURL');
        
        if (mounted) {
          setState(() {
            _selectedImage = downloadURL;
            _isUploading = false;
          });
        }
      } catch (e) {
        print("ГРЕШКА при качване на снимка: $e");
        if (mounted) {
          setState(() {
            _isUploading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Грешка при качване на снимка: $e')),
          );
        }
      }
    }
  }

  // Изпращане на формата
  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isUploading = true;
      });

      String currentUserId = FirebaseAuth.instance.currentUser!.uid;
      String imageUrl = _selectedImage;

      try {
        if (widget.event == null) {
          // Създаване на ново събитие
          String? channelId;
          if (_createGroupChat) {
            DocumentReference channelDoc = await FirebaseFirestore.instance
                .collection('event_channels')
                .add({
              'name': _titleController.text,
              'description': _shortDescController.text,
              'adminId': currentUserId,
              'members': [currentUserId],
              'lastMessage': 'Каналът е създаден.',
              'lastMessageTimestamp': FieldValue.serverTimestamp(),
            });
            channelId = channelDoc.id;
          }

          await FirebaseFirestore.instance.collection('events').add({
            'title': _titleController.text,
            'date': Timestamp.fromDate(_selectedDate),
            'imageUrl': imageUrl,
            'shortDescription': _shortDescController.text,
            'fullDescription': _fullDescController.text,
            'location': _locationController.text,
            'type': _selectedType == EventType.event ? 'event' : 'news',
            'creatorId': currentUserId,
            'channelId': channelId ?? '',
            'attendees': [],
            'interested': [],
            'createdAt': FieldValue.serverTimestamp(),
          });
        } else {
          // Редактиране на съществуващо събитие
          await FirebaseFirestore.instance
              .collection('events')
              .doc(widget.event!.id)
              .update({
            'title': _titleController.text,
            'date': Timestamp.fromDate(_selectedDate),
            'imageUrl': imageUrl,
            'shortDescription': _shortDescController.text,
            'fullDescription': _fullDescController.text,
            'location': _locationController.text,
            'type': _selectedType == EventType.event ? 'event' : 'news',
          });

          // Актуализиране на канала при промяна в заглавието
          if (widget.event!.title != _titleController.text) {
            await FirebaseFirestore.instance
                .collection('event_channels')
                .doc(widget.event!.channelId)
                .update({
              'name': _titleController.text,
              'description': _shortDescController.text,
            });
          }
        }

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.event == null 
                  ? 'Събитието е добавено успешно!'
                  : 'Събитието е редактирано успешно!'),
              backgroundColor: Colors.green[700],
            ),
          );
        }

      } catch (e) {
        print("Грешка при ${widget.event == null ? 'създаване' : 'редактиране'} на събитие: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Грешка: $e')),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isUploading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.event == null ? 'Добавяне на събитие' : 'Редактиране на събитие',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      if (_isUploading) ...[
                        const Center(child: CircularProgressIndicator()),
                        const SizedBox(height: 16),
                      ],
                      // Поле за снимка
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: double.infinity,
                          height: 150,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: _selectedImage.isEmpty
                                ? (_selectedType == EventType.event
                                    ? Colors.green[100]
                                    : Colors.blue[100])
                                : Colors.transparent,
                            image: _selectedImage.isNotEmpty
                                ? DecorationImage(
                                    image: CachedNetworkImageProvider(_selectedImage),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                            border: Border.all(color: Colors.green[300] ?? Colors.green),
                          ),
                          child: _selectedImage.isEmpty
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _selectedType == EventType.event
                                          ? Icons.event
                                          : Icons.article,
                                      size: 40,
                                      color: _selectedType == EventType.event
                                          ? Colors.green[700]
                                          : Colors.blue[700],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Натисни за добавяне на снимка',
                                      style: TextStyle(
                                        color: _selectedType == EventType.event
                                            ? Colors.green[700]
                                            : Colors.blue[700],
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.camera_alt, size: 40, color: Colors.white),
                                    Text(
                                      'Натисни за смяна на снимка',
                                      style: TextStyle(color: Colors.white, fontSize: 16),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Избор на тип
                      Row(
                        children: [
                          Expanded(
                            child: ListTile(
                              title: const Text('Събитие'),
                              leading: Radio<EventType>(
                                value: EventType.event,
                                groupValue: _selectedType,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedType = value!;
                                  });
                                },
                              ),
                            ),
                          ),
                          Expanded(
                            child: ListTile(
                              title: const Text('Новина'),
                              leading: Radio<EventType>(
                                value: EventType.news,
                                groupValue: _selectedType,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedType = value!;
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Превключвател за групов чат
                      SwitchListTile(
                        title: const Text('Създай групов чат'),
                        subtitle: const Text('Позволи на участниците да общуват'),
                        secondary: Icon(Icons.chat_bubble_outline, color: Colors.green[700]),
                        value: _createGroupChat,
                        activeColor: Colors.green[700],
                        onChanged: (bool value) {
                          setState(() {
                            _createGroupChat = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      // Поле за заглавие
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: 'Заглавие на събитието',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.green[700] ?? Colors.green),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Моля, въведете заглавие';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Поле за дата
                      TextFormField(
                        controller: _dateController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Дата на събитието',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.green[700] ?? Colors.green),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                          suffixIcon: IconButton(
                            icon: Icon(Icons.calendar_today, color: Colors.green[700]),
                            onPressed: () => _selectDate(context),
                          ),
                        ),
                        onTap: () => _selectDate(context),
                      ),
                      const SizedBox(height: 16),
                      // Поле за място
                      TextFormField(
                        controller: _locationController,
                        decoration: InputDecoration(
                          labelText: 'Място/Адрес',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.green[700] ?? Colors.green),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Моля, въведете място';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Поле за кратко описание
                      TextFormField(
                        controller: _shortDescController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Кратко описание',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.green[700] ?? Colors.green),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Моля, въведете кратко описание';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Поле за пълно описание
                      TextFormField(
                        controller: _fullDescController,
                        maxLines: 5,
                        decoration: InputDecoration(
                          labelText: 'Пълно описание',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.green[700] ?? Colors.green),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          alignLabelWithHint: true,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Моля, въведете пълно описание';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),
                      // Бутони за отказ и запазване
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                side: BorderSide(color: Colors.green[700] ?? Colors.green),
                              ),
                              child: Text(
                                'Отказ',
                                style: TextStyle(color: Colors.green[700]),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isUploading ? null : _submitForm,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[700],
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: _isUploading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      widget.event == null ? 'Добави' : 'Запази',
                                      style: const TextStyle(color: Colors.white),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Страница с детайли за събитие
class EventDetailPage extends StatefulWidget {
  final Event event;
  const EventDetailPage({super.key, required this.event});

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  UserResponse _userResponse = UserResponse.none;
  String? _currentUserId;
  bool _isAttending = false;
  bool _isInterested = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _checkUserResponse();
  }

  // Проверка на отговора на потребителя
  void _checkUserResponse() {
    if (_currentUserId == null) return;
    setState(() {
      _isAttending = widget.event.attendees.contains(_currentUserId);
      _isInterested = widget.event.interested.contains(_currentUserId);
      if (_isAttending) {
        _userResponse = UserResponse.attending;
      } else if (_isInterested) {
        _userResponse = UserResponse.interested;
      } else {
        _userResponse = UserResponse.none;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isCreator = _currentUserId == widget.event.creatorId;
    final scheme = Theme.of(context).colorScheme;
    final accent = widget.event.type == EventType.event
        ? scheme.primary
        : const Color(0xFF2C7BE5);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Детайли за събитието'),
        actions: [
          if (isCreator) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _editEvent,
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteEvent,
            ),
          ]
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: widget.event.imageUrl.isEmpty
                    ? accent.withOpacity(0.14)
                    : Colors.transparent,
                image: widget.event.imageUrl.isNotEmpty
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(widget.event.imageUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: widget.event.imageUrl.isEmpty
                  ? Center(
                      child: Icon(
                        widget.event.type == EventType.event
                            ? Icons.event
                            : Icons.article,
                        size: 80,
                        color: accent,
                      ),
                    )
                  : Stack(
                      children: [
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.black.withOpacity(0.56),
                                  Colors.transparent
                                ],
                                begin: Alignment.bottomCenter,
                                end: Alignment.center,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 12,
                          top: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              widget.event.type == EventType.event ? 'Събитие' : 'Новина',
                              style: TextStyle(
                                color: accent,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.event.title,
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w900,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceVariant.withOpacity(0.55),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: accent),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.event.date.day}.${widget.event.date.month}.${widget.event.date.year}',
                    style: TextStyle(
                      fontSize: 14,
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Icon(Icons.location_on, size: 16, color: accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.event.location,
                      style: TextStyle(
                        fontSize: 14,
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildParticipationButtons(),
            const SizedBox(height: 16),
            _buildParticipationStats(),
            const SizedBox(height: 20),
            Text(
              'Описание',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Text(
                widget.event.fullDescription,
                style: TextStyle(
                  fontSize: 14,
                  color: scheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (widget.event.channelId.isNotEmpty && (_isAttending || isCreator))
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _goToChat,
                    icon: const Icon(Icons.chat),
                    label: const Text('Към чата на събитието'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _goToChat() {
    // Navigate to ChatDetailPage
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatDetailPage(
          channel: ChatChannel(
            id: widget.event.channelId,
            name: widget.event.title,
            members: widget.event.attendees.length,
            lastMessage: '',
            time: '',
            unread: 0,
            isOnline: false,
            adminId: widget.event.creatorId,
          ),
          collectionPath: 'event_channels',
        ),
      ),
    );
  }

  void _editEvent() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEventForm(
          event: widget.event,
          onEventAdded: (Event updatedEvent) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Събитието е редактирано успешно!'),
                backgroundColor: Colors.green[700],
              ),
            );
            Navigator.pop(context);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  // Бутони за участие в събитието
  Widget _buildParticipationButtons() {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () => _setUserResponse(UserResponse.attending),
            style: ElevatedButton.styleFrom(
              backgroundColor: _userResponse == UserResponse.attending
                  ? scheme.primary
                  : scheme.primaryContainer,
              foregroundColor: _userResponse == UserResponse.attending
                  ? Colors.white
                  : scheme.onPrimaryContainer,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline),
                SizedBox(width: 8),
                Text('Ще участвам'),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () => _setUserResponse(UserResponse.interested),
            style: ElevatedButton.styleFrom(
              backgroundColor: _userResponse == UserResponse.interested
                  ? Colors.orange[700]
                  : Colors.orange[100],
              foregroundColor: _userResponse == UserResponse.interested
                  ? Colors.white
                  : Colors.orange[700],
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite_border),
                SizedBox(width: 8),
                Text('Имам интерес'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Статистика за участие
  Widget _buildParticipationStats() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceVariant.withOpacity(0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Ще участват', widget.event.attendingCount, Icons.check_circle),
          _buildStatItem('Интерес', widget.event.interestedCount, Icons.favorite),
          _buildStatItem(
              'Общо',
              widget.event.attendingCount + widget.event.interestedCount,
              Icons.people),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, size: 20, color: scheme.primary),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: scheme.primary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: scheme.primary,
          ),
        ),
      ],
    );
  }

  // Задаване на отговор на потребителя
  void _setUserResponse(UserResponse response) async {
    if (_currentUserId == null) return;

    String eventId = widget.event.id;
    String channelId = widget.event.channelId;
    String userId = _currentUserId!;

    var eventRef = FirebaseFirestore.instance.collection('events').doc(eventId);
    var channelRef = FirebaseFirestore.instance.collection('event_channels').doc(channelId);

    if (response == UserResponse.attending) {
      await eventRef.update({
        'attendees': FieldValue.arrayUnion([userId]),
        'interested': FieldValue.arrayRemove([userId]),
      });
      await channelRef.update({
        'members': FieldValue.arrayUnion([userId]),
      });

      // Увеличаване на брояча за събития
      bool isAlreadyAttending = widget.event.attendees.contains(userId);
      if (!isAlreadyAttending) {
        final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
        await userRef.update({'eventsCount': FieldValue.increment(1)});
      }

      setState(() {
        widget.event.attendees.add(userId);
        widget.event.interested.remove(userId);
        _checkUserResponse();
        widget.event.attendingCount = widget.event.attendees.length;
        widget.event.interestedCount = widget.event.interested.length;
      });

      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => MainScaffold(initialIndex: 3),
          ),
          (route) => false);

    } else if (response == UserResponse.interested) {
      await eventRef.update({
        'interested': FieldValue.arrayUnion([userId]),
        'attendees': FieldValue.arrayRemove([userId]),
      });
      await channelRef.update({
        'members': FieldValue.arrayRemove([userId]),
      });

      setState(() {
        widget.event.interested.add(userId);
        widget.event.attendees.remove(userId);
        _checkUserResponse();
        widget.event.attendingCount = widget.event.attendees.length;
        widget.event.interestedCount = widget.event.interested.length;
      });
    }
  }

  void _deleteEvent() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Изтриване на събитие'),
        content: const Text('Сигурни ли сте, че искате да изтриете това събитие?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отказ', style: TextStyle(color: Colors.green[700])),
          ),
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('events')
                  .doc(widget.event.id)
                  .delete();
              FirebaseFirestore.instance
                  .collection('event_channels')
                  .doc(widget.event.channelId)
                  .delete();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Събитието е изтрито успешно!'),
                  backgroundColor: Colors.green[700],
                ),
              );
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text('Изтрий', style: TextStyle(color: Colors.red[700])),
          ),
        ],
      ),
    );
  }
}

// Модел за събитие
class Event {
  final String id;
  final String title;
  final DateTime date;
  final String imageUrl;
  final String shortDescription;
  final String fullDescription;
  final String location;
  final EventType type;
  int interestedCount;
  int attendingCount;
  final String creatorId;
  final String channelId;
  final List<String> attendees;
  final List<String> interested;

  Event({
    required this.id,
    required this.title,
    required this.date,
    required this.imageUrl,
    required this.shortDescription,
    required this.fullDescription,
    required this.location,
    required this.type,
    required this.interestedCount,
    required this.attendingCount,
    required this.creatorId,
    required this.channelId,
    required this.attendees,
    required this.interested,
  });

  factory Event.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Event(
      id: doc.id,
      title: data['title'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      imageUrl: data['imageUrl'] ?? '',
      shortDescription: data['shortDescription'] ?? '',
      fullDescription: data['fullDescription'] ?? '',
      location: data['location'] ?? '',
      type: (data['type'] ?? 'event') == 'event'
          ? EventType.event
          : EventType.news,
      interestedCount: (data['interested'] as List?)?.length ?? 0,
      attendingCount: (data['attendees'] as List?)?.length ?? 0,
      creatorId: data['creatorId'] ?? '',
      channelId: data['channelId'] ?? '',
      attendees: List<String>.from(data['attendees'] ?? []),
      interested: List<String>.from(data['interested'] ?? []),
    );
  }
}

enum EventType { event, news }
enum EventSortType { newest, oldest, popular }
enum EventFilterType { all, event, news }
enum UserResponse { none, interested, attending }
