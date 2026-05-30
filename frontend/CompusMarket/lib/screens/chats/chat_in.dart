import 'package:flutter/material.dart';
import '../../services/auth_services.dart';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../services/msg_service.dart';
import '../../screens/home/product_details_screen.dart';

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
    late bool _isOnline;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  WebSocketChannel? _channel;

  @override
  void initState() {
    super.initState();
     _isOnline = widget.isOnline;
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

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty || _channel == null) return;
    _channel!.sink.add(jsonEncode({'message': text}));
    _controller.clear();
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

                          return Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
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
                                  Text(
                                    msg['content'] ?? '',
                                    style: TextStyle(
                                      fontSize: screenWidth * 0.04,
                                      color:
                                          isMe ? Colors.white : Colors.black,
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
                          );
                        },
                      ),
          ),
        ],
      ),

      bottomNavigationBar: Container(
        color: Colors.transparent,
        padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.035,
            vertical: screenHeight * 0.0084),
        margin: EdgeInsets.only(bottom: screenHeight * 0.05),
        child: Row(
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
              backgroundColor: Colors.black,
              radius: 25,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: _sendMessage,
              ),
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
}
