// ignore: file_names
import 'package:compusmarket/screens/authentication/sign_in.dart';
import 'package:compusmarket/screens/home/add_new_product.dart';
import 'package:compusmarket/screens/profiles/Edit_profil.dart';
import 'package:compusmarket/services/announcement_service.dart';
import 'package:compusmarket/services/profile_api_service.dart';
import 'package:compusmarket/services/auth_services.dart';
import 'package:flutter/material.dart';
import 'package:compusmarket/screens/home/home_products_grid.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  String _userName = "";
  String _userEmail = "";
  String _userPhone = "";
  String _userBio = "";
  String _userUniversityId = "";
  String _userUniversityName = "";
  int _itemsCount = 0;
  int _dealsCount = 0;
  double _averageRating = 0.0;

  List<dynamic> _myListings = [];
  List<dynamic> _universities = [];

  bool _showAll = false;
  bool _notificationsEnabled = false;
  bool _showEmail = false;
  bool _isLoading = true;

  String? _avatarUrl;

  File? _avatarImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadAll();
    globalRealProductsNotifier.addListener(_onNewProduct);
  }

  @override
  void dispose() {
    globalRealProductsNotifier.removeListener(_onNewProduct);
    super.dispose();
  }

  void _onNewProduct() {
    if (mounted) _loadAll();
  }

  Future<void> _loadAll() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ProfileApiService.getMyProfile(),
        AuthService.getMe().catchError((_) => <String, dynamic>{}),
        AnnouncementService.getMyAnnouncements().catchError((e) {
          print('❌ getMyAnnouncements error: $e');
          return <dynamic>[];
        }),
        AuthService.getUniversities().catchError((_) => <dynamic>[]),
      ]);

      final profile = results[0] as Map<String, dynamic>;
      final authMe = results[1] as Map<String, dynamic>;
      final listings = results[2] as List<dynamic>;
      final universities = results[3] as List<dynamic>;

      debugPrint('AUTH ME DATA: $authMe');
      debugPrint('PROFILE KEYS: ${profile.keys.toList()}');
      debugPrint('PROFILE DATA: $profile');

      if (mounted)
        setState(() {
          _userName = profile['full_name'] ?? profile['name'] ?? '';
          _userEmail = authMe['email'] ?? '';
          _userPhone = authMe['phone'] ?? profile['phone'] ?? '';
          _userBio = profile['bio'] ?? '';
          _userUniversityId = authMe['university']?['id']?.toString() ?? '';
          _userUniversityName = authMe['university']?['name'] ?? '';
          _notificationsEnabled = profile['notifications_enabled'] ?? false;
          _showEmail = profile['show_email'] ?? false;
          _myListings = listings;
          _itemsCount = listings.length;
          // ✅ Read completed_sales from profile instead of deals list
          _dealsCount = profile['completed_sales'] ?? 0;
          _averageRating =
              double.tryParse(profile['average_rating']?.toString() ?? '0') ??
              0.0;
          _universities = universities;
          _avatarUrl = profile['avatar'] ?? authMe['profile_picture'];
        });
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load profile. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleNotifications(
    bool value,
    StateSetter setModalState,
  ) async {
    setModalState(() => _notificationsEnabled = value);
    setState(() => _notificationsEnabled = value);
    try {
      await ProfileApiService.updateMyProfile(notificationsEnabled: value);
    } catch (e) {
      setModalState(() => _notificationsEnabled = !value);
      setState(() => _notificationsEnabled = !value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update notifications.')),
        );
      }
    }
  }

  Future<void> _toggleShowEmail(bool value, StateSetter setModalState) async {
    setModalState(() => _showEmail = value);
    setState(() => _showEmail = value);
    try {
      await ProfileApiService.updateMyProfile(showEmail: value);
    } catch (e) {
      setModalState(() => _showEmail = !value);
      setState(() => _showEmail = !value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update email visibility.')),
        );
      }
    }
  }

  Future<void> _handleLogout() async {
    Navigator.pop(context);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_email');
    await prefs.remove('saved_password');
    await prefs.setBool('remember_me', false);

    try {
      await AuthService.logout();
    } catch (e) {
      debugPrint('Logout error: $e');
    }

    globalRealProductsNotifier.value = [];
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => SignInScreen(key: UniqueKey())),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final visibleListings = _showAll
        ? _myListings
        : _myListings.take(2).toList();

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
                child: CircularProgressIndicator(color: Color(0xff2853af)),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: MediaQuery.of(context).padding.top + 10),

                    // ── Title + Settings ──
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.06,
                      ),
                      child: Row(
                        children: [
                          Text(
                            "Profil",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: screenWidth * 0.07,
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

                    // ── Avatar + Card ──
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.topCenter,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            margin: const EdgeInsets.only(top: 90),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.5),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                const SizedBox(height: 35),
                                Text(
                                  _userName,
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.05,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (_showEmail) ...[
                                  SizedBox(height: screenHeight * 0.005),
                                  Text(
                                    _userEmail,
                                    style: TextStyle(
                                      color: const Color(0xff808897),
                                      fontSize: screenWidth * 0.033,
                                    ),
                                  ),
                                ],
                                SizedBox(height: screenHeight * 0.005),
                                if (_userBio.isNotEmpty)
                                  Text(
                                    _userBio,
                                    softWrap: true,
                                    style: TextStyle(
                                      color: const Color(0xff808897),
                                      fontSize: screenWidth * 0.035,
                                      height: 1.6,
                                    ),
                                  ),
                                SizedBox(height: screenHeight * 0.01),
                                Container(
                                  height: screenHeight * 0.001,
                                  width: screenWidth * 0.7,
                                  color: const Color(0xffdfe1e6),
                                ),
                                SizedBox(height: screenHeight * 0.02),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _statItem("Items", "$_itemsCount"),
                                    _divider(),
                                    _statItem("Deals", "$_dealsCount"),
                                    _divider(),
                                    _statItem(
                                      "Rating",
                                      _averageRating > 0
                                          ? _averageRating.toStringAsFixed(1)
                                          : "N/A",
                                    ),
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

                        // ── Avatar ──
                        Positioned(
                          top: 0,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey[400],
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 8,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: _avatarImage != null
                                  ? Image.file(_avatarImage!, fit: BoxFit.cover)
                                  : _avatarUrl != null
                                  ? Image.network(
                                      _avatarUrl!,
                                      fit: BoxFit.cover,
                                    )
                                  : Icon(
                                      Icons.person,
                                      size: 60,
                                      color: Colors.grey[600],
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: screenHeight * 0.04),

                    // ── My Listings ──
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.06,
                      ),
                      child: Text(
                        "My Listings",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: screenWidth * 0.05,
                        ),
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.02),

                    if (_myListings.isEmpty)
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
                          itemCount: visibleListings.length,
                          itemBuilder: (context, index) {
                            final listing = visibleListings[index];

                            final rawPriceValue = listing['priceValue'];
                            final rawPriceStr =
                                listing['price']?.toString() ?? '0';
                            final parsedPrice = rawPriceValue is num
                                ? rawPriceValue.toDouble()
                                : (double.tryParse(
                                        rawPriceStr.replaceAll(
                                          RegExp(r'[^0-9.]'),
                                          '',
                                        ),
                                      ) ??
                                      0.0);

                            final product = {
                              'name': listing['title'] ?? listing['name'] ?? '',
                              'price': rawPriceStr,
                              'priceValue': parsedPrice,
                              'category': listing['category'] ?? '',
                              'rating': (listing['average_rating'] ??
                                      listing['rating'] ??
                                      0.0)
                                  .toDouble(),
                              'isRated': false,
                              'image': listing['image'] ??
                                  listing['photos']?[0]?['image'] ??
                                  'assets/images/products/airpods.jpg',
                              'isReal': true,
                              'isUserAdded': false,
                              'id': listing['id'],
                              'sellerId': listing['seller']?['id'],
                              'description': listing['description'] ?? '',
                              'location': listing['location']?.toString() ??
                                  listing['university']?.toString() ??
                                  '',
                              'university': listing['university']?.toString() ??
                                  listing['location']?.toString() ??
                                  '',
                              'images': listing['images'] ??
                                  (listing['image'] != null
                                      ? [listing['image']]
                                      : []),
                              'status': listing['status'] ?? 'active',
                              'model': listing['model']?.toString() ?? '',
                              'seller': listing['seller'] ?? '',
                              'seller_id':
                                  listing['seller_id']?.toString() ?? '',
                              'seller_avatar': listing['seller_avatar'],
                            };

                            return Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.18),
                                    blurRadius: 15,
                                    spreadRadius: 1,
                                    offset: const Offset(0, 0),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Stack(
                                  children: [
                                    ProductCard(
                                      product: product,
                                      isFavorite: false,
                                      isRated: false,
                                      onFavoriteToggle: () {},
                                      onRatingToggle: () {},
                                      onEdit: () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => AddNewProductScreen(
                                              product: product,
                                            ),
                                          ),
                                        );
                                        // ✅ Refresh after editing so Deals counter updates
                                        if (mounted) _loadAll();
                                      },
                                    ),
                                    if ((product['status'] ?? 'active') !=
                                        'active')
                                      Positioned(
                                        top: 8,
                                        left: 8,
                                        child: StatusBadge(
                                          status: product['status'] ?? '',
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                    if (_myListings.length > 2)
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

                    SizedBox(height: screenHeight * 0.03),
                  ],
                ),
              ),
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
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                      "Settings",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: screenWidth * 0.06,
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xffdfe1e6)),
                  ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: const Text(
                      "Edit Profile",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: Text(
                      ">",
                      style: TextStyle(fontSize: screenWidth * 0.04),
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      final result = await Navigator.push<Map<String, dynamic>>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditProfileScreen(
                            name: _userName,
                            email: _userEmail,
                            phone: _userPhone,
                            bio: _userBio,
                            universityId: _userUniversityId,
                            universities: _universities,
                          ),
                        ),
                      );
                      if (result?['updated'] == true) {
                        if (result?['avatar'] != null) {
                          setState(
                            () => _avatarImage = result!['avatar'] as File,
                          );
                        } else {
                          setState(() => _avatarImage = null);
                        }
                        _loadAll();
                      }
                    },
                  ),
                  const Divider(height: 1, color: Color(0xffdfe1e6)),
                  SwitchListTile(
                    secondary: const Icon(Icons.notifications_outlined),
                    title: const Text(
                      "Notifications",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    value: _notificationsEnabled,
                    activeThumbColor: const Color(0xff2853af),
                    onChanged: (v) => _toggleNotifications(v, setModalState),
                  ),
                  const Divider(height: 1, color: Color(0xffdfe1e6)),
                  SwitchListTile(
                    secondary: const Icon(Icons.email_outlined),
                    title: const Text(
                      "Show Email",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    value: _showEmail,
                    activeThumbColor: const Color(0xff2853af),
                    onChanged: (v) => _toggleShowEmail(v, setModalState),
                  ),
                  const Divider(height: 1, color: Color(0xffdfe1e6)),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text(
                      "Logout",
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: _handleLogout,
                  ),
                ],
              ),
            );
          },
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

  void _showAvatarPickerSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
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
                    _pickAvatar(ImageSource.camera);
                  },
                ),
                _buildPickerOption(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  onTap: () {
                    Navigator.pop(context);
                    _pickAvatar(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAvatar(ImageSource source) async {
    final XFile? picked = await _picker.pickImage(
      source: source,
      imageQuality: 80,
    );
    if (picked != null && mounted) {
      setState(() => _avatarImage = File(picked.path));
    }
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
              color: Colors.blue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.blue, size: 30),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
