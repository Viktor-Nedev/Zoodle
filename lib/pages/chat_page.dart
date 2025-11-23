import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// Страница за профил на потребител
class ProfilePage extends StatelessWidget {
  final String userId;
  const ProfilePage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Профил')),
      body: Center(child: Text('Профил на потребител: $userId')),
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
        appBar: AppBar(backgroundColor: Colors.green[500], title: const Text('Чат')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.green[50],
      appBar: AppBar(
        backgroundColor: Colors.green[500],
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Чат'),
      ),
      body: _buildPersonalChatsTab(),
    );
  }

  // Изграждане на таб за лични чатове
  Widget _buildPersonalChatsTab() {
    final user = _currentUser;
    if (user == null) {
      return const Center(child: Text("Моля, влезте в профила си."));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('members', arrayContains: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        // Показване на индикатор за зареждане
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Обработка на грешки
        if (snapshot.hasError) {
          print("Грешка в чат query: ${snapshot.error}");
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Грешка при зареждане на чатове',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {});
                  },
                  child: const Text('Опитайте отново'),
                ),
              ],
            ),
          );
        }

        final data = snapshot.data;
        if (data == null) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Нямате лични съобщения',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        var docs = data.docs;
        
        // Филтриране на чатове без съобщения
        docs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final lastMsg = data['lastMessage'] as String?;
          return lastMsg != null && lastMsg.isNotEmpty;
        }).toList();

        // Показване на съобщение при липса на чатове
        if (docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Нямате лични съобщения',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Започнете чат от картата с други потребители',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        
        // Сортиране на чатове по време на последно съобщение
        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          
          final aTimestamp = aData['lastMessageTimestamp'] as Timestamp?;
          final bTimestamp = bData['lastMessageTimestamp'] as Timestamp?;
          
          if (aTimestamp == null && bTimestamp == null) return 0;
          if (aTimestamp == null) return 1;
          if (bTimestamp == null) return -1;
          
          return bTimestamp.compareTo(aTimestamp);
        });

        print("Заредени ${docs.length} чата (филтрирани и сортирани)");

        // Показване на списък с чатове
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final channel = ChatChannel.fromFirestore(docs[index], user.uid);
            return _buildChatItem(channel, showMembers: false, collectionPath: 'chats');
          },
        );
      },
    );
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
            if (channel.otherUserId.isNotEmpty) {
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
                      : (showMembers ? Icons.group : Icons.person),
                  color: channel.isVet ? Colors.green[600] : Colors.green[500],
                  size: 24,
                ),
              ),
              // Индикатор за онлайн статус
              if (channel.isOnline)
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
        title: Text(
          channel.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.green[800],
            fontSize: 16,
          ),
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
            // Брой членове (за групови чатове)
            if (showMembers) ...[
              const SizedBox(height: 4),
              Text(
                '${channel.members} членове',
                style: TextStyle(
                  color: Colors.green[600],
                  fontSize: 12,
                ),
              ),
            ],
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
  });
  
  // Създаване на обект от Firestore документ
  factory ChatChannel.fromFirestore(DocumentSnapshot doc, String currentUserId) {
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
      );
    }
    
    Map<String, dynamic> data = dataObj as Map<String, dynamic>;
    String chatName = data['name'] ?? 'Неизвестен канал';
    String otherId = '';
    String otherName = 'Потребител';

    // Логика за индивидуални чатове
    if (data.containsKey('memberNames')) {
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
    if (otherId.isEmpty && data.containsKey('members')) {
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
      // Добавяне на съобщение в подколекцията
      await messagesRef.add({
        'senderId': user.uid,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[50],
      appBar: AppBar(
        backgroundColor: Colors.green[500],
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.channel.name),
            Text(
              widget.channel.isOnline ? 'Онлайн' : 'Извън линия',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
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
                    return _buildMessageBubble(msg['text'] ?? '', isMe);
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

  // Изграждане на балон за съобщение
  Widget _buildMessageBubble(String text, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? Colors.green[500] : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isMe ? Colors.white : Colors.black87,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}