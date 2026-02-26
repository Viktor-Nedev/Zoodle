import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:io';
import 'package:async/async.dart';

import '../models/badge_data.dart';
import 'profile_page.dart';

CollectibleBadge? findBadgeById(String? badgeId) {
  if (badgeId == null || badgeId.isEmpty) return null;
  for (final badge in badgeCatalog) {
    if (badge.id == badgeId) return badge;
  }
  return null;
}

enum ChatFilter { all, direct, groups }

// Основна страница за чатове
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  User? _currentUser;
  bool _isLoading = true;
  String _currentUserName = 'Потребител';
  String _currentUserRole = 'user';
  String _searchQuery = '';
  ChatFilter _filter = ChatFilter.all;

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

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .get();
      final data = userDoc.data();
      _currentUserName = data?['username'] ??
          data?['name'] ??
          _currentUser!.displayName ??
          'Потребител';
      _currentUserRole = data?['role'] ?? 'user';
    } catch (e) {
      print("Грешка при зареждане на потребител: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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

    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        elevation: 0,
        title: const Text('Чат'),
      ),
      body: Column(
        children: [
          _buildSearchAndFilters(),
          _buildPendingInvites(),
          Expanded(child: _buildChatList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewChatSheet,
        icon: const Icon(Icons.chat_bubble_outline),
        label: const Text('Нов чат'),
      ),
    );
  }

  String _normalizeSearch(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  String _userNameFromData(Map<String, dynamic> data) {
    final raw = (data['username'] ?? data['name'] ?? data['displayName'] ?? '')
        .toString()
        .trim();
    if (raw.isNotEmpty) return raw;
    final email = (data['email'] ?? '').toString().trim();
    if (email.contains('@')) return email.split('@').first;
    return 'Потребител';
  }

  bool _matchesUserQuery(Map<String, dynamic> data, String normalizedQuery) {
    if (normalizedQuery.isEmpty) return true;
    final q = _normalizeSearch(normalizedQuery);
    final qNoSpace = q.replaceAll(' ', '');
    final parts = q.split(' ').where((part) => part.isNotEmpty);

    final name = _normalizeSearch(_userNameFromData(data));
    final email = _normalizeSearch((data['email'] ?? '').toString());
    final displayName =
        _normalizeSearch((data['displayName'] ?? '').toString());

    final fields = <String>[
      name,
      name.replaceAll(' ', ''),
      email,
      displayName,
    ];

    if (fields.any((field) => field.contains(q) || field.contains(qNoSpace))) {
      return true;
    }

    return parts.every((part) {
      final compactPart = part.replaceAll(' ', '');
      return fields.any((field) =>
          field.contains(part) || field.contains(compactPart));
    });
  }

  int _userSearchScore(Map<String, dynamic> data, String normalizedQuery) {
    if (normalizedQuery.isEmpty) return 0;
    final q = _normalizeSearch(normalizedQuery);
    final name = _normalizeSearch(_userNameFromData(data));
    final email = _normalizeSearch((data['email'] ?? '').toString());
    if (name == q) return 0;
    if (name.startsWith(q)) return 1;
    if (email.startsWith(q)) return 2;
    if (name.contains(q)) return 3;
    if (email.contains(q)) return 4;
    return 5;
  }

  Future<void> _notifyUser({
    required String userId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? payload,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': userId,
        'title': title,
        'body': body,
        'type': type,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        if (payload != null) 'payload': payload,
      });
    } catch (e) {
      print("Грешка при създаване на известие: $e");
    }
  }

  Future<void> _postSystemMessage({
    required String channelId,
    required String text,
  }) async {
    try {
      final channelRef = FirebaseFirestore.instance
          .collection('event_channels')
          .doc(channelId);
      await channelRef.collection('messages').add({
        'senderId': 'system',
        'senderName': 'Система',
        'senderRole': 'system',
        'senderPhotoUrl': '',
        'text': text,
        'messageType': 'text',
        'timestamp': FieldValue.serverTimestamp(),
        'deleted': false,
      });
      await channelRef.set({
        'lastMessage': text,
        'lastMessageType': 'text',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'lastMessageSenderId': 'system',
      }, SetOptions(merge: true));
    } catch (e) {
      print("Грешка при системно съобщение: $e");
    }
  }

  Future<void> _respondToInvitation({
    required QueryDocumentSnapshot inviteDoc,
    required bool accept,
  }) async {
    final user = _currentUser;
    if (user == null) return;

    final data = inviteDoc.data() as Map<String, dynamic>;
    final status = (data['status'] ?? '').toString();
    if (status != 'pending') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Поканата вече е обработена.')),
      );
      return;
    }

    final channelId = (data['channelId'] ?? '').toString();
    final channelName = (data['channelName'] ?? 'Група').toString();
    final inviterId = (data['inviterId'] ?? '').toString();
    final inviteeName = (data['inviteeName'] ?? _currentUserName).toString();
    final eventId = (data['eventId'] ?? '').toString();

    try {
      await inviteDoc.reference.set({
        'status': accept ? 'accepted' : 'declined',
        'respondedAt': FieldValue.serverTimestamp(),
        'respondedBy': user.uid,
      }, SetOptions(merge: true));

      if (accept && channelId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('event_channels')
            .doc(channelId)
            .set({
          'members': FieldValue.arrayUnion([user.uid]),
        }, SetOptions(merge: true));

        if (eventId.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('events')
              .doc(eventId)
              .set({
            'attendees': FieldValue.arrayUnion([user.uid]),
          }, SetOptions(merge: true));
        } else {
          final eventQuery = await FirebaseFirestore.instance
              .collection('events')
              .where('channelId', isEqualTo: channelId)
              .limit(1)
              .get();
          if (eventQuery.docs.isNotEmpty) {
            await eventQuery.docs.first.reference.update({
              'attendees': FieldValue.arrayUnion([user.uid]),
            });
          }
        }

        await _postSystemMessage(
          channelId: channelId,
          text: '$inviteeName прие поканата за групата.',
        );
      }

      if (inviterId.isNotEmpty) {
        final statusText = accept ? 'прие' : 'отказа';
        await _notifyUser(
          userId: inviterId,
          title: 'Отговор на покана',
          body: '$inviteeName $statusText поканата за "$channelName".',
          type: 'group_invite_response',
          payload: {
            'channelId': channelId,
            'inviteId': inviteDoc.id,
            'accepted': accept,
          },
        );
      }

      if (accept && channelId.isNotEmpty) {
        await _notifyUser(
          userId: user.uid,
          title: 'Поканата е приета',
          body: 'Вече сте част от "$channelName".',
          type: 'group_invite',
          payload: {'channelId': channelId},
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? 'Приехте поканата за "$channelName".'
                : 'Отказахте поканата за "$channelName".',
          ),
        ),
      );
    } catch (e) {
      print("Грешка при обработка на покана: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Грешка при обработка на поканата.')),
      );
    }
  }

  Widget _buildPendingInvites() {
    final user = _currentUser;
    if (user == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('group_invitations')
          .where('inviteeId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final pending = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          return (data['status'] ?? '') == 'pending';
        }).toList()
          ..sort((a, b) {
            final ta =
                (a['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
            final tb =
                (b['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
            return tb.compareTo(ta);
          });

        if (pending.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 6, 16, 2),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.secondaryContainer.withOpacity(0.55),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.mark_email_unread_outlined, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Покани за групи (${pending.length})',
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...pending.take(3).map((invite) {
                final data = invite.data() as Map<String, dynamic>? ?? {};
                final group = (data['channelName'] ?? 'Група').toString();
                final inviter =
                    (data['inviterName'] ?? 'Администратор').toString();
                return Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$inviter ви покани в "$group".',
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _respondToInvitation(
                                inviteDoc: invite,
                                accept: false,
                              ),
                              child: const Text('Откажи'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _respondToInvitation(
                                inviteDoc: invite,
                                accept: true,
                              ),
                              child: const Text('Приеми'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchAndFilters() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = _normalizeSearch(value);
              });
            },
            decoration: InputDecoration(
              hintText: 'Търси чат или съобщение...',
              prefixIcon: Icon(Icons.search, color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              children: [
                _buildFilterChip('Всички', ChatFilter.all),
                _buildFilterChip('Лични', ChatFilter.direct),
                _buildFilterChip('Групи', ChatFilter.groups),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, ChatFilter filter) {
    final scheme = Theme.of(context).colorScheme;
    final bool isSelected = _filter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _filter = filter;
        });
      },
      selectedColor: scheme.primaryContainer,
      backgroundColor: scheme.surfaceVariant,
      labelStyle: TextStyle(
        color: isSelected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  // Изграждане на таб за лични чатове (смесени с групи)
  Widget _buildChatList() {
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
        final query = _normalizeSearch(_searchQuery);
        final filteredChannels = channels.where((channel) {
          if (_filter == ChatFilter.direct && channel.isGroup) return false;
          if (_filter == ChatFilter.groups && !channel.isGroup) return false;
          if (query.isEmpty) return true;
          return channel.name.toLowerCase().contains(query) ||
              channel.lastMessage.toLowerCase().contains(query);
        }).toList();

        if (channels.isEmpty && query.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Нямате активни чатове',
                    style: TextStyle(fontSize: 16, color: Colors.grey)),
              ],
            ),
          );
        }

        if (filteredChannels.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Няма резултати',
                    style: TextStyle(fontSize: 16, color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: filteredChannels.length,
          itemBuilder: (context, index) {
            final channel = filteredChannels[index];
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

  String _buildChatId(String a, String b) {
    return a.compareTo(b) > 0 ? '${a}_$b' : '${b}_$a';
  }

  Future<void> _startDirectChat({
    required String otherUserId,
    required String otherUserName,
  }) async {
    final user = _currentUser;
    if (user == null) return;
    if (user.uid == otherUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Не можете да започнете чат със себе си.')),
      );
      return;
    }

    try {
      final otherDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(otherUserId)
          .get();
      final otherRole = otherDoc.data()?['role'] ?? 'user';

      final chatId = _buildChatId(user.uid, otherUserId);
      await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
        'members': [user.uid, otherUserId],
        'memberNames': {
          user.uid: _currentUserName,
          otherUserId: otherUserName,
        },
        'memberRoles': {
          user.uid: _currentUserRole,
          otherUserId: otherRole,
        },
        'lastMessage': '',
        'lastMessageType': 'text',
        'lastMessageTimestamp': Timestamp.now(),
        'createdAt': Timestamp.now(),
        'lastRead': {user.uid: Timestamp.now()},
      }, SetOptions(merge: true));

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatDetailPage(
            channel: ChatChannel(
              id: chatId,
              name: otherUserName,
              members: 2,
              lastMessage: '',
              time: DateFormat('HH:mm').format(DateTime.now()),
              unread: 0,
              isOnline: false,
              otherUserId: otherUserId,
              otherUserName: otherUserName,
            ),
            collectionPath: 'chats',
          ),
        ),
      );
    } catch (e) {
      print("Грешка при създаване на чат: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Неуспешно стартиране на чат.')),
      );
    }
  }

  void _openNewChatSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        String localQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 48,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Нов чат',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        onChanged: (value) {
                          setModalState(() {
                            localQuery = _normalizeSearch(value);
                          });
                        },
                        decoration: const InputDecoration(
                          hintText: 'Търси потребител...',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }
                            final docs = snapshot.data!.docs;
                            final filtered = docs.where((doc) {
                              if (doc.id == _currentUser?.uid) return false;
                              final data = doc.data() as Map<String, dynamic>;
                              return _matchesUserQuery(data, localQuery);
                            }).toList()
                              ..sort((a, b) {
                                final aData = a.data() as Map<String, dynamic>;
                                final bData = b.data() as Map<String, dynamic>;
                                final aScore =
                                    _userSearchScore(aData, localQuery);
                                final bScore =
                                    _userSearchScore(bData, localQuery);
                                if (aScore != bScore) {
                                  return aScore.compareTo(bScore);
                                }
                                final aName =
                                    _normalizeSearch(_userNameFromData(aData));
                                final bName =
                                    _normalizeSearch(_userNameFromData(bData));
                                return aName.compareTo(bName);
                              });

                            if (filtered.isEmpty) {
                              return const Center(
                                  child: Text('Няма намерени потребители'));
                            }

                            return ListView.separated(
                              controller: scrollController,
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final doc = filtered[index];
                                final data = doc.data() as Map<String, dynamic>;
                                final name = _userNameFromData(data);
                                final role = data['role'] ?? 'user';
                                final isZoologist = role == 'zoologist';
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .surfaceVariant,
                                    child: Icon(
                                      isZoologist
                                          ? Icons.medical_services
                                          : Icons.person,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(child: Text(name)),
                                      if (isZoologist) ...[
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.check_circle,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          size: 16,
                                        ),
                                      ],
                                    ],
                                  ),
                                  subtitle: Text(
                                      isZoologist ? 'Зоолог' : 'Потребител'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _startDirectChat(
                                      otherUserId: doc.id,
                                      otherUserName: name,
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Stream<List<ChatChannel>> _combineStreams(
      Stream<QuerySnapshot> s1, Stream<QuerySnapshot> s2, String userId) {
    return RxUtils.combineLatest2(s1, s2,
        (QuerySnapshot snap1, QuerySnapshot snap2) {
      final List<ChatChannel> list = [];
      for (var doc in snap1.docs) {
        list.add(ChatChannel.fromFirestore(doc, userId, isGroup: false));
      }
      for (var doc in snap2.docs) {
        list.add(ChatChannel.fromFirestore(doc, userId, isGroup: true));
      }

      // Сортиране по последно съобщение
      list.sort((a, b) =>
          b.timestamp?.compareTo(a.timestamp ?? Timestamp(0, 0)) ?? 0);
      return list;
    });
  }

  // Изграждане на елемент от списъка с чатове
  Widget _buildChatItem(ChatChannel channel,
      {bool showMembers = false, required String collectionPath}) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      color: scheme.surface,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: GestureDetector(
          onTap: () {
            if (!channel.isGroup && channel.otherUserId.isNotEmpty) {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ProfilePage(userId: channel.otherUserId),
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
                  color: channel.isVet
                      ? scheme.primaryContainer
                      : scheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: channel.isOnline
                        ? scheme.primary
                        : scheme.outlineVariant,
                    width: 2,
                  ),
                ),
                child: Icon(
                  channel.isVet
                      ? Icons.medical_services
                      : (channel.isGroup
                          ? Icons.group_work
                          : (showMembers ? Icons.group : Icons.person)),
                  color: channel.isGroup
                      ? scheme.tertiary
                      : (channel.isVet ? scheme.primary : scheme.primary),
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
                      color: scheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.surface, width: 2),
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
                  color: scheme.onSurface,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (channel.isZoologist) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
                size: 16,
              ),
            ],
            if (channel.isGroup)
              Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'ГРУПА',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: scheme.onTertiaryContainer,
                  ),
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
                color: scheme.onSurfaceVariant,
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
                color: scheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            // Бадж за непрочетени съобщения
            if (channel.unread > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.primary,
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
  factory ChatChannel.fromFirestore(DocumentSnapshot doc, String currentUserId,
      {bool isGroup = false}) {
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
      Map<String, dynamic>? names =
          data['memberNames'] as Map<String, dynamic>?;
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
    final String lastMessageType = data['lastMessageType'] ?? 'text';
    if (lastMessageType == 'image') {
      lastMessage = 'Снимка';
    }
    if (lastMessage.isEmpty) {
      lastMessage = 'Започнете разговор';
    }
    bool isZoologist = data['otherRole'] == 'zoologist';

    if (data.containsKey('memberRoles') && otherId.isNotEmpty) {
      Map<String, dynamic>? roles =
          data['memberRoles'] as Map<String, dynamic>?;
      if (roles != null && roles.containsKey(otherId)) {
        isZoologist = roles[otherId] == 'zoologist';
      }
    }

    final membersList = data['members'] as List?;

    int unread = 0;
    final lastReadMap = data['lastRead'] as Map<String, dynamic>?;
    final Timestamp? lastRead =
        lastReadMap != null ? lastReadMap[currentUserId] as Timestamp? : null;
    final String lastSenderId = data['lastMessageSenderId'] ?? '';
    if (timestamp != null) {
      if (lastSenderId != currentUserId &&
          (lastRead == null || lastRead.compareTo(timestamp) < 0)) {
        unread = 1;
      }
    }
    return ChatChannel(
      id: doc.id,
      name: chatName,
      otherUserId: otherId,
      otherUserName: otherName,
      members: membersList?.length ?? 0,
      lastMessage: lastMessage,
      time: formattedTime,
      unread: unread,
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
  final FocusNode _messageFocusNode = FocusNode();
  User? _currentUser;
  Timer? _typingTimer;
  bool _isTyping = false;
  Timestamp? _lastSeenTimestamp;
  DateTime? _lastReadUpdateAt;
  Map<String, dynamic>? _replyTo;
  String _senderName = 'Потребител';
  String _senderRole = 'user';
  String _senderPhotoUrl = '';
  String? _editingMessageId;
  String? _editingOriginalText;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _loadSenderInfo();
  }

  @override
  void dispose() {
    _setTyping(false);
    _typingTimer?.cancel();
    _messageController.dispose();
    _messageFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSenderInfo() async {
    final user = _currentUser;
    if (user == null) return;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data();
      _senderName = userData?['username'] ??
          userData?['name'] ??
          user.displayName ??
          'Потребител';
      _senderRole = userData?['role'] ?? 'user';
      _senderPhotoUrl = (userData?['profilePictureUrl'] ?? '').toString();
    } catch (e) {
      print("Грешка при зареждане на данни за потребителя: $e");
    }
  }

  void _onTextChanged(String value) {
    if (_currentUser == null) return;
    if (!_isTyping) {
      _setTyping(true);
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _setTyping(false);
    });
  }

  Future<void> _setTyping(bool isTyping) async {
    final user = _currentUser;
    if (user == null) return;
    if (_isTyping == isTyping) return;
    _isTyping = isTyping;

    try {
      final docRef = FirebaseFirestore.instance
          .collection(widget.collectionPath)
          .doc(widget.channel.id);
      await docRef.update({'typing.${user.uid}': isTyping});
    } catch (e) {
      try {
        await FirebaseFirestore.instance
            .collection(widget.collectionPath)
            .doc(widget.channel.id)
            .set({
          'typing': {user.uid: isTyping}
        }, SetOptions(merge: true));
      } catch (inner) {
        print("Грешка при обновяване на typing: $inner");
      }
    }
  }

  Future<void> _markChatRead(Timestamp? latestTimestamp) async {
    final user = _currentUser;
    if (user == null || latestTimestamp == null) return;

    if (_lastSeenTimestamp != null &&
        latestTimestamp.compareTo(_lastSeenTimestamp!) <= 0) {
      return;
    }

    final now = DateTime.now();
    if (_lastReadUpdateAt != null &&
        now.difference(_lastReadUpdateAt!).inSeconds < 5) {
      return;
    }

    _lastSeenTimestamp = latestTimestamp;
    _lastReadUpdateAt = now;

    try {
      final docRef = FirebaseFirestore.instance
          .collection(widget.collectionPath)
          .doc(widget.channel.id);
      await docRef
          .update({'lastRead.${user.uid}': FieldValue.serverTimestamp()});
    } catch (e) {
      try {
        await FirebaseFirestore.instance
            .collection(widget.collectionPath)
            .doc(widget.channel.id)
            .set({
          'lastRead': {user.uid: FieldValue.serverTimestamp()}
        }, SetOptions(merge: true));
      } catch (inner) {
        print("Грешка при маркиране като прочетено: $inner");
      }
    }
  }

  Future<void> _sendMessage({
    String? text,
    String? imageUrl,
    String messageType = 'text',
    String? messageId,
  }) async {
    final user = _currentUser;
    if (user == null) return;
    final messageText = text?.trim() ?? '';
    if (messageType == 'text' && messageText.isEmpty) return;

    _messageController.clear();

    var messagesRef = FirebaseFirestore.instance
        .collection(widget.collectionPath)
        .doc(widget.channel.id)
        .collection('messages');

    var chatDocRef = FirebaseFirestore.instance
        .collection(widget.collectionPath)
        .doc(widget.channel.id);

    try {
      final docRef =
          messageId != null ? messagesRef.doc(messageId) : messagesRef.doc();
      final messageData = {
        'senderId': user.uid,
        'text': messageText,
        'imageUrl': imageUrl,
        'messageType': messageType,
        'timestamp': FieldValue.serverTimestamp(),
        'senderName': _senderName,
        'senderRole': _senderRole,
        'senderPhotoUrl': _senderPhotoUrl,
        'deleted': false,
        'isEdited': false,
        if (_replyTo != null) 'replyTo': _replyTo,
      };

      await docRef.set(messageData);

      await chatDocRef.set({
        'lastMessage': messageType == 'image' ? 'Снимка' : messageText,
        'lastMessageType': messageType,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'lastMessageSenderId': user.uid,
      }, SetOptions(merge: true));

      if (_replyTo != null && mounted) {
        setState(() {
          _replyTo = null;
        });
      }
      if (_editingMessageId != null && mounted) {
        setState(() {
          _editingMessageId = null;
          _editingOriginalText = null;
        });
      }
      _setTyping(false);

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

  Future<void> _sendTextMessage() async {
    if (_editingMessageId != null) {
      await _saveEditedMessage();
      return;
    }
    await _sendMessage(text: _messageController.text, messageType: 'text');
  }

  void _startEditingMessage(String messageId, Map<String, dynamic> message) {
    final text = (message['text'] ?? '').toString();
    if (text.trim().isEmpty) return;
    setState(() {
      _editingMessageId = messageId;
      _editingOriginalText = text;
      _messageController.text = text;
      _replyTo = null;
    });
    _messageFocusNode.requestFocus();
    _messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: _messageController.text.length),
    );
  }

  void _clearEditing() {
    setState(() {
      _editingMessageId = null;
      _editingOriginalText = null;
    });
    _messageController.clear();
  }

  Future<void> _saveEditedMessage() async {
    final messageId = _editingMessageId;
    if (messageId == null) return;
    final editedText = _messageController.text.trim();
    if (editedText.isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection(widget.collectionPath)
          .doc(widget.channel.id)
          .collection('messages')
          .doc(messageId)
          .update({
        'text': editedText,
        'isEdited': true,
        'editedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _editingMessageId = null;
        _editingOriginalText = null;
      });
      _messageController.clear();
    } catch (e) {
      print("Грешка при редакция на съобщение: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Неуспешна редакция на съобщението.')),
      );
    }
  }

  Future<void> _sendImageMessage(ImageSource source) async {
    final user = _currentUser;
    if (user == null) return;

    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (image == null) return;

      final messageId = FirebaseFirestore.instance
          .collection(widget.collectionPath)
          .doc(widget.channel.id)
          .collection('messages')
          .doc()
          .id;

      final file = File(image.path);
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('chat_images/${widget.channel.id}/$messageId.jpg');
      await storageRef.putFile(file);
      final imageUrl = await storageRef.getDownloadURL();

      await _sendMessage(
        imageUrl: imageUrl,
        messageType: 'image',
        messageId: messageId,
      );
    } catch (e) {
      print("Грешка при изпращане на снимка: $e");
    }
  }

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _attachmentOption(
                icon: Icons.photo_camera,
                label: 'Камера',
                onTap: () {
                  Navigator.pop(context);
                  _sendImageMessage(ImageSource.camera);
                },
              ),
              _attachmentOption(
                icon: Icons.photo_library,
                label: 'Галерия',
                onTap: () {
                  Navigator.pop(context);
                  _sendImageMessage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _attachmentOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
          child: IconButton(
            icon: Icon(icon, color: Theme.of(context).colorScheme.primary),
            onPressed: onTap,
          ),
        ),
        const SizedBox(height: 8),
        Text(label),
      ],
    );
  }

  void _setReplyTo(Map<String, dynamic> message, String messageId) {
    setState(() {
      _replyTo = {
        'messageId': messageId,
        'text': message['text'] ?? '',
        'imageUrl': message['imageUrl'],
        'senderName': message['senderName'] ?? 'Потребител',
        'isImage': message['messageType'] == 'image',
      };
    });
  }

  void _clearReply() {
    setState(() {
      _replyTo = null;
    });
  }

  void _showMessageActions({
    required Map<String, dynamic> message,
    required String messageId,
    required bool isMe,
  }) {
    final hasText = (message['text'] ?? '').toString().isNotEmpty;
    final isDeleted = message['deleted'] == true;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.reply),
                title: const Text('Отговори'),
                onTap: () {
                  Navigator.pop(context);
                  _setReplyTo(message, messageId);
                },
              ),
              if (hasText && !isDeleted)
                ListTile(
                  leading: const Icon(Icons.copy),
                  title: const Text('Копирай текста'),
                  onTap: () async {
                    Navigator.pop(context);
                    await Clipboard.setData(
                      ClipboardData(text: message['text'] ?? ''),
                    );
                  },
                ),
              if (isMe && hasText && !isDeleted)
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Редактирай'),
                  onTap: () {
                    Navigator.pop(context);
                    _startEditingMessage(messageId, message);
                  },
                ),
              if (isMe && !isDeleted)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Изтрий съобщението'),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteMessage(messageId);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.report_gmailerrorred),
                title: const Text('Докладвай'),
                onTap: () {
                  Navigator.pop(context);
                  _reportMessage(messageId, message);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      await FirebaseFirestore.instance
          .collection(widget.collectionPath)
          .doc(widget.channel.id)
          .collection('messages')
          .doc(messageId)
          .update({
        'deleted': true,
        'text': '',
        'imageUrl': null,
      });
      if (_editingMessageId == messageId && mounted) {
        _clearEditing();
      }
    } catch (e) {
      print("Грешка при изтриване на съобщение: $e");
    }
  }

  Future<void> _reportMessage(
      String messageId, Map<String, dynamic> message) async {
    final user = _currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('chat_reports').add({
        'channelId': widget.channel.id,
        'collectionPath': widget.collectionPath,
        'messageId': messageId,
        'reportedBy': user.uid,
        'reportedAt': FieldValue.serverTimestamp(),
        'messageSnapshot': message,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Съобщението е докладвано.')),
      );
    } catch (e) {
      print("Грешка при докладване: $e");
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
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection(widget.collectionPath)
            .doc(widget.channel.id)
            .snapshots(),
        builder: (context, chatSnapshot) {
          final chatData =
              chatSnapshot.data?.data() as Map<String, dynamic>? ?? {};
          final typingMap =
              (chatData['typing'] as Map?)?.cast<String, dynamic>() ?? {};
          final lastReadMap =
              (chatData['lastRead'] as Map?)?.cast<String, dynamic>() ?? {};
          final typingUsers = typingMap.entries
              .where((e) => e.value == true && e.key != _currentUser?.uid)
              .map((e) => e.key)
              .toList();
          final Timestamp? otherLastRead =
              !widget.channel.isGroup && widget.channel.otherUserId.isNotEmpty
                  ? lastReadMap[widget.channel.otherUserId] as Timestamp?
                  : null;

          return Column(
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
                        child: Text(
                            'Грешка при зареждане на съобщения: ${snapshot.error}'),
                      );
                    }

                    final data = snapshot.data;
                    if (data == null || data.docs.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline,
                                size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('Няма съобщения'),
                            Text('Бъдете първият, който пише',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      );
                    }

                    var messages = data.docs;
                    final currentUserId = _currentUser?.uid;

                    final latestMsg = messages.isNotEmpty
                        ? messages.first.data() as Map<String, dynamic>
                        : null;
                    final latestTs = latestMsg?['timestamp'] as Timestamp?;
                    _markChatRead(latestTs);

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final messageDoc = messages[index];
                        var msg = messageDoc.data() as Map<String, dynamic>;
                        bool isMe = currentUserId != null &&
                            msg['senderId'] == currentUserId;
                        bool isZoologist = msg['senderRole'] == 'zoologist';

                        // Timestamp logic
                        Timestamp? ts = msg['timestamp'] as Timestamp?;
                        DateTime messageDate = ts?.toDate() ?? DateTime.now();
                        String time = DateFormat('HH:mm').format(messageDate);

                        // Date Header logic
                        bool showDateHeader = false;
                        if (index == messages.length - 1) {
                          showDateHeader =
                              true; // Always show for oldest message
                        } else {
                          var prevMsg = messages[index + 1].data()
                              as Map<String, dynamic>;
                          Timestamp? prevTs =
                              prevMsg['timestamp'] as Timestamp?;
                          DateTime prevDate =
                              prevTs?.toDate() ?? DateTime.now();

                          if (messageDate.year != prevDate.year ||
                              messageDate.month != prevDate.month ||
                              messageDate.day != prevDate.day) {
                            showDateHeader = true;
                          }
                        }

                        final bool isSeen = !widget.channel.isGroup &&
                            isMe &&
                            otherLastRead != null &&
                            ts != null &&
                            otherLastRead.compareTo(ts) >= 0;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (showDateHeader) _buildDateHeader(messageDate),
                            GestureDetector(
                              onLongPress: () => _showMessageActions(
                                message: msg,
                                messageId: messageDoc.id,
                                isMe: isMe,
                              ),
                              child: _buildMessageBubble(
                                msg,
                                isMe,
                                time,
                                senderName: widget.channel.isGroup && !isMe
                                    ? msg['senderName']
                                    : null,
                                isZoologist: isZoologist,
                                isSeen: isSeen,
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              if (typingUsers.isNotEmpty)
                _buildTypingIndicator(typingUsers.length),
              // Поле за въвеждане на съобщение
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                color: Theme.of(context).colorScheme.surface,
                child: Column(
                  children: [
                    if (_editingMessageId != null) _buildEditPreview(),
                    if (_replyTo != null) _buildReplyPreview(),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: _showAttachmentSheet,
                        ),
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            focusNode: _messageFocusNode,
                            decoration: InputDecoration(
                              hintText: 'Напишете съобщение...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            onChanged: _onTextChanged,
                            onSubmitted: (value) => _sendTextMessage(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                          child: IconButton(
                            icon: Icon(
                              _editingMessageId != null
                                  ? Icons.check
                                  : Icons.send,
                            ),
                            onPressed: _sendTextMessage,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
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
          style: TextStyle(
              color: Colors.grey[800],
              fontSize: 12,
              fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // Изграждане на балон за съобщение
  Widget _buildMessageBubble(
    Map<String, dynamic> message,
    bool isMe,
    String time, {
    String? senderName,
    bool isZoologist = false,
    bool isSeen = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final bool isDeleted = message['deleted'] == true;
    final bool isEdited = message['isEdited'] == true;
    final String text = message['text'] ?? '';
    final String? imageUrl = message['imageUrl'] as String?;
    final String senderPhotoUrl = (message['senderPhotoUrl'] ?? '').toString();
    final Map<String, dynamic>? replyTo =
        message['replyTo'] as Map<String, dynamic>?;
    final bool hasImage = imageUrl != null && imageUrl.isNotEmpty;

    Widget avatar = CircleAvatar(
      radius: 16,
      backgroundColor: scheme.surfaceVariant,
      backgroundImage: senderPhotoUrl.isNotEmpty
          ? CachedNetworkImageProvider(senderPhotoUrl)
          : null,
      child: senderPhotoUrl.isEmpty
          ? Icon(
              isZoologist ? Icons.medical_services : Icons.person,
              color: scheme.primary,
              size: 16,
            )
          : null,
    );

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            avatar,
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (senderName != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          senderName,
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isZoologist) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.check_circle,
                              color: scheme.primary, size: 12),
                        ],
                      ],
                    ),
                  ),
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.68,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? scheme.primary : scheme.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isMe ? 20 : 0),
                      bottomRight: Radius.circular(isMe ? 0 : 20),
                    ),
                    border:
                        isMe ? null : Border.all(color: scheme.outlineVariant),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (replyTo != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isMe
                                ? scheme.primaryContainer
                                : scheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 3,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? scheme.onPrimaryContainer
                                      : scheme.primary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  replyTo['text']?.toString().isNotEmpty == true
                                      ? replyTo['text']
                                      : 'Отговор на снимка',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isMe
                                        ? scheme.onPrimaryContainer
                                        : scheme.onSurfaceVariant,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (isDeleted)
                        Text(
                          'Съобщението е изтрито',
                          style: TextStyle(
                            color: isMe
                                ? scheme.onPrimary
                                : scheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      else ...[
                        if (hasImage)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: imageUrl,
                              width: 220,
                              height: 160,
                              fit: BoxFit.cover,
                            ),
                          ),
                        if (text.isNotEmpty) ...[
                          if (hasImage) const SizedBox(height: 8),
                          Text(
                            text,
                            style: TextStyle(
                              color: isMe ? scheme.onPrimary : scheme.onSurface,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            time,
                            style: TextStyle(
                              color: isMe
                                  ? scheme.onPrimary.withOpacity(0.7)
                                  : scheme.onSurfaceVariant,
                              fontSize: 10,
                            ),
                          ),
                          if (isEdited) ...[
                            const SizedBox(width: 6),
                            Text(
                              'ред.',
                              style: TextStyle(
                                color: isMe
                                    ? scheme.onPrimary.withOpacity(0.75)
                                    : scheme.onSurfaceVariant,
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                          if (isMe) ...[
                            const SizedBox(width: 6),
                            Icon(
                              isSeen ? Icons.done_all : Icons.done,
                              size: 14,
                              color: isSeen
                                  ? scheme.onPrimary
                                  : scheme.onPrimary.withOpacity(0.75),
                            ),
                            if (isSeen) ...[
                              const SizedBox(width: 4),
                              Text(
                                'Видяно',
                                style: TextStyle(
                                  color: scheme.onPrimary,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            avatar,
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(int count) {
    final scheme = Theme.of(context).colorScheme;
    final text = count == 1 ? 'Някой пише...' : '$count души пишат...';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildEditPreview() {
    final scheme = Theme.of(context).colorScheme;
    final preview = (_editingOriginalText ?? '').trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withOpacity(0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.edit_outlined, color: scheme.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Редактирате съобщение',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (preview.isNotEmpty)
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _clearEditing,
          ),
        ],
      ),
    );
  }

  Widget _buildReplyPreview() {
    final scheme = Theme.of(context).colorScheme;
    final hasText =
        _replyTo != null && (_replyTo!['text']?.toString().isNotEmpty ?? false);
    final replyText = hasText ? _replyTo!['text'] : 'Отговор на снимка';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 28,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              replyText ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _clearReply,
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

  String _normalizeSearch(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  String _userNameFromData(Map<String, dynamic> data) {
    final raw = (data['username'] ?? data['name'] ?? data['displayName'] ?? '')
        .toString()
        .trim();
    if (raw.isNotEmpty) return raw;
    final email = (data['email'] ?? '').toString().trim();
    if (email.contains('@')) return email.split('@').first;
    return 'Потребител';
  }

  bool _matchesUserQuery(Map<String, dynamic> data, String normalizedQuery) {
    if (normalizedQuery.isEmpty) return true;
    final q = _normalizeSearch(normalizedQuery);
    final qNoSpace = q.replaceAll(' ', '');
    final parts = q.split(' ').where((part) => part.isNotEmpty);

    final name = _normalizeSearch(_userNameFromData(data));
    final email = _normalizeSearch((data['email'] ?? '').toString());
    final displayName =
        _normalizeSearch((data['displayName'] ?? '').toString());

    final fields = <String>[
      name,
      name.replaceAll(' ', ''),
      email,
      displayName,
    ];

    if (fields.any((field) => field.contains(q) || field.contains(qNoSpace))) {
      return true;
    }

    return parts.every((part) {
      final compactPart = part.replaceAll(' ', '');
      return fields.any((field) =>
          field.contains(part) || field.contains(compactPart));
    });
  }

  int _userSearchScore(Map<String, dynamic> data, String normalizedQuery) {
    if (normalizedQuery.isEmpty) return 0;
    final q = _normalizeSearch(normalizedQuery);
    final name = _normalizeSearch(_userNameFromData(data));
    final email = _normalizeSearch((data['email'] ?? '').toString());
    if (name == q) return 0;
    if (name.startsWith(q)) return 1;
    if (email.startsWith(q)) return 2;
    if (name.contains(q)) return 3;
    if (email.contains(q)) return 4;
    return 5;
  }

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
    if (_muteType == type &&
        _muteUntil != null &&
        _muteUntil!.isAfter(DateTime.now())) {
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
        SnackBar(
            content: Text(until == null
                ? 'Известията са включени'
                : 'Известията са заглушени')),
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

  Future<void> _notifyUser({
    required String userId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? payload,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': userId,
        'title': title,
        'body': body,
        'type': type,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        if (payload != null) 'payload': payload,
      });
    } catch (e) {
      print("Грешка при изпращане на известие: $e");
    }
  }

  Future<void> _postSystemMessage(String text) async {
    try {
      final channelRef = FirebaseFirestore.instance
          .collection('event_channels')
          .doc(widget.channel.id);
      await channelRef.collection('messages').add({
        'senderId': 'system',
        'senderName': 'Система',
        'senderRole': 'system',
        'senderPhotoUrl': '',
        'text': text,
        'messageType': 'text',
        'timestamp': FieldValue.serverTimestamp(),
        'deleted': false,
      });
      await channelRef.set({
        'lastMessage': text,
        'lastMessageType': 'text',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'lastMessageSenderId': 'system',
      }, SetOptions(merge: true));
    } catch (e) {
      print("Грешка при системно съобщение в група: $e");
    }
  }

  Future<void> _showMemberProfilePreview(String memberId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(memberId)
          .get();
      final data = userDoc.data() ?? <String, dynamic>{};
      final name =
          (data['username'] ?? data['name'] ?? 'Потребител').toString();
      final role = (data['role'] ?? 'user').toString();
      final email = (data['email'] ?? '').toString();
      final photo = (data['profilePictureUrl'] ?? '').toString();
      final selectedBadgeId = (data['selectedBadgeId'] ?? '').toString();
      final selectedBadge = findBadgeById(selectedBadgeId);

      if (!mounted) return;
      final scheme = Theme.of(context).colorScheme;
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 16),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: scheme.surfaceVariant,
                      backgroundImage: photo.isNotEmpty
                          ? CachedNetworkImageProvider(photo)
                          : null,
                      child: photo.isEmpty
                          ? Icon(
                              role == 'zoologist'
                                  ? Icons.medical_services
                                  : Icons.person,
                              color: scheme.primary,
                              size: 30,
                            )
                          : null,
                    ),
                    if (selectedBadge != null)
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: Container(
                          width: 22,
                          height: 22,
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: scheme.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: scheme.outlineVariant),
                          ),
                          child: Image.asset(
                            selectedBadge.assetPath,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  role == 'zoologist' ? 'Зоолог' : 'Потребител',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    email,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          );
        },
      );
    } catch (e) {
      print("Грешка при зареждане на профил: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Нямате достъп до този профил.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isMuted = _muteUntil != null && _muteUntil!.isAfter(DateTime.now());
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
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
                color: scheme.surface,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Име на групата',
                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                      if (_isAdmin)
                        IconButton(
                          icon: Icon(_isEditingName ? Icons.close : Icons.edit,
                              color: scheme.primary, size: 20),
                          onPressed: () =>
                              setState(() => _isEditingName = !_isEditingName),
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
                          icon: Icon(Icons.check, color: scheme.primary),
                          onPressed: _updateName,
                        ),
                      ],
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        _nameController.text,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text('Администратор',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.channel.adminId)
                  .get(),
              builder: (context, snapshot) {
                final scheme = Theme.of(context).colorScheme;
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data =
                    snapshot.data!.data() as Map<String, dynamic>? ?? {};
                final adminName =
                    (data['username'] ?? data['name'] ?? 'Администратор')
                        .toString();
                final adminRole = (data['role'] ?? 'user').toString();
                final adminPhoto = (data['profilePictureUrl'] ?? '').toString();

                return Container(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: ListTile(
                    onTap: () =>
                        _showMemberProfilePreview(widget.channel.adminId),
                    leading: CircleAvatar(
                      backgroundColor: scheme.surfaceVariant,
                      backgroundImage: adminPhoto.isNotEmpty
                          ? CachedNetworkImageProvider(adminPhoto)
                          : null,
                      child: adminPhoto.isEmpty
                          ? Icon(
                              adminRole == 'zoologist'
                                  ? Icons.medical_services
                                  : Icons.person,
                              color: scheme.primary,
                            )
                          : null,
                    ),
                    title: Text(
                      adminName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(adminRole == 'zoologist'
                        ? 'Администратор • Зоолог'
                        : 'Администратор'),
                    trailing:
                        Icon(Icons.workspace_premium, color: scheme.primary),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Заглушаване
            const Text('Известия',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                        isMuted
                            ? Icons.notifications_off_outlined
                            : Icons.notifications_active_outlined,
                        color: isMuted ? Colors.orange : scheme.primary),
                    title: Text(isMuted ? 'Заглушено' : 'Активни известия',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color:
                                isMuted ? Colors.orange[800] : scheme.primary)),
                    subtitle: isMuted
                        ? Text(
                            _muteType == 'always'
                                ? 'Известията са спрени'
                                : 'Известията са спрени до ${DateFormat('dd.MM HH:mm').format(_muteUntil!)}',
                            style: const TextStyle(color: Colors.red))
                        : const Text('Ще получавате известия за нови съобщения',
                            style: TextStyle(color: Colors.grey)),
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
                            avatar: Icon(Icons.notifications_active,
                                size: 16, color: scheme.primary),
                            backgroundColor: scheme.primaryContainer,
                            onPressed: () => _setMute(
                                const Duration(seconds: -1),
                                null), // Pass null type to clear selection
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Участници
            const Text('Участници',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            if (_isAdmin)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openAddMemberSheet,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Покани участник'),
                ),
              ),
            if (_isAdmin) const SizedBox(height: 12),
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('event_channels')
                  .doc(widget.channel.id)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final members =
                    List<String>.from(snapshot.data!['members'] ?? []);

                return Container(
                  decoration: BoxDecoration(
                    color: scheme.surface,
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
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(memberId)
                            .get(),
                        builder: (context, userSnap) {
                          if (!userSnap.hasData) return const SizedBox();
                          final userData =
                              userSnap.data!.data() as Map<String, dynamic>?;
                          // Check for 'username' first, then 'name', then fallback
                          final name = userData?['username'] ??
                              userData?['name'] ??
                              'Потребител';
                          final role = userData?['role'] ?? 'user';
                          final bool isMemberAdmin =
                              memberId == widget.channel.adminId;
                          final bool isZoologist = role == 'zoologist';
                          final selectedBadgeId =
                              (userData?['selectedBadgeId'] ?? '').toString();
                          final selectedBadge = findBadgeById(selectedBadgeId);

                          return ListTile(
                            leading: GestureDetector(
                              onTap: () => _showMemberProfilePreview(memberId),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .surfaceVariant,
                                    backgroundImage: (userData?[
                                                    'profilePictureUrl'] ??
                                                '')
                                            .toString()
                                            .isNotEmpty
                                        ? CachedNetworkImageProvider(
                                            (userData?['profilePictureUrl'] ??
                                                    '')
                                                .toString())
                                        : null,
                                    child:
                                        (userData?['profilePictureUrl'] ?? '')
                                                .toString()
                                                .isEmpty
                                            ? Icon(
                                                isZoologist
                                                    ? Icons.medical_services
                                                    : Icons.person,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                              )
                                            : null,
                                  ),
                                  if (selectedBadge != null)
                                    Positioned(
                                      right: -2,
                                      bottom: -2,
                                      child: Container(
                                        width: 20,
                                        height: 20,
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surface,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .outlineVariant,
                                          ),
                                        ),
                                        child: Image.asset(
                                          selectedBadge.assetPath,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(name),
                                if (isZoologist) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.check_circle,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    size: 16,
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(isMemberAdmin
                                ? 'Администратор'
                                : (isZoologist ? 'Зоолог' : 'Участник')),
                            trailing: _isAdmin && !isMemberAdmin
                                ? IconButton(
                                    icon: const Icon(
                                        Icons.remove_circle_outline,
                                        color: Colors.red),
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                        side: BorderSide(color: Colors.red[100]!)),
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
    final scheme = Theme.of(context).colorScheme;
    final bool isSelected = _muteType == type &&
        _muteUntil != null &&
        _muteUntil!.isAfter(DateTime.now());

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _setMute(duration, type),
      selectedColor: Colors.orange[100],
      checkmarkColor: Colors.orange[800],
      labelStyle: TextStyle(
        color: isSelected ? Colors.orange[900] : scheme.primary,
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: isSelected
            ? BorderSide(color: Colors.orange[300]!)
            : BorderSide.none,
      ),
    );
  }

  Future<void> _openAddMemberSheet() async {
    final channelDoc = await FirebaseFirestore.instance
        .collection('event_channels')
        .doc(widget.channel.id)
        .get();
    final currentMembers =
        List<String>.from(channelDoc.data()?['members'] ?? []);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        String localQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 48,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Покани участник',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        onChanged: (value) {
                          setModalState(() {
                            localQuery = _normalizeSearch(value);
                          });
                        },
                        decoration: const InputDecoration(
                          hintText: 'Търси потребител...',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }

                            final docs = snapshot.data!.docs.where((doc) {
                              if (currentMembers.contains(doc.id)) return false;
                              final data = doc.data() as Map<String, dynamic>;
                              return _matchesUserQuery(data, localQuery);
                            }).toList()
                              ..sort((a, b) {
                                final aData = a.data() as Map<String, dynamic>;
                                final bData = b.data() as Map<String, dynamic>;
                                final aScore =
                                    _userSearchScore(aData, localQuery);
                                final bScore =
                                    _userSearchScore(bData, localQuery);
                                if (aScore != bScore) {
                                  return aScore.compareTo(bScore);
                                }
                                final aName =
                                    _normalizeSearch(_userNameFromData(aData));
                                final bName =
                                    _normalizeSearch(_userNameFromData(bData));
                                return aName.compareTo(bName);
                              });

                            if (docs.isEmpty) {
                              return const Center(
                                  child: Text('Няма потребители за покана'));
                            }

                            return ListView.separated(
                              controller: scrollController,
                              itemCount: docs.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final doc = docs[index];
                                final data = doc.data() as Map<String, dynamic>;
                                final name = _userNameFromData(data);
                                final role = data['role'] ?? 'user';
                                final isZoologist = role == 'zoologist';
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .surfaceVariant,
                                    child: Icon(
                                      isZoologist
                                          ? Icons.medical_services
                                          : Icons.person,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(child: Text(name)),
                                      if (isZoologist) ...[
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.check_circle,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          size: 16,
                                        ),
                                      ],
                                    ],
                                  ),
                                  subtitle: Text(
                                      isZoologist ? 'Зоолог' : 'Потребител'),
                                  onTap: () async {
                                    Navigator.pop(context);
                                    await _addMember(doc.id);
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _addMember(String memberId) async {
    if (!_isAdmin) return;
    try {
      final currentId = _currentUserId;
      if (currentId == null || currentId == memberId) return;

      final inviterDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentId)
          .get();
      final inviterName = (inviterDoc.data()?['username'] ??
              inviterDoc.data()?['name'] ??
              'Администратор')
          .toString();

      final inviteeDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(memberId)
          .get();
      final inviteeName = (inviteeDoc.data()?['username'] ??
              inviteeDoc.data()?['name'] ??
              'Потребител')
          .toString();

      final eventQuery = await FirebaseFirestore.instance
          .collection('events')
          .where('channelId', isEqualTo: widget.channel.id)
          .limit(1)
          .get();
      final eventId =
          eventQuery.docs.isNotEmpty ? eventQuery.docs.first.id : '';

      final inviteId = '${widget.channel.id}_$memberId';
      await FirebaseFirestore.instance
          .collection('group_invitations')
          .doc(inviteId)
          .set({
        'channelId': widget.channel.id,
        'channelName': _nameController.text.trim(),
        'eventId': eventId,
        'inviterId': currentId,
        'inviterName': inviterName,
        'inviteeId': memberId,
        'inviteeName': inviteeName,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _notifyUser(
        userId: memberId,
        title: 'Покана за група',
        body: '$inviterName ви кани в "${_nameController.text.trim()}".',
        type: 'group_invite',
        payload: {
          'channelId': widget.channel.id,
          'inviteId': inviteId,
          'inviterId': currentId,
        },
      );

      await _postSystemMessage('$inviterName покани $inviteeName в групата.');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Поканата до $inviteeName е изпратена.')),
      );
    } catch (e) {
      print("Грешка при добавяне на участник: $e");
    }
  }

  Future<void> _removeMember(String memberId) async {
    if (!_isAdmin) return;
    try {
      final removedDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(memberId)
          .get();
      final removedName = (removedDoc.data()?['username'] ??
              removedDoc.data()?['name'] ??
              'Потребител')
          .toString();

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

      await _notifyUser(
        userId: memberId,
        title: 'Премахнати сте от група',
        body:
            'Администраторът ви премахна от "${_nameController.text.trim()}".',
        type: 'group_member_removed',
        payload: {'channelId': widget.channel.id},
      );

      await _postSystemMessage('$removedName беше премахнат от групата.');
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
          const SnackBar(
              content: Text(
                  'Администраторът не може да напусне групата. Моля, изтрийте събитието.')),
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
