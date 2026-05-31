import 'dart:io';
import 'package:flutter/material.dart';
import 'filter_state.dart';
import 'product_details_screen.dart';
import '../../services/announcement_service.dart';
import '../../services/favorite_service.dart';

// ── GLOBAL VARIABLES FOR MEMORY ──
List<Map<String, dynamic>> globalFavoriteProducts = [];
List<Map<String, dynamic>> globalRatedProducts = [];

final ValueNotifier<List<Map<String, dynamic>>> globalRealProductsNotifier =
    ValueNotifier([]);

// ── 15 FIXED FAKE PRODUCTS ──
const List<Map<String, dynamic>> _fakeProducts = [
  {'name': 'AirPods', 'price': '4500.00 DA', 'priceValue': 4500.00, 'category': 'Electronics', 'rating': 4.5, 'isRated': false, 'image': 'assets/images/products/airpods.jpg'},
  {'name': 'Apple Watch', 'price': '15500.00 DA', 'priceValue': 15500.00, 'category': 'Electronics', 'rating': 3.5, 'isRated': false, 'image': 'assets/images/products/applewatch.jpg'},
  {'name': 'Bike', 'price': '22500.00 DA', 'priceValue': 22500.00, 'category': 'Accessories', 'rating': 4.0, 'isRated': false, 'image': 'assets/images/products/bike.jpg'},
  {'name': 'Black Airpods', 'price': '2500.00 DA', 'priceValue': 2500.00, 'category': 'Electronics', 'rating': 3.5, 'isRated': false, 'image': 'assets/images/products/blackairpods.jpg'},
];

class HomeProductsGrid extends StatefulWidget {
  const HomeProductsGrid({super.key});
  @override
  State<HomeProductsGrid> createState() => _HomeProductsGridState();
}

class _HomeProductsGridState extends State<HomeProductsGrid> {
  List<Map<String, dynamic>> _realProducts = [];
  

  @override
  void initState() {
    super.initState();
    _loadRealProducts();
    globalFilterState.addListener(_onFilterChanged);
    globalRealProductsNotifier.addListener(_onNewProductAdded);
  }

  @override
  void dispose() {
    globalFilterState.removeListener(_onFilterChanged);
    globalRealProductsNotifier.removeListener(_onNewProductAdded);
    super.dispose();
  }

  void _onFilterChanged() {
    _loadRealProducts();
  }

  void _onNewProductAdded() {
    _loadRealProducts();
  }

