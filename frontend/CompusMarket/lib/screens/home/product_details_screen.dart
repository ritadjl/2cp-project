import 'dart:io';
import 'package:compusmarket/screens/profiles/My_profile.dart';
import 'package:flutter/material.dart';
import 'home_products_grid.dart';
import '../../services/announcement_service.dart';
import '../../services/msg_service.dart';
import '../../services/auth_services.dart';
import '../../services/favorite_service.dart';
import '../chats/chat_in.dart';
import '../profiles/His_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:compusmarket/screens/home/add_new_product.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailsScreen({super.key, required this.product});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  late bool isFavorite;
  late bool isRated;
  int _userRating = 0;
  bool isDescriptionExpanded = false;
  List<Map<String, dynamic>> _comments = [];
  final TextEditingController _commentController = TextEditingController();
  int selectedImageIndex = 0;
  late List<String> galleryImages;


  @override
  void initState() {
    super.initState();
    _loadSavedRating();
    debugPrint('PRODUCT DATA: ${widget.product}');

    final productName = widget.product['name'] ?? widget.product['title'] ?? '';

    isFavorite = globalFavoriteProducts.any(
      (p) => (p['name'] ?? p['title']) == productName,
    );
    isRated = globalRatedProducts.any(
      (p) => (p['name'] ?? p['title']) == productName,
    );

    final photos = widget.product['photos'];
    if (photos != null && photos is List && photos.isNotEmpty) {
      galleryImages = photos
          .map((p) => p is Map ? (p['url'] ?? '').toString() : p.toString())
          .where((url) => url.isNotEmpty)
          .toList();
    } else {
      final image =
          widget.product['photo']?.toString() ??
          widget.product['image']?.toString() ??
          '';
      galleryImages = image.isNotEmpty ? [image] : [];
    }

    if (galleryImages.isEmpty) galleryImages = [''];
  }

  String get _productName =>
      widget.product['name'] ?? widget.product['title'] ?? '';

  String get _productPrice => widget.product['price']?.toString() ?? '';

  String get _productDescription => widget.product['description'] ?? '';

  double get _productRating =>
      (widget.product['average_rating'] ?? widget.product['rating'] ?? 0.0)
          .toDouble();

  bool get _isOwnProduct {
    final sellerId = widget.product['seller_id']?.toString();
    return sellerId != null && sellerId == MsgService.currentUserId;
  }

  Future<void> _loadSavedRating() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt('rating_${widget.product['id']}') ?? 0;
    if (mounted) setState(() => _userRating = saved);
  }

  void _toggleFavorite() async {
    final bool isReal = widget.product['isReal'] == true;
    final String productName = _productName;
    final int? announcementId = widget.product['id'];

    setState(() {
      isFavorite = !isFavorite;
    });

    if (isFavorite) {
      if (isReal && announcementId != null) {
        try {
          final result = await FavoriteService.addFavorite(announcementId);
          if (mounted) {
            setState(() {
              final updatedProduct = {
                ...widget.product,
                'favoriteId': result['id'],
              };
              globalFavoriteProducts.removeWhere(
                (p) => (p['name'] ?? p['title']) == productName,
              );
              globalFavoriteProducts.add(updatedProduct);
            });
          }
        } catch (e) {
          print('❌ Failed to add favorite: $e');
          if (mounted) {
            setState(() {
              isFavorite = false;
            });
          }
        }
      } else {
        setState(() {
          globalFavoriteProducts.removeWhere(
            (p) => (p['name'] ?? p['title']) == productName,
          );
          globalFavoriteProducts.add(widget.product);
        });
      }
    } else {
      if (isReal) {
        try {
          final existing = globalFavoriteProducts.firstWhere(
            (p) => (p['name'] ?? p['title']) == productName,
            orElse: () => {},
          );
          final favoriteId = existing['favoriteId'];
          if (favoriteId != null) {
            final int parsedId = favoriteId is int
                ? favoriteId
                : int.parse(favoriteId.toString());
            await FavoriteService.removeFavorite(parsedId);
          }
          if (mounted) {
            setState(() {
              globalFavoriteProducts.removeWhere(
                (p) => (p['name'] ?? p['title']) == productName,
              );
            });
          }
        } catch (e) {
          print('❌ Failed to remove favorite: $e');
          if (mounted) {
            setState(() {
              isFavorite = true;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            globalFavoriteProducts.removeWhere(
              (p) => (p['name'] ?? p['title']) == productName,
            );
          });
        }
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFavorite ? 'Added to favorites' : 'Removed from favorites',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String selectedReason = 'Spam / Misleading';
        final reasons = [
          'Spam / Misleading',
          'Inappropriate Content',
          'Harassment or Abuse',
          'Fake Product / Scam',
          'Other'
        ];
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(Icons.report_problem, color: Colors.red),
                  SizedBox(width: 10),
                  Text('Report Product'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Why are you reporting this product?',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 15),
                  ...reasons.map((reason) {
                    return RadioListTile<String>(
                      activeColor: Colors.red,
                      title:
                          Text(reason, style: const TextStyle(fontSize: 14)),
                      value: reason,
                      groupValue: selectedReason,
                      onChanged: (val) {
                        setStateDialog(() {
                          selectedReason = val!;
                        });
                      },
                    );
                  }),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    print('DEBUG: Report button tapped');
                    try {
                      final reasonMap = {
                        'Spam / Misleading': 'spam',
                        'Inappropriate Content': 'inappropriate',
                        'Harassment or Abuse': 'offensive',
                        'Fake Product / Scam': 'scam',
                        'Other': 'other',
                      };
                      final reasonKey = reasonMap[selectedReason] ?? 'other';
                      await AnnouncementService.reportAnnouncement(
                        widget.product['id'],
                        reasonKey,
                      );
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Report submitted! Our team will review it.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    } catch (e) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to report: $e')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Submit Report',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildImage(String imagePath, {BoxFit fit = BoxFit.cover}) {
    final bool isUserAdded = widget.product['isUserAdded'] == true;
    final bool isReal = widget.product['isReal'] == true;
    final screenWidth = MediaQuery.of(context).size.width;

    if (imagePath.isEmpty) {
      return Center(
        child: Icon(
          Icons.image_outlined,
          size: screenWidth * 0.2,
          color: Colors.grey[400],
        ),
      );
    }

    if (isUserAdded) {
      return Image.file(
        File(imagePath),
        fit: fit,
        errorBuilder: (context, error, stackTrace) => Center(
          child: Icon(
            Icons.image_outlined,
            size: screenWidth * 0.2,
            color: Colors.grey[400],
          ),
        ),
      );
    }

    if (isReal || imagePath.startsWith('http')) {
      return Image.network(
        imagePath,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
              color: const Color(0xFF1A73E8),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => Center(
          child: Icon(
            Icons.image_outlined,
            size: screenWidth * 0.2,
            color: Colors.grey[400],
          ),
        ),
      );
    }

    return Image.asset(
      imagePath,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => Center(
        child: Icon(
          Icons.image_outlined,
          size: screenWidth * 0.2,
          color: Colors.grey[400],
        ),
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: PageView.builder(
            itemCount: galleryImages.length,
            controller: PageController(initialPage: initialIndex),
            itemBuilder: (context, index) {
              return InteractiveViewer(
                minScale: 0.1,
                maxScale: 4.0,
                child: _buildImage(galleryImages[index], fit: BoxFit.contain),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showCommentsSheet(BuildContext context) {
    bool isFetching = false;
    bool localIsLoading = widget.product['isReal'] == true;
    String errorMessage = '';

    void loadData(StateSetter setStateBottomSheet) async {
      if (isFetching) return;
      isFetching = true;
      try {
        final commentsData = await AnnouncementService.getComments(
          widget.product['id'],
        );
        if (commentsData.isNotEmpty) {
          debugPrint('COMMENT DATA: ${commentsData.first}');
        }
        if (mounted) {
          setState(() {
            _comments = List<Map<String, dynamic>>.from(
              commentsData.map(
                (e) => {
                  'text': e['content'] ?? e['text'] ?? '',
                  'user': e['user_full_name'] ??
                      e['user']?['full_name'] ??
                      'User',
                },
              ),
            );
          });
          setStateBottomSheet(() {
            localIsLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setStateBottomSheet(() {
            localIsLoading = false;
            errorMessage = 'Failed to load comments.';
          });
        }
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateBottomSheet) {
            if (localIsLoading && !isFetching) {
              loadData(setStateBottomSheet);
            }
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Comments',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: localIsLoading
                          ? const Center(child: CircularProgressIndicator())
                          : errorMessage.isNotEmpty
                              ? Center(
                                  child: Text(
                                    errorMessage,
                                    style:
                                        const TextStyle(color: Colors.red),
                                  ),
                                )
                              : _comments.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'No comments yet. Be the first!',
                                        style:
                                            TextStyle(color: Colors.grey),
                                      ),
                                    )
                                  : ListView.builder(
                                      itemCount: _comments.length,
                                      itemBuilder: (context, index) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8.0),
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[100],
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const CircleAvatar(
                                                  backgroundColor:
                                                      Color(0xFF1A73E8),
                                                  child: Icon(Icons.person,
                                                      color: Colors.white),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        _comments[index]
                                                                ['user'] ??
                                                            'User',
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        _comments[index]
                                                                ['text'] ??
                                                            '',
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            decoration: InputDecoration(
                              hintText: 'Write a comment...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () async {
                            if (_commentController.text.trim().isNotEmpty) {
                              final text = _commentController.text.trim();
                              _commentController.clear();

                              if (widget.product['isReal'] == true) {
                                try {
                                  await AnnouncementService.createComment(
                                    widget.product['id'],
                                    text,
                                  );
                                  if (mounted) {
                                    isFetching = false;
                                    loadData(setStateBottomSheet);
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text('Failed to post comment'),
                                      ),
                                    );
                                  }
                                }
                              } else {
                                setState(() {
                                  _comments.add(
                                      {'text': text, 'user': 'You'});
                                });
                                setStateBottomSheet(() {});
                              }
                            }
                          },
                          child: const CircleAvatar(
                            backgroundColor: Color(0xFF1A73E8),
                            child: Icon(Icons.send, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final modelText = widget.product['model'] ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── HEADER ──
            Padding(
              padding: const EdgeInsets.only(top: 60, left: 20, right: 20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.black),
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Product Info',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 45),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── IMAGE SLIDESHOW ──
            Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: screenWidth * 1.1,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF2F2F2),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: GestureDetector(
                    onTap: () =>
                        _showFullScreenImage(context, selectedImageIndex),
                    child: Stack(
                      children: [
                        PageView.builder(
                          itemCount: galleryImages.length,
                          onPageChanged: (index) =>
                              setState(() => selectedImageIndex = index),
                          itemBuilder: (context, index) {
                            return _buildImage(
                              galleryImages[index],
                              fit: BoxFit.cover,
                            );
                          },
                        ),
                        if (galleryImages.length > 1)
                          Positioned(
                            bottom: 16,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                galleryImages.length,
                                (index) => AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 300),
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 4),
                                  width:
                                      selectedImageIndex == index ? 20 : 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: selectedImageIndex == index
                                        ? const Color(0xFF1A73E8)
                                        : Colors.white.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // Status badge (SOLD / INACTIVE)
                        if ((widget.product['status'] ?? 'active') !=
                            'active')
                          Positioned(
                            top: 80,
                            left: 20,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xff2853af),
                                borderRadius: BorderRadius.circular(25),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        Colors.black.withOpacity(0.2),
                                    blurRadius: 6,
                                  )
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    widget.product['status'] == 'sold'
                                        ? Icons.sell
                                        : Icons.timer_off,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    (widget.product['status'] ?? '')
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Favorite button
                // ✅ REPLACE WITH
Positioned(
  bottom: 16,
  right: 16,
  child: GestureDetector(
    onTap: _isOwnProduct
        ? () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddNewProductScreen(product: widget.product),
              ),
            );
          }
        : _toggleFavorite,
    child: Container(
      width: 45,
      height: 45,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 5,
          ),
        ],
      ),
      child: Icon(
        _isOwnProduct
            ? Icons.edit_outlined
            : (isFavorite ? Icons.favorite : Icons.favorite_border),
        color: _isOwnProduct
            ? const Color(0xff2853af)
            : (isFavorite ? Colors.red : Colors.grey),
      ),
    ),
  ),
),
              ],
            ),

            SizedBox(height: screenWidth * 0.05),

            // ── THUMBNAILS ──
            if (galleryImages.length > 1)
              SizedBox(
                height: 70,
                child: ListView.builder(
                  padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.05),
                  scrollDirection: Axis.horizontal,
                  itemCount: galleryImages.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () =>
                          setState(() => selectedImageIndex = index),
                      child: Container(
                        width: 70,
                        margin: const EdgeInsets.only(right: 15),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F2F2),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: selectedImageIndex == index
                                ? const Color(0xFF1A73E8)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: _buildImage(
                          galleryImages[index],
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              ),

            SizedBox(height: screenWidth * 0.05),

            // ── SELLER PROFILE — hidden for own product ──
            if (!_isOwnProduct) ...[
              Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFF1A73E8),
                      backgroundImage: (widget.product['seller_photo'] !=
                                  null &&
                              widget.product['seller_photo']
                                  .toString()
                                  .isNotEmpty)
                          ? NetworkImage(
                              widget.product['seller_photo'].toString())
                          : null,
                      child: (widget.product['seller_photo'] == null ||
                              widget.product['seller_photo']
                                  .toString()
                                  .isEmpty)
                          ? const Icon(Icons.person, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.product['seller'] ??
                                widget.product['sellerName'] ??
                                'Campus Seller',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            widget.product['university']?.toString() ??
                                'Verified User',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        final sellerId =
                            widget.product['seller_id']?.toString();
                        if (sellerId == null || sellerId.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Seller info not available')),
                          );
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                HisProfileScreen(sellerId: sellerId),
                          ),
                        );
                      },
                      child: const Text('View Profile'),
                    ),
                  ],
                ),
              ),
              SizedBox(height: screenWidth * 0.05),
            ],

            // ── PRODUCT INFO ──
            Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _productName,
                              style: TextStyle(
                                fontSize: screenWidth * 0.06,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (modelText.isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Text(
                                modelText,
                                style: TextStyle(
                                  fontSize: screenWidth * 0.035,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Text(
                        _productPrice.contains('DA')
                            ? _productPrice
                            : '$_productPrice DA',
                        style: TextStyle(
                          fontSize: screenWidth * 0.055,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A73E8),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: screenWidth * 0.05),

                  // ── ACTIONS ROW ──
                  // Own product: only Comments
                  // Other product: Rating + Comments + Report
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Rating stars — hidden for own product
                        if (!_isOwnProduct) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.amber.withOpacity(0.5)),
                            ),
                            child: Row(
                              children: List.generate(5, (index) {
                                return GestureDetector(
                                  onTap: () async {
                                    final int selectedRating = index + 1;
                                    setState(() {
                                      _userRating = selectedRating;
                                      isRated = true;
                                    });
                                    final prefs =
                                        await SharedPreferences.getInstance();
                                    await prefs.setInt(
                                        'rating_${widget.product['id']}',
                                        selectedRating);
                                    if (widget.product['isReal'] == true) {
                                      try {
                                        await AnnouncementService
                                            .rateAnnouncement(
                                          widget.product['id'],
                                          rating: selectedRating,
                                        );
                                      } catch (e) {
                                        print('❌ Rating failed: $e');
                                      }
                                    }
                                  },
                                  child: Icon(
                                    index < _userRating
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: Colors.amber,
                                    size: 20,
                                  ),
                                );
                              }),
                            ),
                          ),
                          const SizedBox(width: 15),
                        ],

                        // Comments — always visible
                        GestureDetector(
                          onTap: () => _showCommentsSheet(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.grey.withOpacity(0.3)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.comment_outlined,
                                    color: Colors.black87, size: 20),
                                SizedBox(width: 6),
                                Text(
                                  'Comments',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Report — hidden for own product
                        if (!_isOwnProduct) ...[
                          const SizedBox(width: 15),
                          GestureDetector(
                            onTap: _showReportDialog,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: Colors.red.withOpacity(0.3)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.report_outlined,
                                      color: Colors.red, size: 20),
                                  SizedBox(width: 6),
                                  Text(
                                    'Report product',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  SizedBox(height: screenWidth * 0.08),

                  // ── DESCRIPTION ──
                  const Text(
                    'Description',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  _productDescription.isEmpty
                      ? Text(
                          'No description available.',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[500],
                            height: 1.5,
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _productDescription,
                              maxLines:
                                  isDescriptionExpanded ? null : 3,
                              overflow: isDescriptionExpanded
                                  ? TextOverflow.visible
                                  : TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey[700],
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 5),
                            GestureDetector(
                              onTap: () => setState(
                                () => isDescriptionExpanded =
                                    !isDescriptionExpanded,
                              ),
                              child: Text(
                                isDescriptionExpanded
                                    ? 'Show less'
                                    : 'Learn more',
                                style: const TextStyle(
                                  color: Color(0xFF1A73E8),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),

                  SizedBox(height: screenWidth * 0.1),
                ],
              ),
            ),
          ],
        ),
      ),

      // ── BOTTOM BUTTON ──
      // Own product  → "Delete Product" (red)
      // Other product → "Contact seller" (blue)
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.05,
            vertical: 15,
          ),
          child: ElevatedButton(
            onPressed: () async {
              if (_isOwnProduct) {
                // ── DELETE PRODUCT ──
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    title: const Text('Archive Product'),
                    content: const Text(
                        'Are you sure you want to archive this product?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel',
                            style: TextStyle(color: Colors.grey)),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red),
                        child: const Text('Archive',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  try {
                    await AnnouncementService.archiveAnnouncement(
    widget.product['id']);
if (mounted) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
        content: Text('Product archived successfully')),
  );
  Navigator.pop(context);
}
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Failed to delete: $e')),
                      );
                    }
                  }
                }
              } else {
                // ── CONTACT SELLER ──
                try {
                  final sellerId =
                      widget.product['seller_id']?.toString();
                  final listingId =
                      widget.product['id']?.toString();
                  print('DEBUG seller_id: $sellerId');
                  print('DEBUG listing id: $listingId');

                  if (sellerId == null || listingId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Seller info not available')),
                    );
                    return;
                  }

                  if (sellerId == MsgService.currentUserId) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('This is your own listing')),
                    );
                    return;
                  }

                  final conversation =
                      await MsgService.getOrCreateConversation(
                    AuthService.accessToken,
                    sellerId,
                    listingId,
                  );

                  final seller = conversation['seller'] ?? {};
                  final first =
                      (seller['first_name'] ?? '').toString().trim();
                  final last =
                      (seller['last_name'] ?? '').toString().trim();
                  final name = [first, last]
                      .where((s) => s.isNotEmpty)
                      .join(' ');

                  if (mounted) {
                    final announcement = {
                      'id': widget.product['id'],
                      'title': widget.product['name'] ??
                          widget.product['title'] ??
                          '',
                      'price': widget.product['priceValue'] ??
                          widget.product['price'] ??
                          '',
                      'photo': galleryImages.isNotEmpty &&
                              galleryImages[0].isNotEmpty
                          ? galleryImages[0]
                          : '',
                      'currency': 'DA',
                    };

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatsInScreen(
                          name: name.isNotEmpty
                              ? name
                              : seller['email'] ?? 'Seller',
                          conversationId: conversation['id'],
                          isNetwork: false,
                          isOnline: false,
                          announcement: announcement,
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Could not open chat: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _isOwnProduct
                  ? Colors.orange
                  : const Color(0xFF1A73E8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              padding: const EdgeInsets.symmetric(vertical: 18),
              elevation: 0,
            ),
            child: Text(
              _isOwnProduct ? 'Archive Product' : 'Contact seller',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}