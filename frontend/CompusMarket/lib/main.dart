import 'package:compusmarket/screens/authentication/ON_Boadring.dart';
import 'package:compusmarket/screens/home/home_screen.dart';
import 'package:compusmarket/services/profile_api_service.dart';
import 'package:compusmarket/services/auth_services.dart';
import 'package:compusmarket/services/msg_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('📩 Foreground message: ${message.notification?.title}');
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('📩 Notification tapped: ${message.data}');
  });

  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  final prefs = await SharedPreferences.getInstance();
  final savedToken = prefs.getString('auth_token') ?? '';
  final savedRefresh = prefs.getString('refresh_token') ?? '';
  final rememberMe = prefs.getBool('remember_me') ?? false;

  ProfileApiService.token = savedToken;
  AuthService.accessToken = savedToken;
  AuthService.refreshToken = savedRefresh;

  if (savedToken.isNotEmpty) {
    try {
      final me = await AuthService.getMe();
      MsgService.currentUserId = me['id']?.toString() ?? '';
    } catch (_) {}
  }

 if (savedRefresh.isNotEmpty) {
  try {
    await AuthService.refreshAccessToken();
  } catch (_) {}
}

  runApp(MyApp(goHome: rememberMe && savedToken.isNotEmpty));
}

class MyApp extends StatelessWidget {
  final bool goHome;
  const MyApp({super.key, required this.goHome});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CompusMarket',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Inter'),
      home: goHome ? const HomeScreen() : const OnBoadringScreen(),
    );
  }
}