import 'package:flutter/material.dart';
import '../../services/auth_services.dart';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../services/msg_service.dart';
import '../../screens/home/product_details_screen.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class ChatsInScreen extends StatefulWidget {
  final String name;
  final String? image;
  final bool isNetwork;
  final bool isOnline;
  final int conversationId;
  final Map<String, dynamic>? announcement;

  const ChatsInScreen({
    super.key,
    required this.name,
    this.image,
    required this.isNetwork,
    required this.isOnline,
    required this.conversationId,
    this.announcement,
  });

  @override
  State<ChatsInScreen> createState() => _ChatsInScreenState();
}

class _ChatsInScreenState extends State<ChatsInScreen> {
  List<dynamic> messages = [];
  bool isLoading = true;
  dynamic _replyingTo;
  late bool _isOnline;
  bool _isSendingImage = false;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  WebSocketChannel? _channel;

  // ✅ FIX 1: Retry counter to avoid infinite reconnect loops
  int _wsRetryCount = 0;
  static const int _maxRetries = 5;
  bool _wsConnected = false;

  @override
  void initState() {
    super.initState();
    _isOnline = widget.isOnline;
    print('🟢 isOnline on open: ${widget.isOnline}');
    _loadMessages();
    _markAsRead();
    // ✅ FIX 2: Wake server before connecting WebSocket (Render free tier)
    _wakeServerThenConnect();
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ✅ FIX 3: Ping any HTTP endpoint first to wake Render from sleep
  Future<void> _wakeServerThenConnect() async {
    try {
      await http.get(
        Uri.parse('${MsgService.baseUrl}/messaging/conversations/'),
        headers: {'Authorization': 'Bearer ${AuthService.accessToken}'},
      ).timeout(const Duration(seconds: 10));
    } catch (_) {
      // Server might still be waking — proceed anyway
    }
    if (mounted) _connectWebSocket();
  }

  Future<void> _loadMessages() async {
    try {
      final data = await MsgService.getMessages(
          AuthService.accessToken, widget.conversationId);
      setState(() {
        messages = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _markAsRead() async {
    try {
      await MsgService.markAsRead(
          AuthService.accessToken, widget.conversationId);
    } catch (_) {}
  }

  

  void _connectWebSocket() {
    // ✅ FIX 4: Close old channel cleanly before reconnecting
    _channel?.sink.close();
    _wsConnected = false;
final uri = MsgService.wsUri(widget.conversationId, AuthService.accessToken);
print('🔌 WS URI: $uri | scheme: ${uri.scheme} | host: ${uri.host} | port: ${uri.port}');
_channel = WebSocketChannel.connect(uri);
    try {
      final uri = MsgService.wsUri(widget.conversationId, AuthService.accessToken);
      _channel = WebSocketChannel.connect(uri);

      // ✅ FIX 5: Wait for handshake before listening — prevents the crash
      _channel!.ready.then((_) {
        if (!mounted) return;
        setState(() {
          _wsConnected = true;
          _wsRetryCount = 0; // reset on successful connect
        });

        _channel!.stream.listen(
          (data) {
            if (!mounted) return;
            final newMessage = jsonDecode(data);
            if (newMessage['type'] == 'online_status') {
              setState(() => _isOnline = newMessage['is_online'] == true);
              return;
            }
            setState(() => messages.add(newMessage));
            _scrollToBottom();
          },
          onError: (e) {
            debugPrint('WebSocket error: $e');
            setState(() => _wsConnected = false);
            _scheduleReconnect();
          },
          onDone: () {
            debugPrint('WebSocket closed');
            if (mounted) setState(() => _wsConnected = false);
            _scheduleReconnect();
          },
          cancelOnError: false, // ✅ FIX 6: Don't kill stream on single error
        );
      }).catchError((e) {
        // ✅ FIX 7: Handshake failed (server still waking) — retry gracefully
        debugPrint('WebSocket handshake failed: $e');
        if (mounted) setState(() => _wsConnected = false);
        _scheduleReconnect();
      });
    } catch (e) {
      debugPrint('WebSocket connection failed: $e');
      if (mounted) setState(() => _wsConnected = false);
      _scheduleReconnect();
    }
  }

  // ✅ FIX 8: Centralized retry with cap to avoid infinite loops
  void _scheduleReconnect() {
    if (!mounted) return;
    if (_wsRetryCount >= _maxRetries) {
      debugPrint('WebSocket max retries reached. Giving up.');
      return;
    }
    _wsRetryCount++;
    final delay = Duration(seconds: _wsRetryCount * 3); // 3s, 6s, 9s...
    debugPrint('WebSocket retry $_wsRetryCount in ${delay.inSeconds}s');
    Future.delayed(delay, () {
      if (mounted) _connectWebSocket();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  bool _isMe(dynamic message) {
    final senderEmail = message['sender']?['email'] ?? '';
    final senderId = message['sender']?['id']?.toString() ?? '';
    return senderEmail == MsgService.currentUserEmail ||
        (MsgService.currentUserId.isNotEmpty &&
            senderId == MsgService.currentUserId);
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return '';
    final dt = DateTime.tryParse(timestamp)?.toLocal();
    if (dt == null) return '';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildProductCard(double screenWidth, double screenHeight) {
    final ann = widget.announcement;
    if (ann == null) return const SizedBox.shrink();

    final photo = ann['photo']?.toString() ?? '';
    final title = ann['title']?.toString() ?? '';
    final price = ann['price']?.toString() ?? '';
    final currency = ann['currency']?.toString() ?? 'DA';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailsScreen(product: ann),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.04,
          vertical: screenHeight * 0.012,
        ),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          border: Border(
            bottom: BorderSide(color: Colors.grey[200]!, width: 1),
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: photo.isNotEmpty
                  ? Image.network(
                      photo,
                      width: screenWidth * 0.14,
                      height: screenWidth * 0.14,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _productImagePlaceholder(screenWidth),
                    )
                  : _productImagePlaceholder(screenWidth),
            ),
            SizedBox(width: screenWidth * 0.03),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: screenWidth * 0.038,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$price $currency',
                    style: TextStyle(
                      color: const Color(0xff2853af),
                      fontWeight: FontWeight.bold,
                      fontSize: screenWidth * 0.035,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _productImagePlaceholder(double screenWidth) {
    return Container(
      width: screenWidth * 0.14,
      height: screenWidth * 0.14,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.image, color: Colors.grey),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey[400]),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xff808897), width: 1.5),
              ),
              child: Icon(Icons.more_horiz, size: screenWidth * 0.065),
            ),
            onPressed: () => _showOptionsSheet(context, screenWidth),
          ),
        ],
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          iconSize: screenWidth * 0.065,
          icon: const Icon(Icons.arrow_back, color: Colors.black),
        ),
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: widget.image != null
                      ? (widget.isNetwork
                          ? NetworkImage(widget.image!)
                          : AssetImage(widget.image!) as ImageProvider)
                      : null,
                  child: widget.image == null
                      ? Icon(Icons.person, size: 22, color: Colors.grey[600])
                      : null,
                ),
                if (_isOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: screenWidth * 0.028,
                      height: screenWidth * 0.028,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: screenWidth * 0.03),
            Flexible(
              child: Text(
                widget.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.bold,
                  fontSize: screenWidth * 0.045,
                ),
              ),
            ),
          ],
        ),
      ),

      body: Column(
        children: [
          _buildProductCard(screenWidth, screenHeight),
          // ✅ FIX 9: Show reconnecting banner when WS is down
          if (!_wsConnected && !isLoading)
            Container(
              width: double.infinity,
              color: Colors.orange[100],
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Connecting...',
                    style: TextStyle(
                      fontSize: screenWidth * 0.032,
                      color: Colors.orange[800],
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                    ? const Center(
                        child: Text('No messages yet',
                            style: TextStyle(color: Colors.grey)),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.only(
                            top: 15, left: 15, right: 15, bottom: 15),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[messages.length - 1 - index];
                          final isMe = _isMe(msg);
                          final time = _formatTime(msg['timestamp']);
                          final isRead = msg['is_read'] ?? false;

                          return GestureDetector(
                            onLongPress: () =>
                                _showMessageOptions(context, msg, isMe),
                            child: Align(
                              alignment: isMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin:
                                    const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                constraints: BoxConstraints(
                                    maxWidth: screenWidth * 0.75),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? const Color(0xff2853af)
                                      : Colors.grey[300],
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(15),
                                    topRight: const Radius.circular(15),
                                    bottomLeft: isMe
                                        ? const Radius.circular(15)
                                        : Radius.zero,
                                    bottomRight: isMe
                                        ? Radius.zero
                                        : const Radius.circular(15),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: isMe
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    if (msg['reply_to'] != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        margin:
                                            const EdgeInsets.only(bottom: 6),
                                        decoration: BoxDecoration(
                                          color: isMe
                                              ? Colors.blue[800]
                                              : Colors.grey[400],
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border(
                                            left: BorderSide(
                                              color: isMe
                                                  ? Colors.lightBlueAccent
                                                  : const Color(0xff2853af),
                                              width: 3,
                                            ),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              msg['reply_to']['sender_name'] ??
                                                  '',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: isMe
                                                    ? Colors.lightBlueAccent
                                                    : const Color(0xff2853af),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              msg['reply_to']['content'] ?? '',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isMe
                                                    ? Colors.white70
                                                    : Colors.black54,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                    Builder(
                                      builder: (context) {
                                        final content =
                                            msg['content']?.toString() ?? '';
                                        final imageUrl =
                                            msg['image_url']?.toString() ?? '';
                                        final isImage = imageUrl.isNotEmpty ||
                                            (content.startsWith('https://') &&
                                                (content.endsWith('.jpg') ||
                                                    content.endsWith('.jpeg') ||
                                                    content.endsWith('.png') ||
                                                    content.endsWith('.webp')));

                                        if (isImage) {
                                          return ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            child: Image.network(
                                              imageUrl.isNotEmpty
                                                  ? imageUrl
                                                  : content,
                                              width: screenWidth * 0.55,
                                              fit: BoxFit.cover,
                                              loadingBuilder:
                                                  (_, child, progress) =>
                                                      progress == null
                                                          ? child
                                                          : Container(
                                                              width: screenWidth *
                                                                  0.55,
                                                              height: 150,
                                                              color: Colors
                                                                  .grey[300],
                                                              child: const Center(
                                                                child:
                                                                    CircularProgressIndicator(
                                                                  color: Color(
                                                                      0xff2853af),
                                                                  strokeWidth:
                                                                      2,
                                                                ),
                                                              ),
                                                            ),
                                              errorBuilder: (_, __, ___) =>
                                                  Container(
                                                width: screenWidth * 0.55,
                                                height: 100,
                                                color: Colors.grey[300],
                                                child: const Icon(
                                                    Icons.broken_image,
                                                    color: Colors.grey),
                                              ),
                                            ),
                                          );
                                        }
                                        return Text(
                                          content,
                                          style: TextStyle(
                                            fontSize: screenWidth * 0.04,
                                            color: isMe
                                                ? Colors.white
                                                : Colors.black,
                                          ),
                                        );
                                      },
                                    ),

                                    const SizedBox(height: 3),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          time,
                                          style: TextStyle(
                                            fontSize: screenWidth * 0.027,
                                            color: isMe
                                                ? Colors.white70
                                                : Colors.grey[600],
                                          ),
                                        ),
                                        if (isMe) ...[
                                          const SizedBox(width: 4),
                                          Icon(
                                            isRead
                                                ? Icons.done_all
                                                : Icons.done,
                                            size: screenWidth * 0.035,
                                            color: isRead
                                                ? Colors.lightBlueAccent
                                                : Colors.white70,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),

      bottomNavigationBar: Container(
        color: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.035,
          vertical: screenHeight * 0.0084,
        ),
        margin: EdgeInsets.only(bottom: screenHeight * 0.05),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyingTo != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xffEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                  border: const Border(
                    left: BorderSide(color: Color(0xff2853af), width: 4),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Replying to',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xff2853af),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            (_replyingTo['content'] ?? '').toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          size: 18, color: Color(0xff2853af)),
                      onPressed: () => setState(() => _replyingTo = null),
                    ),
                  ],
                ),
              ),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      prefixIcon: _isSendingImage
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xff2853af),
                                ),
                              ),
                            )
                          : IconButton(
                              onPressed: _showImagePickerSheet,
                              icon: const Icon(Icons.add),
                              iconSize: screenWidth * 0.06,
                            ),
                      hintText: "Write a message...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      fillColor: const Color(0xffF0F0F0),
                      filled: true,
                    ),
                  ),
                ),
                SizedBox(width: screenWidth * 0.04),
                CircleAvatar(
                  backgroundColor: const Color(0xff2853af),
                  radius: 25,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showOptionsSheet(BuildContext context, double screenWidth) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'Delete Chat',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(context);
              },
            ),
            const Divider(height: 1, color: Color(0xffdfe1e6)),
            ListTile(
              leading: const Icon(Icons.cancel_outlined, color: Colors.grey),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Chat'),
        content: const Text(
          'Are you sure you want to delete this conversation? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await MsgService.deleteConversation(
                  AuthService.accessToken,
                  widget.conversationId,
                );
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Chat deleted')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete: $e')),
                  );
                }
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showMessageOptions(BuildContext context, dynamic msg, bool isMe) {
    showDialog(
      context: context,
      barrierColor: Colors.black26,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: const Color(0xffEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  (msg['content'] ?? '').toString(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xff2853af),
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _replyingTo = msg);
                },
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: const Row(
                    children: [
                      Icon(Icons.reply, color: Color(0xff2853af), size: 20),
                      SizedBox(width: 12),
                      Text(
                        'Reply',
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xff2853af),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, color: Color(0xffF0F0F0)),
              if (isMe)
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteMessage(msg);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    child: const Row(
                      children: [
                        Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        SizedBox(width: 12),
                        Text(
                          'Delete',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: const Row(
                    children: [
                      Icon(Icons.close, color: Colors.grey, size: 20),
                      SizedBox(width: 12),
                      Text(
                        'Cancel',
                        style: TextStyle(fontSize: 15, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteMessage(dynamic msg) async {
    final messageId = msg['id'];
    try {
      final res = await http.delete(
        Uri.parse(
            '${MsgService.baseUrl}/messaging/conversations/${widget.conversationId}/messages/$messageId/delete/'),
        headers: {'Authorization': 'Bearer ${AuthService.accessToken}'},
      );
      if (res.statusCode == 204) {
        setState(() => messages.removeWhere(
            (m) => m['id'].toString() == messageId.toString()));
      } else if (res.statusCode == 403) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("You can't delete this message")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    // ✅ FIX 10: Block send if WS not connected — avoids crash on closed channel
    if (text.isEmpty || _channel == null || !_wsConnected) {
      if (!_wsConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Still connecting, please wait a moment...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    final payload = <String, dynamic>{'message': text};
    if (_replyingTo != null) {
      payload['reply_to_id'] = _replyingTo['id'];
    }

    _channel!.sink.add(jsonEncode(payload));
    _controller.clear();
    setState(() => _replyingTo = null);
  }

  void _showImagePickerSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildPickerOption(
                icon: Icons.camera_alt,
                label: 'Camera',
                onTap: () {
                  Navigator.pop(context);
                  _pickAndSendImage(ImageSource.camera);
                },
              ),
              _buildPickerOption(
                icon: Icons.photo_library,
                label: 'Gallery',
                onTap: () {
                  Navigator.pop(context);
                  _pickAndSendImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickerOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xff2853af).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xff2853af), size: 30),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    // ✅ FIX 11: Also guard image send against disconnected WS
    if (!_wsConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Still connecting, please wait...')),
      );
      return;
    }

    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: source);
    if (picked == null) return;

    setState(() => _isSendingImage = true);

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
            '${MsgService.baseUrl}/messaging/conversations/${widget.conversationId}/messages/image/'),
      );
      request.headers['Authorization'] =
          'Bearer ${AuthService.accessToken}';
      request.files
          .add(await http.MultipartFile.fromPath('image', picked.path));

      final streamed = await request.send();
      final res = await http.Response.fromStream(streamed);

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        final imageUrl = data['image_url']?.toString() ?? '';
        if (imageUrl.isNotEmpty && _channel != null && _wsConnected) {
          _channel!.sink.add(jsonEncode({'message': imageUrl}));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to send image')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingImage = false);
    }
  }
}