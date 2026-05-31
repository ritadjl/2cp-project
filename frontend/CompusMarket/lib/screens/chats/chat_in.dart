import 'package:flutter/material.dart';
import '../../services/auth_services.dart';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../services/msg_service.dart';
import '../../screens/home/product_details_screen.dart';
import 'package:http/http.dart' as http;

class ChatsInScreen extends StatefulWidget {
  final String name;
  final String? image;
  final bool isNetwork;
  final bool isOnline;
  final int conversationId;
  final Map<String, dynamic>? announcement; // ✅ NEW

  const ChatsInScreen({
    super.key,
    required this.name,
    this.image,
    required this.isNetwork,
    required this.isOnline,
    required this.conversationId,
    this.announcement, // ✅ NEW
  });

  @override
  State<ChatsInScreen> createState() => _ChatsInScreenState();
}

class _ChatsInScreenState extends State<ChatsInScreen> {
  List<dynamic> messages = [];
  bool isLoading = true;
  dynamic _replyingTo;
    late bool _isOnline;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  WebSocketChannel? _channel;

  @override
  void initState() {
    super.initState();
     _isOnline = widget.isOnline;

     print('🟢 isOnline on open: ${widget.isOnline}');
    
    _loadMessages();
    _markAsRead();
    _connectWebSocket();
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
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
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse(
            MsgService.wsUrl(widget.conversationId, AuthService.accessToken)),
      );
      _channel!.stream.listen(
        (data) {
          final newMessage = jsonDecode(data);
         if (newMessage['type'] == 'online_status') {
  setState(() => _isOnline = newMessage['is_online'] == true);
  return;
}
 setState(() => messages.add(newMessage));
    _scrollToBottom();
},
        onError: (e) => debugPrint('WebSocket error: $e'),
        onDone: () => debugPrint('WebSocket closed'),
      );
    } catch (e) {
      debugPrint('WebSocket connection failed: $e');
    }
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

  // ✅ Product card at top of chat — like Instagram/Facebook Marketplace
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
            // Product image
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: photo.isNotEmpty
                  ? Image.network(
                      photo,
                      width: screenWidth * 0.14,
                      height: screenWidth * 0.14,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _productImagePlaceholder(screenWidth),
                    )
                  : _productImagePlaceholder(screenWidth),
            ),
            SizedBox(width: screenWidth * 0.03),
            // Title + price
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
                border:
                    Border.all(color: const Color(0xff808897), width: 1.5),
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

      // ✅ Body: product card pinned at top, messages below
      body: Column(
        children: [
          _buildProductCard(screenWidth, screenHeight),
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
    onLongPress: () => _showMessageOptions(context, msg, isMe),
    child: Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(maxWidth: screenWidth * 0.75),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xff2853af) : Colors.grey[300],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(15),
            topRight: const Radius.circular(15),
            bottomLeft: isMe ? const Radius.circular(15) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(15),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // ✅ Reply preview inside bubble
            if (msg['reply_to'] != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: isMe
                      ? Colors.blue[800]
                      : Colors.grey[400],
                  borderRadius: BorderRadius.circular(10),
                  border: Border(
                    left: BorderSide(
                      color: isMe ? Colors.lightBlueAccent : const Color(0xff2853af),
                      width: 3,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      msg['reply_to']['sender_name'] ?? '',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isMe ? Colors.lightBlueAccent : const Color(0xff2853af),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      msg['reply_to']['content'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isMe ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),

            // ✅ Message text
            Text(
              msg['content'] ?? '',
              style: TextStyle(
                fontSize: screenWidth * 0.04,
                color: isMe ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  time,
                  style: TextStyle(
                    fontSize: screenWidth * 0.027,
                    color: isMe ? Colors.white70 : Colors.grey[600],
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    isRead ? Icons.done_all : Icons.done,
                    size: screenWidth * 0.035,
                    color: isRead ? Colors.lightBlueAccent : Colors.white70,
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
      // ✅ Reply preview bar above input
      if (_replyingTo != null)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                icon: const Icon(Icons.close, size: 18, color: Color(0xff2853af)),
                onPressed: () => setState(() => _replyingTo = null),
              ),
            ],
          ),
        ),

      // ✅ Input row
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                prefixIcon: IconButton(
                  onPressed: () {},
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
              Navigator.pop(context); // close sheet
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
            Navigator.pop(context); // close dialog
            try {
              await MsgService.deleteConversation(
                AuthService.accessToken,
                widget.conversationId,
              );
              if (mounted) {
                Navigator.pop(context); // go back to chat list
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
            // ✅ Message preview at top of popup
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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

            // ✅ Reply option
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                Navigator.pop(context);
                setState(() => _replyingTo = msg);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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

            // ✅ Delete option — only for own messages
            if (isMe)
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(msg);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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

            // ✅ Cancel
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
      Uri.parse('${MsgService.baseUrl}/messaging/conversations/${widget.conversationId}/messages/$messageId/delete/'),
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
  if (text.isEmpty || _channel == null) return;

  final payload = <String, dynamic>{'message': text};
  if (_replyingTo != null) {
    payload['reply_to_id'] = _replyingTo['id'];
  }

  _channel!.sink.add(jsonEncode(payload));
  _controller.clear();
  setState(() => _replyingTo = null);
}
}
