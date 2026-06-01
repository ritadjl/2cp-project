import 'dart:convert';
import 'package:compusmarket/services/auth_services.dart';
import 'package:http/http.dart' as http;

class MsgService {
  static const String baseUrl = 'https://twocp-project-1-gtam.onrender.com/api';  
  static const String wsBase = 'wss://twocp-project-1-gtam.onrender.com/ws';

  static String currentUserEmail = '';
  static String currentUserId = '';  // String because Me returns UUID

  static Map<String, String> headers(String token) => {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  static Future<List<dynamic>> getConversations(String token) async {
    final res = await http.get(
      Uri.parse('$baseUrl/messaging/conversations/'),
      headers: headers(token),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to load conversations');
  }

  static Future<List<dynamic>> getMessages(String token, int conversationId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/messaging/conversations/$conversationId/messages/'),
      headers: headers(token),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to load messages');
  }

  static Future<void> markAsRead(String token, int conversationId) async {
    await http.patch(
      Uri.parse('$baseUrl/messaging/conversations/$conversationId/read/'),
      headers: headers(token),
    );
  }

  static Future<void> deleteConversation(String token, int conversationId) async {
  final res = await http.delete(
    Uri.parse('$baseUrl/messaging/conversations/$conversationId/delete/'),
    headers: headers(token),
  );
  if (res.statusCode == 204) return;
  if (res.statusCode == 403) throw Exception('Not your conversation');
  if (res.statusCode == 404) throw Exception('Conversation not found');
  throw Exception('Failed to delete conversation: ${res.statusCode}');
}

static Future<void> saveDeviceToken(String token, String fcmToken) async {
  await http.post(
    Uri.parse('$baseUrl/messaging/devices/token/'),
    headers: headers(token),
    body: jsonEncode({'device_token': fcmToken}),
  );
}

  // ✅ Fixed — use Uri constructor, not Uri.parse()
static Uri wsUri(int conversationId, String token) => Uri(
  scheme: 'wss',
  host: 'twocp-project-1-gtam.onrender.com',
  path: '/ws/chat/$conversationId/',
  queryParameters: {'token': token},
);
     static Future<Map<String, dynamic>> getOrCreateConversation(
  String token,
  String sellerId,
  String announcementId,
) async {
  // ✅ Step 1: Check if a conversation with this seller already exists
  try {
    final existing = await getConversations(token);
    for (final conv in existing) {
      final seller = conv['seller'];
      final buyer = conv['buyer'];
      // Match by seller id or buyer id (depending on who we are)
      if (seller != null &&
          (seller['id']?.toString() == sellerId ||
              seller['email']?.toString() == sellerId)) {
        return conv as Map<String, dynamic>;
      }
      if (buyer != null &&
          (buyer['id']?.toString() == sellerId ||
              buyer['email']?.toString() == sellerId)) {
        return conv as Map<String, dynamic>;
      }
    }
  } catch (_) {
    // If checking fails, proceed to create
  }

  // ✅ Step 2: Only create if none found
  final res = await http.post(
    Uri.parse('$baseUrl/messaging/conversations/start/'),
    headers: headers(token),
    body: jsonEncode({
      'seller_id': sellerId,
  'announcement_id': int.tryParse(announcementId) ?? 0,
    }),
  );
  print('DEBUG start conversation body: ${res.body}');
  if (res.statusCode == 200 || res.statusCode == 201) {
    return jsonDecode(res.body);
  }
  throw Exception('Failed to create conversation: ${res.body}');
}

}