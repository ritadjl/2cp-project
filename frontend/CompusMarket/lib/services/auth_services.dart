import 'dart:convert';
import 'package:compusmarket/services/profile_api_service.dart';
import 'package:compusmarket/services/msg_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

const String baseUrl = 'https://twocp-project-1-gtam.onrender.com/api/auth';

class AuthService {
  static String accessToken = '';
  static String refreshToken = '';

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      accessToken = data['access'];
      ProfileApiService.token = data['access'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', data['access']);
      await prefs.setString('refresh_token', data['refresh']);
      refreshToken = data['refresh'];
      final me = await getMe();
      MsgService.currentUserId = me['id']?.toString() ?? '';
      MsgService.currentUserEmail = me['email']?.toString() ?? '';

      print('DEBUG currentUserEmail: ${MsgService.currentUserEmail}');
      print('DEBUG currentUserId: ${MsgService.currentUserId}');

      // ✅ FCM token
      try {
        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          await MsgService.saveDeviceToken(accessToken, fcmToken);
          print('✅ FCM token saved');
        }
      } catch (e) {
        print('❌ FCM token error: $e');
      }

      return data; // ✅ only one return, at the very end
    } else {
      throw Exception('Login failed');
    }
  }

  static Future<List<dynamic>> getUniversities() async {
    final response = await http.get(Uri.parse('$baseUrl/universities/'));
    print('🌐 Universities status: ${response.statusCode}');
    print('🌐 Universities body: ${response.body}');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load universities');
    }
  }

  static Future<void> register(
    String email,
    String password,
    String fullName,
    String universityId,
    String phoneNumber,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'full_name': fullName,
        'university_id': universityId,
        'phone_number': phoneNumber,
      }),
    );
    if (response.headers['content-type']?.contains('application/json') ==
        true) {
      final data = jsonDecode(response.body);
      print('Success: $data');
    } else {
      print('Server error: ${response.statusCode}');
    }
    print('📦 Register response: ${response.body}');
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Register failed: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> getMe() async {
    final response = await http.get(
      Uri.parse('$baseUrl/me/'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to get user info');
  }

  static Future<void> logout() async {
    await http.post(
      Uri.parse('$baseUrl/logout/'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'refresh': refreshToken}),
    );
    accessToken = '';
    refreshToken = '';
    MsgService.currentUserId = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('refresh_token');
    await prefs.remove('saved_email');
    await prefs.remove('saved_password');
    await prefs.setBool('remember_me', false);
  }

  static Future<void> verifyEmail(String email, String code) async {
    final response = await http.post(
      Uri.parse('$baseUrl/verify-email/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'code': code}),
    );
    if (response.statusCode != 200) {
      throw Exception('Invalid or expired code');
    }
    final data = jsonDecode(response.body);
    accessToken = data['access'];
    ProfileApiService.token = data['access'];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', data['access']);
    await prefs.setString('refresh_token', data['refresh']);
    refreshToken = data['refresh'];
    final me = await getMe();
    MsgService.currentUserId = me['id']?.toString() ?? '';
  }

  static Future<void> forgotPassword(String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/forgot-password/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    if (response.statusCode != 200) {
      throw Exception('Email not found');
    }
  }

  static Future<void> resetPassword(
    String email,
    String code,
    String newPassword,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/reset-password/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'code': code,
        'new_password': newPassword,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Reset failed');
    }
  }

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId:
        '487741193559-9e1h8s176ahqaar9so7uapeliu3vrfq9.apps.googleusercontent.com',
  );

  static Future<Map<String, dynamic>> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google sign in cancelled');
    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) throw Exception('Failed to get ID token');
    final response = await http.post(
      Uri.parse('$baseUrl/google/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id_token': idToken}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      accessToken = data['access'];
      refreshToken = data['refresh'];
      ProfileApiService.token = data['access'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', data['access']);
      await prefs.setString('refresh_token', data['refresh']);
      final me = await getMe();
      MsgService.currentUserId = me['id']?.toString() ?? '';
      return data;
    } else {
      throw Exception('Google login failed: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> signInWithApple() async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );
    final response = await http.post(
      Uri.parse('$baseUrl/apple/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'id_token': credential.identityToken,
        'email': credential.email ?? '',
        'full_name':
            '${credential.givenName ?? ''} ${credential.familyName ?? ''}'
                .trim(),
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      accessToken = data['access'];
      refreshToken = data['refresh'];
      ProfileApiService.token = data['access'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', data['access']);
      await prefs.setString('refresh_token', data['refresh']);
      final me = await getMe();
      MsgService.currentUserId = me['id']?.toString() ?? '';
      return data;
    } else {
      throw Exception('Apple login failed: ${response.body}');
    }
  }

  static Future<void> refreshAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final refresh = prefs.getString('refresh_token') ?? refreshToken;
    if (refresh.isEmpty) return;

    final response = await http.post(
      Uri.parse('$baseUrl/refresh/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh': refresh}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      accessToken = data['access'];
      ProfileApiService.token = data['access'];
      await prefs.setString('auth_token', data['access']);
    } else {
      accessToken = '';
      await prefs.remove('auth_token');
      await prefs.remove('refresh_token');
    }
  }
}