  Future<void> _loadRealProducts() async {
    try {
      final filter = globalFilterState.value;
      final data = await AnnouncementService.getAnnouncements(
        page: 1,
        search: filter.searchQuery.isNotEmpty ? filter.searchQuery : null,
        minPrice: filter.priceRange.start > 0 ? filter.priceRange.start : null,
        maxPrice: filter.priceRange.end < 1000000 ? filter.priceRange.end : null,
      );
      final List results = data['results'] ?? [];
      final real = results.take(5).map((item) {
  print('DEBUG item: id=${item['id']}, seller=${item['seller']}, seller_id=${item['seller_id']}');
  return {
    'id': item['id'],
    'name': item['title'] ?? '',
    'price': '${item['price']} DA',
    'priceValue': double.tryParse(item['price'].toString()) ?? 0.0,
    'category': item['category'] ?? '',
    'rating': (item['average_rating'] ?? 0.0).toDouble(),
    'isRated': false,
    'image': item['photo'] ?? '',
    'isReal': true,
    'seller': item['seller'] ?? '',
    'seller_id': item['seller_id']?.toString() ?? '',  // 👈 add this
    'university': item['university'] ?? '',
    'photos': item['photos'],
    'status': item['status']?.toString() ?? 'active',
  };
}).toList();

      if (mounted) {
        setState(() {
          _realProducts = real;
        });
      }
    } catch (e) {
      print('❌ Failed to load real products: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: globalRealProductsNotifier,
      builder: (context, userProducts, _) {
        final List<Map<String, dynamic>> allProducts = [
          ...userProducts,
          ..._realProducts,
          ..._fakeProducts,
        ];

        return ValueListenableBuilder<FilterData>(
          valueListenable: globalFilterState,
          builder: (context, filter, child) {
            final filteredProducts = allProducts.where((product) {
              if (filter.searchQuery.isNotEmpty) {
                final String productName = product['name'].toLowerCase();
                final String query = filter.searchQuery.toLowerCase();
                if (!productName.contains(query)) return false;
              }
              if (filter.selectedMainCategory != 'All' &&
                  product['category'] != filter.selectedMainCategory) {
                return false;
              }
              if (filter.selectedCategories.isNotEmpty &&
                  !filter.selectedCategories.contains(product['category'])) {
                return false;
              }
              final double price = product['priceValue'] as double;
              if (price < filter.priceRange.start ||
                  price > filter.priceRange.end) {
                return false;
              }
              return true;
            }).toList();

            if (filteredProducts.isEmpty) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: screenWidth * 0.1),
                child: Center(
                  child: Text(
                    'No products match these filters.',
                    style: TextStyle(
                        color: Colors.grey, fontSize: screenWidth * 0.045),
                  ),
                ),
              );
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: screenWidth * 0.03,
                mainAxisSpacing: screenWidth * 0.03,
                childAspectRatio: 0.75,
              ),
              itemCount: filteredProducts.length,
              itemBuilder: (context, index) {
                final product = filteredProducts[index];
                final bool isFavorite = globalFavoriteProducts.any(
                  (p) => p['name'] == product['name'],
                );
                final bool isRated = globalRatedProducts.any(
                  (p) => p['name'] == product['name'],
                );

                return ProductCard(
                  product: product,
                  isFavorite: isFavorite,
                  isRated: isRated,
                  onFavoriteToggle: () async {
                    final bool isReal = product['isReal'] == true;
                    if (isReal) {
                      try {
                        if (isFavorite) {
                          final existing = globalFavoriteProducts.firstWhere(
                            (p) => p['name'] == product['name'],
                            orElse: () => {},
                          );
                          final favoriteId = existing['favoriteId'];
                          if (favoriteId != null) {
                            await FavoriteService.removeFavorite(favoriteId);
                          }
                          if (mounted) {
                            setState(() {
                              globalFavoriteProducts.removeWhere(
                                  (p) => p['name'] == product['name']);
                            });
                          }
                        } else {
                          final result =
                              await FavoriteService.addFavorite(product['id']);
                          if (mounted) {
                            setState(() {
                              globalFavoriteProducts.add({
                                ...product,
                                'favoriteId': result['id'],
                              });
                            });
                          }
                        }
                      } catch (e) {
                        print('❌ Favorite toggle failed: $e');
                      }
                    } else {
                      if (mounted) {
                        setState(() {
                          if (isFavorite) {
                            globalFavoriteProducts.removeWhere(
                                (p) => p['name'] == product['name']);
                          } else {
                            globalFavoriteProducts.add(product);
                          }
                        });
                      }
                    }
                  },
                  onRatingToggle: () {
                    if (mounted) {
                      setState(() {
                        if (isRated) {
                          globalRatedProducts.removeWhere(
                              (p) => p['name'] == product['name']);
                        } else {
                          globalRatedProducts.add(product);
                        }
                      });
                    }
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

// ── PRODUCT CARD WIDGET ──
class ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final bool isFavorite;
  final bool isRated;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onRatingToggle;
  final VoidCallback? onEdit;

  const ProductCard({
    super.key,
    required this.product,
    required this.isFavorite,
    required this.isRated,
    required this.onFavoriteToggle,
    required this.onRatingToggle,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isReal = product['isReal'] == true;
    final bool isUserAdded = product['isUserAdded'] == true;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                ProductDetailsScreen(product: product),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              const begin = Offset(1.0, 0.0);
              const end = Offset.zero;
              const curve = Curves.easeInOut;
              var tween = Tween(begin: begin, end: end)
                  .chain(CurveTween(curve: curve));
              return SlideTransition(
                  position: animation.drive(tween), child: child);
            },
          ),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(screenWidth * 0.05),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 6),
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F2),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(screenWidth * 0.05),
                        topRight: Radius.circular(screenWidth * 0.05),
                      ),
                    ),
                    child: isUserAdded
                        ? Image.file(
                            File(product['image']),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Center(
                              child: Icon(Icons.image_outlined,
                                  size: screenWidth * 0.12,
                                  color: Colors.grey[400]),
                            ),
                          )
                        : isReal
                            ? Image.network(
                                product['image'],
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Center(
                                  child: Icon(Icons.image_outlined,
                                      size: screenWidth * 0.12,
                                      color: Colors.grey[400]),
                                ),
                              )
                            : Image.asset(
                                product['image'],
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Center(
                                  child: Icon(Icons.image_outlined,
                                      size: screenWidth * 0.12,
                                      color: Colors.grey[400]),
                                ),
                              ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: onEdit ?? onFavoriteToggle,
                      child: Container(
                        width: screenWidth * 0.08,
                        height: screenWidth * 0.08,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4),
                          ],
                        ),
                        child: Center(
                          child: onEdit != null
                              ? Icon(Icons.edit_outlined,
                                  color: const Color(0xff2853af),
                                  size: screenWidth * 0.05)
                              : Icon(
                                  isFavorite
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color:
                                      isFavorite ? Colors.red : Colors.grey,
                                  size: screenWidth * 0.05),
                        ),
                      ),
                    ),
                  ),
                  // Add this after the existing Positioned(top: 8, right: 8, ...) block:
if ((product['status'] ?? 'active') != 'active')
  Positioned(
    top: 8,
    left: 8,
    child: StatusBadge(status: product['status'] ?? ''),
  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(screenWidth * 0.025),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name'],
                    style: TextStyle(
                      fontSize: screenWidth * 0.033,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: screenWidth * 0.01),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        product['price'],
                        style: TextStyle(
                          fontSize: screenWidth * 0.035,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A73E8),
                        ),
                      ),
                      
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isSold = status == 'sold';
    final label = isSold ? 'SOLD' : 'EXPIRED';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xff2853af),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSold ? Icons.sell : Icons.timer_off,
            color: Colors.white,
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}