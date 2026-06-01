import 'package:flutter/material.dart';
import 'filter_state.dart';
import '../../services/university_service.dart';

class FilterBottomSheet extends StatefulWidget {
  const FilterBottomSheet({super.key});

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  // Categories Data
  final List<String> _categories = [
    'All',
    'Books',
    'Electronics',
    'Accessories',
    'Clothes',
    'Furniture',
  ];
  List<String> _selectedCategories = [];

  // Universities Data
  List<Map<String, dynamic>> _universities =
      []; // Stores full objects {id, name}
  bool _isLoadingUniversities = true;
  List<String> _selectedUniversities = []; // Stores IDs of selected universities

  // Price Range Data
  RangeValues _priceRange = const RangeValues(0, 1000000);

  @override
  void initState() {
    super.initState();
    final currentFilters = globalFilterState.value;
    _selectedCategories = List.from(currentFilters.selectedCategories);
    _selectedUniversities = List.from(currentFilters.selectedUniversities);
    _priceRange = currentFilters.priceRange;
    _fetchUniversities();
  }

  Future<void> _fetchUniversities() async {
    try {
      final uniList = await UniversityService.getUniversities();
      if (mounted) {
        setState(() {
          _universities = uniList.map((dynamic u) {
            if (u is Map) {
              return Map<String, dynamic>.from(u);
            } else {
              return {'id': 0, 'name': u.toString()};
            }
          }).toList();
          _isLoadingUniversities = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load universities: $e');
      if (mounted) {
        setState(() {
          _isLoadingUniversities = false;
        });
      }
    }
  }

  // Helper function to build custom chips
  Widget _buildFilterChips(List<String> items, List<String> selectedItems) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.04,
        vertical: 8.0,
      ),
      child: Wrap(
        spacing: screenWidth * 0.02,
        runSpacing: screenWidth * 0.02,
        children: items.map((item) {
          final isSelected = selectedItems.contains(item);
          return GestureDetector(
            onTap: () {
              setState(() {
                if (isSelected) {
                  selectedItems.remove(item);
                } else {
                  selectedItems.add(item);
                }
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.04,
                vertical: screenWidth * 0.02,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F2), // Grey background always
                borderRadius: BorderRadius.circular(
                  screenWidth * 0.05,
                ), // Oval shape
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF1A73E8)
                      : Colors.transparent, // Blue border if selected
                  width: 2.0,
                ),
              ),
              child: Text(
                item,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF1A73E8) : Colors.black87,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: screenWidth * 0.035,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── INSERT IT HERE (Line 123) ──
    Widget _buildUniversityChips() {
    final screenWidth = MediaQuery.of(context).size.width;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04, vertical: 8.0),
      child: Wrap(
        spacing: screenWidth * 0.02,
        runSpacing: screenWidth * 0.02,
        children: _universities.map((uni) {
          final String id = uni['id'].toString(); // ── CHANGE THIS to read directly as String ──
          final String name = uni['name'].toString();
          final isSelected = _selectedUniversities.contains(id);

          return GestureDetector(
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedUniversities.remove(id);
                } else {
                  _selectedUniversities.add(id);
                }
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.04,
                vertical: screenWidth * 0.02,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F2),
                borderRadius: BorderRadius.circular(screenWidth * 0.05),
                border: Border.all(
                  color: isSelected ? const Color(0xFF1A73E8) : Colors.transparent,
                  width: 2.0,
                ),
              ),
              child: Text(
                name,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF1A73E8) : Colors.black87,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: screenWidth * 0.035,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.85, // Adjust height as necessary
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24.0),
          topRight: Radius.circular(24.0),
        ),
      ),
      child: Column(
        children: [
          // ── HEADER ──
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.04,
              vertical: screenHeight * 0.02,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(width: screenWidth * 0.06), // Placeholder for balance
                Text(
                  'Filter',
                  style: TextStyle(
                    fontSize: screenWidth * 0.05,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close, size: screenWidth * 0.06),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── CONTENT ──
          Expanded(
            child: ListView(
              children: [
                // ── CATEGORIES ──
                Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                  ), // Remove ExpansionTile border
                  child: ExpansionTile(
                    title: Text(
                      'Category',
                      style: TextStyle(
                        fontSize: screenWidth * 0.04,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    children: [
                      _buildFilterChips(_categories, _selectedCategories),
                    ],
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),

                // ── UNIVERSITIES ──
                Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    title: Text(
                      'Universities',
                      style: TextStyle(
                        fontSize: screenWidth * 0.04,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    children: [
                      if (_isLoadingUniversities)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_universities.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('No universities found.'),
                        )
                      else
_buildUniversityChips(),                     ],
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),

                // ── PRICE RANGE ──
                Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded:
                        true, // often helpful to show price right away
                    title: Text(
                      'Price',
                      style: TextStyle(
                        fontSize: screenWidth * 0.04,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.04,
                          vertical: 8.0,
                        ),
                        child: Column(
                          children: [
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: const Color(0xFF1A73E8),
                                inactiveTrackColor: Colors.grey[300],
                                thumbColor: Colors.white,
                                // To make thumbs look like standard circles with borders like the image
                                rangeThumbShape:
                                    const RoundRangeSliderThumbShape(
                                      enabledThumbRadius: 10,
                                      elevation: 4,
                                      pressedElevation: 6,
                                    ),
                                overlayColor: const Color(
                                  0xFF1A73E8,
                                ).withOpacity(0.2),
                              ),
                              child: RangeSlider(
                                values: _priceRange,
                                min: 0,
                                max: 1000000,
                                divisions: 1000,
                                onChanged: (RangeValues values) {
                                  setState(() {
                                    _priceRange = values;
                                  });
                                },
                              ),
                            ),
                            SizedBox(height: screenHeight * 0.01),
                            // Price Labels
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Min Price Box
                                Expanded(
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      vertical: screenHeight * 0.015,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(
                                        screenWidth * 0.03,
                                      ),
                                      border: Border.all(
                                        color: Colors.grey[300]!,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${_priceRange.start.round()} DA',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: screenWidth * 0.035,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: screenWidth * 0.03,
                                  ),
                                  child: Text(
                                    '-',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: screenWidth * 0.04,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                // Max Price Box
                                Expanded(
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      vertical: screenHeight * 0.015,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(
                                        screenWidth * 0.03,
                                      ),
                                      border: Border.all(
                                        color: Colors.grey[300]!,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${_priceRange.end.round()} DA',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: screenWidth * 0.035,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: screenHeight * 0.02),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── BOTTOM BUTTONS ──
          Container(
            padding: EdgeInsets.all(screenWidth * 0.04),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedCategories.clear();
                        _selectedUniversities.clear();
                        _priceRange = const RangeValues(0, 1000000);
                      });
                      globalFilterState.value = globalFilterState.value
                          .copyWith(
                            selectedCategories: [],
                            selectedUniversities: [],
                            priceRange: const RangeValues(0, 1000000),
                          );
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        vertical: screenHeight * 0.02,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(screenWidth * 0.03),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    child: Text(
                      'Clear all',
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                        fontSize: screenWidth * 0.035,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: screenWidth * 0.03),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      // Apply Filter action here
                      globalFilterState.value = globalFilterState.value
                          .copyWith(
                            selectedCategories: List.from(_selectedCategories),
                            selectedUniversities: List.from(
                              _selectedUniversities,
                            ),
                            priceRange: _priceRange,
                          );
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A73E8),
                      padding: EdgeInsets.symmetric(
                        vertical: screenHeight * 0.02,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(screenWidth * 0.03),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Apply Filter',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: screenWidth * 0.038,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom), // safe area
        ],
      ),
    );
  }
}
