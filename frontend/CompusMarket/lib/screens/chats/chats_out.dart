import 'package:compusmarket/services/msg_service.dart';
import 'package:compusmarket/services/auth_services.dart';
import 'package:flutter/material.dart';
import '../chats/chat_in.dart';

class ChatsOutScreen extends StatefulWidget {
  const ChatsOutScreen({super.key});

  @override
  State<ChatsOutScreen> createState() => _ChatsOutScreenState();
}

class _ChatsOutScreenState extends State<ChatsOutScreen> {
  List conversations = [];
  bool isLoading = true;
  String? error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    try {
      final data = await MsgService.getConversations(AuthService.accessToken);
      if (!mounted) return;
      setState(() {
        conversations = data;
       if (data.isNotEmpty) {
    print('🟢 conv keys: ${(data[0] as Map).keys.toList()}');
    print('🟢 is_online value: ${data[0]['is_online']}');
    print('🟢 other_user_online: ${data[0]['other_user_online']}');
  }
  print('💬 CONV SAMPLE: ${data.isNotEmpty ? data[0] : "empty"}');
  isLoading = false;
});
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = 'Failed to load chats';
        isLoading = false;
      });
    }
  }

  Map<String, dynamic> _getOtherUser(Map<String, dynamic> conv) {
    final buyer = conv['buyer'] ?? {};
    final seller = conv['seller'] ?? {};
    if ((buyer['id'] ?? buyer['email']) == MsgService.currentUserId ||
        buyer['email'] == MsgService.currentUserEmail) {
      return seller;
    }
    return buyer;
  }

  String _getDisplayName(Map<String, dynamic> user) {
    final fullName = (user['full_name'] ?? '').toString().trim();
    if (fullName.isNotEmpty) return fullName;
    final first = (user['first_name'] ?? '').toString().trim();
    final last = (user['last_name'] ?? '').toString().trim();
    final combined = [first, last].where((s) => s.isNotEmpty).join(' ');
    if (combined.isNotEmpty) return combined;
    final username = (user['username'] ?? '').toString().trim();
    if (username.isNotEmpty) return username;
    return (user['email'] ?? 'Unknown').toString();
  }

  // ✅ Try all possible avatar field names
  String? _getAvatar(Map<String, dynamic> user) {
    for (final key in ['avatar', 'profile_picture', 'photo', 'image', 'picture']) {
      final val = user[key]?.toString() ?? '';
      if (val.isNotEmpty) return val;
    }
    return null;
  }

  // ✅ Read online status from conv or user object
  bool _getIsOnline(Map<String, dynamic> conv, Map<String, dynamic> otherUser) {
    return conv['is_online'] == true ||
        conv['other_user_online'] == true ||
        otherUser['is_online'] == true;
  }

  bool _isLastMessageFromMe(Map<String, dynamic> conv) {
    if (conv.containsKey('last_message_is_mine')) {
      return conv['last_message_is_mine'] == true;
    }
    final senderId = conv['last_message_sender_id']?.toString() ?? '';
    if (senderId.isNotEmpty) {
      return senderId == MsgService.currentUserId;
    }
    return (conv['unread_count'] ?? 0) == 0 &&
        (conv['last_message'] ?? '').toString().isNotEmpty;
  }

  bool _isLastMessageRead(Map<String, dynamic> conv) {
    return conv['last_message_is_read'] ?? false;
  }

  String _formatConvTime(Map<String, dynamic> conv) {
    final raw = conv['last_message_time']?.toString() ??
        conv['updated_at']?.toString() ??
        conv['created_at']?.toString() ??
        '';
    if (raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(msgDay).inDays;
    if (diff == 0) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (diff < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[dt.weekday - 1];
    } else {
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: Text(
          "Chats",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: screenWidth * 0.07,
            fontFamily: 'Inter',
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.menu, size: screenWidth * 0.065),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: EdgeInsets.symmetric(
                vertical: screenHeight * 0.02, horizontal: screenWidth * 0.03),
            height: screenHeight * 0.065,
            child: TextField(
               onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              expands: true,
              maxLines: null,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(screenWidth * 0.08),
                  borderSide: BorderSide.none,
                ),
                hintText: "Search",
                hintStyle:
                    TextStyle(fontSize: screenWidth * 0.045, color: Colors.grey),
                prefixIcon: Icon(Icons.search,
                    color: Colors.grey, size: screenWidth * 0.06),
                contentPadding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.04, vertical: 0),
                fillColor: const Color(0xffF0F0F0),
                filled: true,
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(error!,
                                style: const TextStyle(color: Colors.grey)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _loadConversations,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : conversations.isEmpty
                        ? const Center(child: Text('No conversations yet'))
                        : RefreshIndicator(
                            onRefresh: _loadConversations,
                            child:  Builder(builder: (context) {
                  // ✅ ADD THIS RIGHT HERE, before ListView
                  final filtered = conversations.where((conv) {
                    final conv_ = conv as Map<String, dynamic>;
                    final other = _getOtherUser(conv_);
                    final name = _getDisplayName(other).toLowerCase();
                    final msg = (conv_['last_message'] ?? '').toString().toLowerCase();
                    return name.contains(_searchQuery) || msg.contains(_searchQuery);
                  }).toList();

                  if (filtered.isEmpty) {
            return const Center(child: Text('No results found'));
          }
                           return ListView.builder(
                              
                               itemCount: filtered.length,    
                              itemBuilder: (context, index) {
                                final conv =
                                    filtered[index] as Map<String, dynamic>;
                                final otherUser = _getOtherUser(conv);
                                final name = _getDisplayName(otherUser);
                                final avatarUrl = _getAvatar(otherUser);
                                // ✅ isOnline now computed correctly inside builder
                                final isOnline = _getIsOnline(conv, otherUser);
                                final lastMessage =
                                    (conv['last_message'] ?? '').toString();
                                final unread = conv['unread_count'] ?? 0;
                                final conversationId = conv['id'];
                                final isFromMe = _isLastMessageFromMe(conv);
                                final isRead = _isLastMessageRead(conv);
                                final time = _formatConvTime(conv);

                                final announcement = conv['announcement'] != null
                                    ? Map<String, dynamic>.from(
                                        conv['announcement'])
                                    : null;
                                final productPhoto =
                                    announcement?['photo']?.toString() ?? '';

                                     print('💬 unread for $name: $unread | isFromMe: $isFromMe');

                                return Column(
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ChatsInScreen(
                                              name: name,
                                              image: avatarUrl,
                                              isNetwork: avatarUrl != null,
                                              isOnline: isOnline, // ✅ fixed
                                              conversationId: conversationId,
                                              announcement: announcement,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: screenWidth * 0.04,
                                          vertical: screenHeight * 0.012,
                                        ),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 26,
                                              backgroundColor: Colors.grey[300],
                                              backgroundImage: avatarUrl != null
                                                  ? NetworkImage(avatarUrl)
                                                  : null,
                                              child: avatarUrl == null
                                                  ? Icon(Icons.person,
                                                      size: 28,
                                                      color: Colors.grey[600])
                                                  : null,
                                            ),
                                            SizedBox(width: screenWidth * 0.03),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          name,
                                                          style: const TextStyle(
                                                            fontFamily: 'Inter',
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 15,
                                                          ),
                                                          overflow:
                                                              TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                      if (time.isNotEmpty)
                                                        Text(
                                                          time,
                                                          style: TextStyle(
                                                            fontSize:
                                                                screenWidth * 0.03,
                                                            color: unread > 0
                                                                ? const Color(
                                                                    0xff2853af)
                                                                : Colors.grey,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Row(
                                                    children: [
                                                      if (isFromMe &&
                                                          lastMessage
                                                              .isNotEmpty) ...[
                                                        Icon(
                                                          isRead
                                                              ? Icons.done_all
                                                              : Icons.done,
                                                          size:
                                                              screenWidth * 0.038,
                                                          color: isRead
                                                              ? Colors.blue
                                                              : Colors.grey,
                                                        ),
                                                        SizedBox(
                                                            width:
                                                                screenWidth * 0.01),
                                                      ],
                                                      Expanded(
                                                        child: Text(
                                                          lastMessage.isNotEmpty
                                                              ? lastMessage
                                                              : (announcement != null
                                                                  ? '📦 ${announcement['title'] ?? 'Product'}'
                                                                  : ''),
                                                          maxLines: 1,
                                                          overflow:
                                                              TextOverflow.ellipsis,
                                                          style: TextStyle(
  fontFamily: 'Inter',
  fontSize: screenWidth * 0.033,
  fontWeight: (!isFromMe && unread > 0)
      ? FontWeight.bold
      : FontWeight.normal,
  color: (!isFromMe && unread > 0)
      ? Colors.black87  // ✅ dark for unread
      : Colors.grey,    // ✅ grey for read/sent
),
                                                        ),
                                                      ),
                                                      SizedBox(
                                                          width:
                                                              screenWidth * 0.02),
                                                      Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment.end,
                                                        children: [
                                                          if (unread > 0)
                                                            Container(
                                                              width: 20,
                                                              height: 20,
                                                              decoration:
                                                                  const BoxDecoration(
                                                                color: Color(
                                                                    0xff2853af),
                                                                shape:
                                                                    BoxShape.circle,
                                                              ),
                                                              child: Center(
                                                                child: Text(
                                                                  unread.toString(),
                                                                  style: const TextStyle(
                                                                      color: Colors
                                                                          .white,
                                                                      fontSize: 11,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold),
                                                                ),
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                      // if (productPhoto
                                                      //     .isNotEmpty) ...[
                                                      //   SizedBox(
                                                      //       width:
                                                      //           screenWidth * 0.02),
                                                      //   ClipRRect(
                                                      //     borderRadius:
                                                      //         BorderRadius.circular(
                                                      //             6),
                                                      //     child: Image.network(
                                                      //       productPhoto,
                                                      //       width:
                                                      //           screenWidth * 0.11,
                                                      //       height:
                                                      //           screenWidth * 0.11,
                                                      //       fit: BoxFit.cover,
                                                      //       errorBuilder: (_,
                                                      //               __,
                                                      //               ___) =>
                                                      //           const SizedBox
                                                      //               .shrink(),
                                                      //     ),
                                                      //   ),
                                                      // ],
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Divider(
                                      height: 1,
                                      indent: 80,
                                      color: Colors.grey[200],
                                    ),
                                  ],
                                );
                              },
                            );}
                          ),),
          ),
        ],
      ),
    );
  }
}