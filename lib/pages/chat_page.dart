import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:async/async.dart';

// Страница за профил на потребител
class ProfilePage extends StatelessWidget {
  final String userId;
  const ProfilePage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Профил'),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          final String name = data?['name'] ?? 'Потребител';
          final String role = data?['role'] ?? 'user';
          final bool isZoologist = role == 'zoologist';

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.green[100],
                  child: Icon(isZoologist ? Icons.medical_services : Icons.person, size: 50, color: Colors.green[700]),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    if (isZoologist) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.check_circle, color: Colors.green, size: 24),
                    ],
                  ],
                ),
                Text(isZoologist ? 'Зоолог (Верифициран)' : 'Потребител', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Основна страница за чатове
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  User? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Зареждане на данни за текущия потребител
  Future<void> _loadUserData() async {
    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Отваряне на детайлен изглед на чат
  void _openChat(ChatChannel channel, String collectionPath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatDetailPage(
          channel: channel,
          collectionPath: collectionPath,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Чат')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.green[50],
      appBar: AppBar(
        elevation: 0,
        title: const Text('Чат'),
      ),
      body: _buildPersonalChatsTab(),
    );
  }

  // Изграждане на таб за лични чатове (смесени с групи)
  Widget _buildPersonalChatsTab() {
    final user = _currentUser;
    if (user == null) {
      return const Center(child: Text("Моля, влезте в профила си."));
    }

    final personalStream = FirebaseFirestore.instance
        .collection('chats')
        .where('members', arrayContains: user.uid)
        .snapshots();

    final groupStream = FirebaseFirestore.instance
        .collection('event_channels')
        .where('members', arrayContains: user.uid)
        .snapshots();

    return StreamBuilder<List<ChatChannel>>(
      stream: _combineStreams(personalStream, groupStream, user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Грешка: ${snapshot.error}'));
        }

        final channels = snapshot.data ?? [];

        if (channels.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Нямате активни чатове', style: TextStyle(fontSize: 16, color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: channels.length,
          itemBuilder: (context, index) {
            final channel = channels[index];
            return _buildChatItem(
              channel,
              showMembers: channel.isGroup,
              collectionPath: channel.isGroup ? 'event_channels' : 'chats',
            );
          },
        );
      },
    );
  }

  Stream<List<ChatChannel>> _combineStreams(
      Stream<QuerySnapshot> s1, Stream<QuerySnapshot> s2, String userId) {
    return RxUtils.combineLatest2(s1, s2, (QuerySnapshot snap1, QuerySnapshot snap2) {
      final List<ChatChannel> list = [];
      for (var doc in snap1.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['lastMessage'] != null && data['lastMessage'].toString().isNotEmpty) {
          list.add(ChatChannel.fromFirestore(doc, userId, isGroup: false));
        }
      }
      for (var doc in snap2.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['lastMessage'] != null && data['lastMessage'].toString().isNotEmpty) {
          list.add(ChatChannel.fromFirestore(doc, userId, isGroup: true));
        }
      }

      // Сортиране по последно съобщение
      list.sort((a, b) => b.timestamp?.compareTo(a.timestamp ?? Timestamp(0, 0)) ?? 0);
      return list;
    });
  }

  // Изграждане на елемент от списъка с чатове
  Widget _buildChatItem(ChatChannel channel,
      {bool showMembers = false, required String collectionPath}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      color: Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: GestureDetector(
          onTap: () {
            if (!channel.isGroup && channel.otherUserId.isNotEmpty) {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfilePage(userId: channel.otherUserId),
                  ));
            }
          },
          child: Stack(
            children: [
              // Аватар на потребителя/групата
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: channel.isVet ? Colors.green[100] : Colors.green[50],
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: channel.isOnline ? (Colors.green[500] ?? Colors.green) : (Colors.grey[300] ?? Colors.grey),
                    width: 2,
                  ),
                ),
                child: Icon(
                  channel.isVet
                      ? Icons.medical_services
                      : (channel.isGroup ? Icons.group_work : (showMembers ? Icons.group : Icons.person)),
                  color: channel.isGroup ? Colors.orange[700] : (channel.isVet ? Colors.green[600] : Colors.green[500]),
                  size: 24,
                ),
              ),
              // Индикатор за онлайн статус
              if (channel.isOnline && !channel.isGroup)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.green[500],
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Заглавие и информация за чата
        title: Row(
          children: [
            Expanded(
              child: Text(
                channel.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: channel.isGroup ? Colors.green[900] : Colors.green[800],
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (channel.isZoologist) ...[
              const SizedBox(width: 4),
              const Icon(Icons.check_circle, color: Colors.green, size: 16),
            ],
            if (channel.isGroup)
              Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'ГРУПА',
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.orange[800]),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            // Последно съобщение
            Text(
              channel.lastMessage,
              style: TextStyle(
                color: Colors.green[700],
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        // Време и брой непрочетени съобщения
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              channel.time,
              style: TextStyle(
                color: Colors.green[600],
                fontSize: 12,
              ),
            ),
            // Бадж за непрочетени съобщения
            if (channel.unread > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green[500],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  channel.unread.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        onTap: () => _openChat(channel, collectionPath),
      ),
    );
  }
}

// Помощен клас за обединяване на стриймове
class RxUtils {
  static Stream<T> combineLatest2<A, B, T>(
      Stream<A> s1, Stream<B> s2, T Function(A, B) combiner) async* {
    A? lastA;
    B? lastB;
    bool hasA = false;
    bool hasB = false;

    await for (final value in StreamGroup.merge([
      s1.map((a) => _StreamValue(a, 1)),
      s2.map((b) => _StreamValue(b, 2)),
    ])) {
      if (value.index == 1) {
        lastA = value.value as A;
        hasA = true;
      } else {
        lastB = value.value as B;
        hasB = true;
      }
      if (hasA && hasB) {
        yield combiner(lastA!, lastB!);
      }
    }
  }
}

class _StreamValue {
  final dynamic value;
  final int index;
  _StreamValue(this.value, this.index);
}

// Модел за чат канал
class ChatChannel {
  final String id;
  final String name;
  final int members;
  final String lastMessage;
  final String time;
  final int unread;
  final bool isOnline;
  final bool isVet;
  final String adminId;
  final String otherUserId;
  final String otherUserName;
  final bool isGroup;
  final Timestamp? timestamp;
  final bool isZoologist;
  
  ChatChannel({
    required this.id,
    required this.name,
    required this.members,
    required this.lastMessage,
    required this.time,
    required this.unread,
    required this.isOnline,
    this.isVet = false,
    this.adminId = '',
    this.otherUserId = '',
    this.otherUserName = 'Потребител',
    this.isGroup = false,
    this.timestamp,
    this.isZoologist = false,
  });
  
  // Създаване на обект от Firestore документ
  factory ChatChannel.fromFirestore(DocumentSnapshot doc, String currentUserId, {bool isGroup = false}) {
    var dataObj = doc.data();
    if (dataObj == null) {
      return ChatChannel(
        id: doc.id,
        name: 'Error',
        members: 0,
        lastMessage: 'Error loading data',
        time: '',
        unread: 0,
        isOnline: false,
        isGroup: isGroup,
      );
    }
    
    Map<String, dynamic> data = dataObj as Map<String, dynamic>;
    String chatName = data['name'] ?? 'Неизвестен канал';
    String otherId = '';
    String otherName = 'Потребител';

    // Логика за индивидуални чатове
    if (!isGroup && data.containsKey('memberNames')) {
      Map<String, dynamic>? names = data['memberNames'] as Map<String, dynamic>?;
      if (names != null) {
        for (var entry in names.entries) {
          if (entry.key != currentUserId) {
            chatName = entry.value as String? ?? 'Неизвестен потребител';
            otherId = entry.key;
            otherName = chatName;
            break;
          }
        }
      }
    }

    // Резервна логика за намиране на другия потребител
    if (!isGroup && otherId.isEmpty && data.containsKey('members')) {
      List<dynamic> members = data['members'] ?? [];
      for (var member in members) {
        if (member != currentUserId) {
          otherId = member.toString();
          break;
        }
      }
    }

    // Форматиране на времето
    String formattedTime = '';
    Timestamp? timestamp = data['lastMessageTimestamp'] as Timestamp?;
    if (timestamp != null) {
      formattedTime = DateFormat('HH:mm').format(timestamp.toDate());
    } else {
      formattedTime = DateFormat('HH:mm').format(DateTime.now());
    }

    // Вземане на последното съобщение
    String lastMessage = data['lastMessage'] ?? '';
    bool isZoologist = data['otherRole'] == 'zoologist';
    
    if (data.containsKey('memberRoles') && otherId.isNotEmpty) {
      Map<String, dynamic>? roles = data['memberRoles'] as Map<String, dynamic>?;
      if (roles != null && roles.containsKey(otherId)) {
        isZoologist = roles[otherId] == 'zoologist';
      }
    }

    final membersList = data['members'] as List?;
    return ChatChannel(
      id: doc.id,
      name: chatName,
      otherUserId: otherId,
      otherUserName: otherName,
      members: membersList?.length ?? 0,
      lastMessage: lastMessage,
      time: formattedTime,
      unread: 0,
      isOnline: false,
      isVet: false,
      adminId: data['adminId'] ?? '',
      isGroup: isGroup,
      timestamp: timestamp,
      isZoologist: isZoologist,
    );
  }
}

// Страница за детайли на чат
class ChatDetailPage extends StatefulWidget {
  final ChatChannel channel;
  final String collectionPath;
  const ChatDetailPage({
    super.key,
    required this.channel,
    required this.collectionPath,
  });
  
  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  User? _currentUser;
  
  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Изпращане на съобщение
  void _sendMessage() async {
    final text = _messageController.text.trim();
    final user = _currentUser;
    if (text.isEmpty || user == null) return;

    _messageController.clear();

    var messagesRef = FirebaseFirestore.instance
        .collection(widget.collectionPath)
        .doc(widget.channel.id)
        .collection('messages');

    var chatDocRef = FirebaseFirestore.instance
        .collection(widget.collectionPath)
        .doc(widget.channel.id);

    try {
      // Get user role for the badge
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      final String role = userData?['role'] ?? 'user';

      // Добавяне на съобщение в подколекцията
      await messagesRef.add({
        'senderId': user.uid,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'senderName': userData?['name'] ?? user.displayName ?? 'Потребител',
        'senderRole': role,
      });

      // Обновяване на последното съобщение в канала
      await chatDocRef.update({
        'lastMessage': text,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
      });

      // Скролиране до най-новите съобщения
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      print("Грешка при изпращане на съобщение: $e");
    }
  }

  void _openGroupSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupSettingsPage(channel: widget.channel),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: GestureDetector(
          onTap: widget.channel.isGroup ? _openGroupSettings : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.channel.name, style: const TextStyle(fontSize: 16)),
              if (widget.channel.isGroup)
                Text(
                  '${widget.channel.members} членове',
                  style: const TextStyle(fontSize: 12),
                )
              else
                Text(
                  widget.channel.isOnline ? 'Онлайн' : 'Извън линия',
                  style: const TextStyle(fontSize: 12),
                ),
            ],
          ),
        ),
        actions: [
          if (widget.channel.isGroup)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: _openGroupSettings,
            ),
        ],
      ),
      body: Column(
        children: [
          // Област за съобщения
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(widget.collectionPath)
                  .doc(widget.channel.id)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Грешка при зареждане на съобщения: ${snapshot.error}'),
                  );
                }
                
                final data = snapshot.data;
                if (data == null || data.docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Няма съобщения'),
                        Text('Бъдете първият, който пише', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  );
                }

                var messages = data.docs;
                final currentUserId = _currentUser?.uid;

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var msg = messages[index].data() as Map<String, dynamic>;
                    bool isMe = currentUserId != null && msg['senderId'] == currentUserId;
                    bool isZoologist = msg['senderRole'] == 'zoologist';
                    
                    // Timestamp logic
                    Timestamp? ts = msg['timestamp'] as Timestamp?;
                    DateTime messageDate = ts?.toDate() ?? DateTime.now();
                    String time = DateFormat('HH:mm').format(messageDate);

                    // Date Header logic
                    bool showDateHeader = false;
                    if (index == messages.length - 1) {
                      showDateHeader = true; // Always show for oldest message
                    } else {
                      var prevMsg = messages[index + 1].data() as Map<String, dynamic>;
                      Timestamp? prevTs = prevMsg['timestamp'] as Timestamp?;
                      DateTime prevDate = prevTs?.toDate() ?? DateTime.now();
                      
                      if (messageDate.year != prevDate.year || 
                          messageDate.month != prevDate.month || 
                          messageDate.day != prevDate.day) {
                        showDateHeader = true;
                      }
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showDateHeader) _buildDateHeader(messageDate),
                        _buildMessageBubble(
                          msg['text'] ?? '', 
                          isMe, 
                          time,
                          senderName: widget.channel.isGroup && !isMe ? msg['senderName'] : null,
                          isZoologist: isZoologist,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          // Поле за въвеждане на съобщение
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Напишете съобщение...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide(color: Colors.green[300] ?? Colors.green),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onSubmitted: (value) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                // Бутон за изпращане
                CircleAvatar(
                  backgroundColor: Colors.green[500],
                  foregroundColor: Colors.white,
                  child: IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Изграждане на заглавка за дата
  Widget _buildDateHeader(DateTime date) {
    String text;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(date.year, date.month, date.day);

    if (dateToCheck == today) {
      text = 'Днес';
    } else if (dateToCheck == yesterday) {
      text = 'Вчера';
    } else {
      text = DateFormat('dd.MM.yyyy').format(date);
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: TextStyle(color: Colors.grey[800], fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // Изграждане на балон за съобщение
  Widget _buildMessageBubble(String text, bool isMe, String time, {String? senderName, bool isZoologist = false}) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (senderName != null)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    senderName,
                    style: TextStyle(fontSize: 11, color: Colors.green[800], fontWeight: FontWeight.bold),
                  ),
                  if (isZoologist) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.check_circle, color: Colors.green, size: 12),
                  ],
                ],
              ),
            ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isMe ? Colors.green[500] : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isMe ? 20 : 0),
                bottomRight: Radius.circular(isMe ? 0 : 20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    text,
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                ),
                Padding(
                   padding: const EdgeInsets.only(left: 8, top: 8),
                   child: Text(
                     time,
                     style: TextStyle(
                       color: isMe ? Colors.white70 : Colors.black54,
                       fontSize: 10,
                     ),
                   ),
                ),
                if (isMe && isZoologist) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.check_circle, color: Colors.white, size: 14),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Страница за настройки на група
