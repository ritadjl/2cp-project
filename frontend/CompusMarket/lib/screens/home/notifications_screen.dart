import 'package:flutter/material.dart';
import '../../services/auth_services.dart';
import 'package:http/http.dart' as http;
import '../../services/api_config.dart';
import 'dart:convert';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/notifications/'),
        headers: await ApiConfig.getHeaders(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _notifications = data['results'] ?? data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load notifications';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load notifications';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.04,
                vertical: screenWidth * 0.03,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: screenWidth * 0.11,
                      height: screenWidth * 0.11,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF2F2F2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Notifications',
                        style: TextStyle(
                          fontSize: screenWidth * 0.065,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.11),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!))
                      : _notifications.isEmpty
                          ? const Center(child: Text('No notifications yet'))
                          : ListView.builder(
                              itemCount: _notifications.length,
                              itemBuilder: (context, index) {
                                final n = _notifications[index];
                                return ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: Color(0xFF1A73E8),
                                    child: Icon(Icons.notifications, color: Colors.white),
                                  ),
                                  title: Text(n['content'] ?? ''),
                                  subtitle: Text(n['created_at']?.toString().substring(0, 10) ?? ''),
                                  tileColor: n['is_read'] == true ? null : Colors.blue.withOpacity(0.05),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}