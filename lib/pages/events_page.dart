import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../main_scaffold.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Събития и Новини'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildFilterSortRow(),
          Expanded(
            child: _buildEventsList(),
          ),
        ],
      ),
      // Бутон за добавяне само за зоолози
      floatingActionButton: _userRole == 'zoologist'
          ? FloatingActionButton(
              onPressed: () => _addNewEvent(context),
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  // Ред с филтри и сортиране
  Widget _buildFilterSortRow() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        border: Border(
          bottom: BorderSide(color: Colors.green[100] ?? Colors.green),
        ),
      ),
      child: Row(
        children: [
          // Филтър по тип
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green[300] ?? Colors.green),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<EventFilterType>(
                    value: _filterType,
                    isExpanded: true,
                    icon: Icon(Icons.filter_list, color: Colors.green[700], size: 20),
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
                              color: Colors.green[800],
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
              border: Border.all(color: Colors.green[300] ?? Colors.green),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<EventSortType>(
                  value: _sortType,
                  isExpanded: false,
                  icon: Icon(Icons.sort, color: Colors.green[700], size: 20),
                  items: [
                    DropdownMenuItem(
                      value: EventSortType.newest,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          'Най-нови',
                          style: TextStyle(
                            color: Colors.green[800],
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
                            color: Colors.green[800],
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
                            color: Colors.green[800],
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
    bool isCreator = _currentUser?.uid == event.creatorId;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      child: InkWell(
        onTap: () => _openEventDetails(event),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Икона или снимка на събитието
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: event.imageUrl.isEmpty
                      ? (event.type == EventType.event
                          ? Colors.green[100]
                          : Colors.blue[100])
                      : Colors.transparent,
                  image: event.imageUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(event.imageUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: event.imageUrl.isEmpty
                    ? Icon(
                        event.type == EventType.event
                            ? Icons.event
                            : Icons.article,
                        size: 40,
                        color: event.type == EventType.event
                            ? Colors.green[700]
                            : Colors.blue[700],
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            event.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Бутони за редактиране за създателя
                        if (isCreator) ...[
                          IconButton(
                            icon: Icon(Icons.edit, size: 18, color: Colors.green[700]),
                            onPressed: () => _editEvent(event),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 4),
                        ],
                        // Бейдж за тип
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: event.type == EventType.event
                                ? Colors.green[100]
                                : Colors.blue[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            event.type == EventType.event ? 'Събитие' : 'Новина',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: event.type == EventType.event
                                  ? Colors.green[800]
                                  : Colors.blue[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Дата
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: Colors.green[700]),
                        const SizedBox(width: 4),
                        Text(
                          '${event.date.day}.${event.date.month}.${event.date.year}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Кратко описание
                    Text(
                      event.shortDescription,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // Брой участници
                    Row(
                      children: [
                        Icon(Icons.people_outline, size: 16, color: Colors.green[700]),
                        const SizedBox(width: 4),
                        Text(
                          '${event.interestedCount + event.attendingCount} участници',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green[700],
                            fontWeight: FontWeight.w500,
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
        File imageFile = File(image.path);
        String fileName = 'events/${DateTime.now().millisecondsSinceEpoch}.jpg';
        Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
        UploadTask uploadTask = storageRef.putFile(imageFile);
        TaskSnapshot snapshot = await uploadTask;
        String downloadURL = await snapshot.ref.getDownloadURL();
        setState(() {
          _selectedImage = downloadURL;
          _isUploading = false;
        });
      } catch (e) {
        print("Грешка при качване на снимка: $e");
        setState(() {
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Грешка при качване на снимка: $e')),
        );
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

          await FirebaseFirestore.instance.collection('events').add({
            'title': _titleController.text,
            'date': Timestamp.fromDate(_selectedDate),
            'imageUrl': imageUrl,
            'shortDescription': _shortDescController.text,
            'fullDescription': _fullDescController.text,
            'location': _locationController.text,
            'type': _selectedType == EventType.event ? 'event' : 'news',
            'creatorId': currentUserId,
            'channelId': channelDoc.id,
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
                                    image: NetworkImage(_selectedImage),
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
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Детайли за събитието'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Снимка или икона на събитието
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: widget.event.imageUrl.isEmpty
                    ? (widget.event.type == EventType.event
                        ? Colors.green[100]
                        : Colors.blue[100])
                    : Colors.transparent,
                image: widget.event.imageUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(widget.event.imageUrl),
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
                        color: widget.event.type == EventType.event
                            ? Colors.green[700]
                            : Colors.blue[700],
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            // Заглавие
            Text(
              widget.event.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            // Дата и място
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.green[700]),
                const SizedBox(width: 8),
                Text(
                  '${widget.event.date.day}.${widget.event.date.month}.${widget.event.date.year}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.location_on, size: 16, color: Colors.green[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.event.location,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Бутони за участие
            _buildParticipationButtons(),
            const SizedBox(height: 16),
            // Статистика за участие
            _buildParticipationStats(),
            const SizedBox(height: 20),
            // Пълно описание
            const Text(
              'Описание',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.event.fullDescription,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[800],
                height: 1.5,
              ),
            ),
          ],
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
            Navigator.pop(context);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Събитието е редактирано успешно!'),
                backgroundColor: Colors.green[700],
              ),
            );
          },
        ),
      ),
    );
  }

  // Бутони за участие в събитието
  Widget _buildParticipationButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () => _setUserResponse(UserResponse.attending),
            style: ElevatedButton.styleFrom(
              backgroundColor: _userResponse == UserResponse.attending
                  ? Colors.green[700]
                  : Colors.green[50],
              foregroundColor: _userResponse == UserResponse.attending
                  ? Colors.white
                  : Colors.green[700],
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
                  : Colors.orange[50],
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
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
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.green[700]),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.green[700],
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.green[700],
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
              Navigator.pop(context);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Събитието е изтрито успешно!'),
                  backgroundColor: Colors.green[700],
                ),
              );
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