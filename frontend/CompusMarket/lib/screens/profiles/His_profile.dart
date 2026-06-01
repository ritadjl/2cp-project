
import 'dart:convert';
import 'package:compusmarket/screens/home/home_products_grid.dart';
import 'package:compusmarket/screens/home/product_details_screen.dart';
//import 'package:compusmarket/widgets/standard_Button.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_services.dart';
import '../../services/msg_service.dart';
import '../../services/api_config.dart';
import '../chats/chat_in.dart';

class HisProfileScreen extends StatefulWidget {
  final String sellerId;

  const HisProfileScreen({super.key, required this.sellerId});

  @override
  State<HisProfileScreen> createState() => _HisProfileScreenState();
}

class _HisProfileScreenState extends State<HisProfileScreen> {
  bool _showAll = false;
  bool _isLoading = true;
  String? _errorMessage;

  Map<String, dynamic> _profile = {};
  List<Map<String, dynamic>> _listings = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Future.wait([
        _fetchProfile(),
        _fetchListings(),
      ]);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load profile details.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchProfile() async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/profiles/${widget.sellerId}/'),
      headers: {
        'Authorization': 'Bearer ${AuthService.accessToken}',
      },
    );

    if (res.statusCode == 200) {
      final data = json.decode(res.body);

      if (mounted) {
        setState(() {
          _profile = Map<String, dynamic>.from(data);
        });
      }
    }
  }

  Future<void> _fetchListings() async {
    final url =
        '${ApiConfig.baseUrl}/announcements/?student_id=${widget.sellerId}';

    final res = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer ${AuthService.accessToken}',
      },
    );

    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      final List rawList =
          data is List ? data : (data['results'] ?? []);

      if (mounted) {
        setState(() {
          _listings = rawList
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        });
      }
    }
  }

  String get _fullName =>
      _profile['full_name']?.toString() ?? 'Campus Seller';

  String? get _email =>
      _profile['show_email'] == true
          ? _profile['email']?.toString()
          : null;

  String get _avatar =>
      _profile['avatar']?.toString() ?? '';

  String get _bio =>
      _profile['bio']?.toString() ?? '';

  String get _university =>
      _profile['university']?.toString() ?? '';

  String get _rating =>
      _profile['average_rating']?.toString() ?? 'N/A';

  String get _itemsListed => _listings.length.toString();

  String get _completedSales =>
      _profile['completed_sales']?.toString() ?? '0';

  bool get _isVerified =>
      _profile['is_verified'] == true;

  String get _lastSeen =>
      _profile['last_seen_display']?.toString() ?? '';

  Widget _buildAvatar({double size = 120}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[300],
      ),
      child: ClipOval(
        child: _avatar.isNotEmpty
            ? Image.network(
                _avatar,
                fit: BoxFit.cover,
              )
            : Icon(
                Icons.person,
                size: size * 0.5,
                color: Colors.grey,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight =
        MediaQuery.of(context).size.height;
    final screenWidth =
        MediaQuery.of(context).size.width;

    return Scaffold(
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: screenHeight * 0.06),

                  _buildAvatar(),

                  const SizedBox(height: 16),

                  Text(
                    _fullName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  if (_email != null)
                    Text(_email!),

                  const SizedBox(height: 24),

                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                    ),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics:
                          const NeverScrollableScrollPhysics(),
                      itemCount: _showAll
                          ? _listings.length
                          : (_listings.length > 2
                              ? 2
                              : _listings.length),
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.75,
                      ),
                      itemBuilder: (context, index) {
                        final listing =
                            _listings[index];

                        final imageUrl =
                            listing['photo']
                                    ?.toString() ??
                                '';

                        return Stack(
                          children: [
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ProductDetailsScreen(
                                      product: listing,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                decoration:
                                    BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(
                                          16),
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black
                                          .withOpacity(
                                              0.1),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(
                                          16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,
                                    children: [
                                      Expanded(
                                        child: imageUrl
                                                .isNotEmpty
                                            ? Image.network(
                                                imageUrl,
                                                fit: BoxFit
                                                    .cover,
                                                width: double
                                                    .infinity,
                                              )
                                            : Container(
                                                color: Colors
                                                        .grey[
                                                    200],
                                                child:
                                                    const Icon(
                                                  Icons
                                                      .image,
                                                ),
                                              ),
                                      ),
                                      Padding(
                                        padding:
                                            const EdgeInsets
                                                .all(8),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment
                                                  .start,
                                          children: [
                                            Text(
                                              listing['title'] ??
                                                  '',
                                              maxLines:
                                                  1,
                                              overflow:
                                                  TextOverflow
                                                      .ellipsis,
                                            ),
                                            const SizedBox(
                                                height:
                                                    4),
                                            Text(
                                              '${listing['price'] ?? ''} DA',
                                              style:
                                                  const TextStyle(
                                                fontWeight:
                                                    FontWeight.bold,
                                                color: Color(
                                                    0xff2853af),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if ((listing['status'] ??
                                    'active') !=
                                'active')
                              Positioned(
                                top: 8,
                                left: 8,
                                child: StatusBadge(
                                  status:
                                      listing['status'] ??
                                          '',
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),

                  if (_listings.length > 2)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _showAll = !_showAll;
                        });
                      },
                      child: Text(
                        _showAll
                            ? 'View less <'
                            : 'View more >',
                      ),
                    ),

                  SizedBox(height: screenHeight * 0.04),
                ],
              ),
            ),
    );
  }

  void _openChat(BuildContext context) async {
    final conversation =
        await MsgService.getOrCreateConversation(
      AuthService.accessToken,
      widget.sellerId,
      '',
    );

    final announcement =
        conversation['announcement'] != null
            ? Map<String, dynamic>.from(
                conversation['announcement'],
              )
            : null;

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatsInScreen(
          name: _fullName,
          conversationId: conversation['id'],
          isNetwork: false,
          isOnline: false,
          announcement: announcement,
        ),
      ),
    );
  }

  void _reportSeller() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Report received"),
      ),
    );
  }

  void _openSettings() {}
}