class GroupSettingsPage extends StatefulWidget {
  final ChatChannel channel;
  const GroupSettingsPage({super.key, required this.channel});

  @override
  State<GroupSettingsPage> createState() => _GroupSettingsPageState();
}

class _GroupSettingsPageState extends State<GroupSettingsPage> {
  final TextEditingController _nameController = TextEditingController();
  bool _isAdmin = false;
  String? _currentUserId;
  bool _isEditingName = false;
  DateTime? _muteUntil;

  String? _muteType; // '1h', '2h', '8h', '24h', 'always'

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _isAdmin = widget.channel.adminId == _currentUserId;
    _nameController.text = widget.channel.name;
    _loadMuteStatus();
  }

  Future<void> _loadMuteStatus() async {
    final userId = _currentUserId;
    if (userId == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('event_channels')
        .doc(widget.channel.id)
        .collection('user_settings')
        .doc(userId)
        .get();

    if (doc.exists && mounted) {
      final data = doc.data();
      final timestamp = data?['muteUntil'] as Timestamp?;
      final type = data?['muteType'] as String?;
      
      setState(() {
        _muteUntil = timestamp?.toDate();
        // Fallback for legacy "Always" if type is missing
        if (_muteUntil != null && type == null) {
           if (_muteUntil!.year > 3000) {
             _muteType = 'always';
           }
        } else {
          _muteType = type;
        }
      });
    }
  }

  Future<void> _setMute(Duration? duration, String? type) async {
    final userId = _currentUserId;
    if (userId == null) return;

    // Toggle off if already selected
    if (_muteType == type && _muteUntil != null && _muteUntil!.isAfter(DateTime.now())) {
      // Unmute
      await _updateMuteData(null, null);
      return;
    }

    DateTime? until;
    if (duration != null) {
      if (duration.isNegative) {
        until = null; // Explicit Unmute button
      } else {
        until = DateTime.now().add(duration);
      }
    } else {
      // "Always" mute
      until = DateTime.now().add(const Duration(days: 36500)); // 100 years
    }
    
    // If explict unmute (duration negative), clear type
    final newType = (duration != null && duration.isNegative) ? null : type;

    // Optimistic update for instant feedback
    setState(() {
      _muteUntil = until;
      _muteType = newType;
    });

    await _updateMuteData(until, newType);
  }

  Future<void> _updateMuteData(DateTime? until, String? type) async {
    final userId = _currentUserId;
    if (userId == null) return;

    final data = {
      'muteUntil': until != null ? Timestamp.fromDate(until) : null,
      'muteType': type,
    };

    try {
      await FirebaseFirestore.instance
          .collection('event_channels')
          .doc(widget.channel.id)
          .collection('user_settings')
          .doc(userId)
          .update(data);
    } catch (e) {
      await FirebaseFirestore.instance
          .collection('event_channels')
          .doc(widget.channel.id)
          .collection('user_settings')
          .doc(userId)
          .set(data);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(until == null ? 'Известията са включени' : 'Известията са заглушени')),
      );
    }
  }

  Future<void> _updateName() async {
    if (!_isAdmin) return;
    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('event_channels')
          .doc(widget.channel.id)
          .update({'name': newName});
      
      final eventQuery = await FirebaseFirestore.instance
          .collection('events')
          .where('channelId', isEqualTo: widget.channel.id)
          .limit(1)
          .get();
      
      if (eventQuery.docs.isNotEmpty) {
        await eventQuery.docs.first.reference.update({'title': newName});
      }

      setState(() => _isEditingName = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Името е променено успешно!')),
        );
      }
    } catch (e) {
      print("Грешка при смяна на име: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isMuted = _muteUntil != null && _muteUntil!.isAfter(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.green[50],
      appBar: AppBar(
        title: const Text('Настройки на групата'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Име на групата
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Име на групата', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      if (_isAdmin)
                        IconButton(
                          icon: Icon(_isEditingName ? Icons.close : Icons.edit, color: Colors.green[700], size: 20),
                          onPressed: () => setState(() => _isEditingName = !_isEditingName),
                        ),
                    ],
                  ),
                  if (_isEditingName)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _nameController,
                            autofocus: true,
                            decoration: const InputDecoration(isDense: true),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: _updateName,
                        ),
                      ],
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        _nameController.text,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Заглушаване
            const Text('Известия', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(isMuted ? Icons.notifications_off_outlined : Icons.notifications_active_outlined, 
                        color: isMuted ? Colors.orange : Colors.green),
                    title: Text(isMuted ? 'Заглушено' : 'Активни известия', 
                        style: TextStyle(fontWeight: FontWeight.bold, color: isMuted ? Colors.orange[800] : Colors.green[800])),
                    subtitle: isMuted 
                        ? Text(_muteType == 'always' ? 'Известията са спрени' : 'Известията са спрени до ${DateFormat('dd.MM HH:mm').format(_muteUntil!)}', style: const TextStyle(color: Colors.red)) 
                        : const Text('Ще получавате известия за нови съобщения', style: TextStyle(color: Colors.grey)),
                    // Trailing button removed as requested
                  ),
                  const Divider(),
                    Center(
                      child: Wrap(
                        spacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          _muteChip('1ч', const Duration(hours: 1), '1h'),
                          _muteChip('2ч', const Duration(hours: 2), '2h'),
                          _muteChip('8ч', const Duration(hours: 8), '8h'),
                          _muteChip('24ч', const Duration(hours: 24), '24h'),
                          _muteChip('Винаги', null, 'always'),
                          if (isMuted)
                            ActionChip(
                              label: const Text('Отглуши'),
                              avatar: const Icon(Icons.notifications_active, size: 16, color: Colors.green),
                              backgroundColor: Colors.green[100],
                              onPressed: () => _setMute(const Duration(seconds: -1), null), // Pass null type to clear selection
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Участници
            const Text('Участници', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('event_channels')
                  .doc(widget.channel.id)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final members = List<String>.from(snapshot.data!['members'] ?? []);
                
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: members.length,
                    separatorBuilder: (c, i) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final memberId = members[index];
                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance.collection('users').doc(memberId).get(),
                        builder: (context, userSnap) {
                          if (!userSnap.hasData) return const SizedBox();
                          final userData = userSnap.data!.data() as Map<String, dynamic>?;
                          // Check for 'username' first, then 'name', then fallback
                          final name = userData?['username'] ?? userData?['name'] ?? 'Потребител';
                          final role = userData?['role'] ?? 'user';
                          final bool isMemberAdmin = memberId == widget.channel.adminId;
                          final bool isZoologist = role == 'zoologist';

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.green[50],
                              child: Icon(isZoologist ? Icons.medical_services : Icons.person, color: Colors.green),
                            ),
                            title: Row(
                              children: [
                                Text(name),
                                if (isZoologist) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                                ],
                              ],
                            ),
                            subtitle: Text(isMemberAdmin ? 'Администратор' : (isZoologist ? 'Зоолог' : 'Участник')),
                            trailing: _isAdmin && !isMemberAdmin
                                ? IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                    onPressed: () => _removeMember(memberId),
                                  )
                                : null,
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            
            // Напускане на група
            if (!_isAdmin)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _leaveGroup,
                  icon: const Icon(Icons.exit_to_app),
                  label: const Text('Напусни групата'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[50],
                    foregroundColor: Colors.red,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.red[100]!)),
                  ),
                ),
              ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _muteChip(String label, Duration? duration, String type) {
    final bool isSelected = _muteType == type && _muteUntil != null && _muteUntil!.isAfter(DateTime.now());
    
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _setMute(duration, type),
      selectedColor: Colors.orange[100],
      checkmarkColor: Colors.orange[800],
      labelStyle: TextStyle(
        color: isSelected ? Colors.orange[900] : Colors.green[800], 
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: Colors.green[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: isSelected ? BorderSide(color: Colors.orange[300]!) : BorderSide.none,
      ),
    );
  }

  Future<void> _removeMember(String memberId) async {
    if (!_isAdmin) return;
    try {
      await FirebaseFirestore.instance
          .collection('event_channels')
          .doc(widget.channel.id)
          .update({
        'members': FieldValue.arrayRemove([memberId])
      });
      
      // Also update event attendees
      final eventQuery = await FirebaseFirestore.instance
          .collection('events')
          .where('channelId', isEqualTo: widget.channel.id)
          .limit(1)
          .get();
      
      if (eventQuery.docs.isNotEmpty) {
        await eventQuery.docs.first.reference.update({
          'attendees': FieldValue.arrayRemove([memberId])
        });
      }
    } catch (e) {
      print("Грешка при премахване на член: $e");
    }
  }

  Future<void> _leaveGroup() async {
    final userId = _currentUserId;
    if (userId == null) return;

    try {
      if (_isAdmin) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Администраторът не може да напусне групата. Моля, изтрийте събитието.')),
        );
        return;
      }

      await FirebaseFirestore.instance
          .collection('event_channels')
          .doc(widget.channel.id)
          .update({
        'members': FieldValue.arrayRemove([userId])
      });

       // Update event attendees
      final eventQuery = await FirebaseFirestore.instance
          .collection('events')
          .where('channelId', isEqualTo: widget.channel.id)
          .limit(1)
          .get();
      
      if (eventQuery.docs.isNotEmpty) {
        await eventQuery.docs.first.reference.update({
          'attendees': FieldValue.arrayRemove([userId])
        });
      }

      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      print("Грешка при напускане: $e");
    }
  }
}



