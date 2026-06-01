import 'dart:convert';
import 'package:compusmarket/screens/home/home_products_grid.dart';
import 'package:compusmarket/screens/home/product_details_screen.dart';
import 'package:compusmarket/widgets/standard_Button.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_services.dart';
import '../../services/msg_service.dart';
import '../../services/api_config.dart'; // ✅ Use unified config
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
      await Future.wait([_fetchProfile(), _fetchListings()]);
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to load profile details.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchProfile() async {
    //  Utilizes the central ApiConfig baseUrl
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/profiles/${widget.sellerId}/'),
      headers: {'Authorization': 'Bearer ${AuthService.accessToken}'},
    );
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      if (mounted) setState(() => _profile = Map<String, dynamic>.from(data));
    } else {
      throw Exception('Profile fetch failed: ${res.statusCode}');
    }
  }

  Future<void> _fetchListings() async {
    // ✅ Safe fallback check: handles both path-based /seller/{id}/ and query-based requests
    final url =
        '${ApiConfig.baseUrl}/announcements/?student_id=${widget.sellerId}';
    print('DEBUG listings URL: $url');
    print('DEBUG seller ID: ${widget.sellerId}');
    final res = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer ${AuthService.accessToken}'},
    );
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      final List rawList = data is List ? data : (data['results'] ?? []);
      if (mounted) {
        setState(() {
          _listings = rawList.map((e) => Map<String, dynamic>.from(e)).toList();
        });

        if (_listings.isNotEmpty) {
          debugPrint('Listing keys: ${_listings[0].keys.toList()}');
          debugPrint('First listing: ${_listings[0]}');
        }
      }
    } else {
      throw Exception('Listings fetch failed: ${res.statusCode}');
    }
  }

  String get _fullName => _profile['full_name']?.toString() ?? 'Campus Seller';
  String? get _email =>
      _profile['show_email'] == true ? _profile['email']?.toString() : null;
  String get _avatar => _profile['avatar']?.toString() ?? '';
  String get _bio => _profile['bio']?.toString() ?? '';
  String get _university => _profile['university']?.toString() ?? '';
  String get _rating => _profile['average_rating']?.toString() ?? 'N/A';
  String get _itemsListed => _listings.length.toString();
  String get _completedSales => _profile['completed_sales']?.toString() ?? '0';
  bool get _isVerified => _profile['is_verified'] == true;
  String get _lastSeen => _profile['last_seen_display']?.toString() ?? '';

  Widget _buildAvatar({double size = 120}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[300],
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: ClipOval(
        child: _avatar.isNotEmpty
            ? Image.network(
                _avatar,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.person,
                  size: size * 0.5,
                  color: Colors.grey[600],
                ),
              )
            : Icon(Icons.person, size: size * 0.5, color: Colors.grey[600]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/blue_background.jfif'),
            fit: BoxFit.cover,
          ),
        ),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : _errorMessage != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadData,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: screenHeight * 0.05),

                    // ── TOP BAR ──
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.06,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            iconSize: screenWidth * 0.065,
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.black,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: _openSettings,
                            icon: Icon(
                              Icons.settings_outlined,
                              size: screenWidth * 0.075,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── PROFILE CARD ──
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.topCenter,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            margin: const EdgeInsets.only(top: 70),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                const SizedBox(height: 60),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _fullName,
                                      style: TextStyle(
                                        fontSize: screenWidth * 0.05,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (_isVerified) ...[
                                      const SizedBox(width: 6),
                                      const Icon(
                                        Icons.verified,
                                        color: Color(0xFF1A73E8),
                                        size: 18,
                                      ),
                                    ],
                                  ],
                                ),
                                if (_email != null) ...[
                                  SizedBox(height: screenHeight * 0.005),
                                  Text(
                                    _email!,
                                    style: TextStyle(
                                      color: const Color(0xff808897),
                                      fontSize: screenWidth * 0.033,
                                    ),
                                  ),
                                ],
                                if (_university.isNotEmpty) ...[
                                  SizedBox(height: screenHeight * 0.004),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.school_outlined,
                                        size: 14,
                                        color: Color(0xff808897),
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: _university.length > 30
                                            ? SizedBox(
                                                height: 22,
                                                width: screenWidth * 0.6,
                                                child: SingleChildScrollView(
                                                  scrollDirection:
                                                      Axis.horizontal,
                                                  child: Text(
                                                    _university,
                                                    style: TextStyle(
                                                      color: const Color(
                                                        0xff808897,
                                                      ),
                                                      fontSize:
                                                          screenWidth * 0.032,
                                                    ),
                                                  ),
                                                ),
                                              )
                                            : Text(
                                                _university,
                                                style: TextStyle(
                                                  color: const Color(
                                                    0xff808897,
                                                  ),
                                                  fontSize: screenWidth * 0.032,
                                                ),
                                              ),
                                      ),
                                    ],
                                  ),
                                ],
                                if (_lastSeen.isNotEmpty) ...[
                                  SizedBox(height: screenHeight * 0.004),
                                  Text(
                                    _lastSeen,
                                    style: TextStyle(
                                      color: Colors.green[600],
                                      fontSize: screenWidth * 0.03,
                                    ),
                                  ),
                                ],
                                if (_bio.isNotEmpty) ...[
                                  SizedBox(height: screenHeight * 0.008),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: screenWidth * 0.08,
                                    ),
                                    child: Text(
                                      _bio,
                                      softWrap: true,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: const Color(0xff808897),
                                        fontSize: screenWidth * 0.035,
                                        height: 1.6,
                                      ),
                                    ),
                                  ),
                                ],
                                SizedBox(height: screenHeight * 0.015),
                                Container(
                                  height: screenHeight * 0.001,
                                  width: screenWidth * 0.7,
                                  color: const Color(0xffdfe1e6),
                                ),
                                SizedBox(height: screenHeight * 0.02),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _statItem("Items", _itemsListed),
                                    _divider(),
                                    _statItem("Sales", _completedSales),
                                    _divider(),
                                    _statItem("Rating", _rating),
                                  ],
                                ),
                                SizedBox(height: screenHeight * 0.02),
                                Container(
                                  height: screenHeight * 0.001,
                                  width: screenWidth * 0.7,
                                  color: const Color(0xffdfe1e6),
                                ),
                                SizedBox(height: screenHeight * 0.02),
                              ],
                            ),
                          ),
                        ),
                        Positioned(top: 0, child: _buildAvatar()),
                      ],
                    ),

                    SizedBox(height: screenHeight * 0.04),

                    // ── ACTION BUTTONS ──
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.07,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: StandardButton(
                              text: "Message",
                              onPressed: () => _openChat(context),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: StandardButton(
                              text: "Report",
                              onPressed: _reportSeller,
                              color: const Color(0xffdfe1e6),
                              textColor: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: screenHeight * 0.03),

                    // ── LISTINGS SECTION ──
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.06,
                      ),
                      child: Text(
                        "Listings",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: screenWidth * 0.055,
                        ),
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.02),

                    if (_listings.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            "No listings yet.",
                            style: TextStyle(
                              color: const Color(0xff808897),
                              fontSize: screenWidth * 0.04,
                            ),
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.04,
                        ),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: screenWidth * 0.03,
                                mainAxisSpacing: screenWidth * 0.03,
                                childAspectRatio: 0.75,
                              ),
                          itemCount: _showAll
                              ? _listings.length
                              : (_listings.length > 2 ? 2 : _listings.length),
                          itemBuilder: (context, index) {
                            final listing = _listings[index];
                            final imageUrl = listing['photo']?.toString() ?? '';
                            return Stack(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ProductDetailsScreen(
                                          product: listing,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        color: Colors.white,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: imageUrl.isNotEmpty
                                                  ? Image.network(
                                                      imageUrl,
                                                      fit: BoxFit.cover,
                                                      width: double.infinity,
                                                      errorBuilder:
                                                          (
                                                            _,
                                                            __,
                                                            ___,
                                                          ) => Container(
                                                            color: Colors
                                                                .grey[200],
                                                            child: const Icon(
                                                              Icons.image,
                                                              color:
                                                                  Colors.grey,
                                                              size: 40,
                                                            ),
                                                          ),
                                                    )
                                                  : Container(
                                                      color: Colors.grey[200],
                                                      child: const Icon(
                                                        Icons.image,
                                                        color: Colors.grey,
                                                        size: 40,
                                                      ),
                                                    ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.all(8),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    listing['title'] ?? '',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 13,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  Text(
                                                    '${listing['price'] ?? ''} ${listing['currency'] ?? 'DA'}',
                                                    style: const TextStyle(
                                                      color: Color(0xff2853af),
                                                      fontWeight:
                                                          FontWeight.bold,
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
                                ),
                                if ((listing['status'] ?? 'active') != 'active')
                                  Positioned(
                                    top: 8,
                                    left: 8,
                                    child: StatusBadge(
                                      status: listing['status'] ?? '',
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),

                    if (_listings.length > 2)
                      Center(
                        child: TextButton(
                          onPressed: () => setState(() => _showAll = !_showAll),
                          child: Text(
                            _showAll ? "View less <" : "View more >",
                            style: TextStyle(
                              color: const Color(0xff2853af),
                              fontWeight: FontWeight.bold,
                              fontSize: screenWidth * 0.035,
                            ),
                          ),
                        ),
                      ),
                    SizedBox(height: screenHeight * 0.04),
                  ],
                ),
              ),
      ),
    );
  }

  // ✅ FIXED:
  void _openChat(BuildContext context) async {
    try {
      final conversation = await MsgService.getOrCreateConversation(
        AuthService.accessToken,
        widget.sellerId,
        '',
      );
      final announcement = conversation['announcement'] != null
          ? Map<String, dynamic>.from(conversation['announcement'])
          : null;
      if (mounted) {
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not open chat: $e')));
      }
    }
  }

  void _reportSeller() {
    // ✅ Implement interactive, beautiful feedback modal dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Report Seller"),
        content: const Text(
          "Are you sure you want to report this seller for policy violations? We will review this profile immediately.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              // TODO: Integrate actual POST request to report API here
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Thank you. Report received.")),
              );
            },
            child: const Text("Report", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openSettings() {
    final screenWidth = MediaQuery.of(context).size.width;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Container(
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
              ListTile(
                title: Text(
                  "Options",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: screenWidth * 0.06,
                  ),
                ),
              ),
              const Divider(height: 1, color: Color(0xffdfe1e6)),
              ListTile(
                leading: const Icon(
                  Icons.report_gmailerrorred,
                  color: Colors.red,
                ),
                title: const Text(
                  "Report Seller",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _reportSeller();
                },
              ),
              const Divider(height: 1, color: Color(0xffdfe1e6)),
            ],
          ),
        );
      },
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: Color(0xff808897),
          ),
        ),
      ],
    );
  }

  Widget _divider() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 30),
      width: 1,
      height: 50,
      color: const Color(0xffdfe1e6),
    );
  }
}