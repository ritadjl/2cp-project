import 'package:flutter/material.dart';

class FilterData {
  final String selectedMainCategory;
  final List<String> selectedCategories;
  final List<String> selectedUniversities; // Change this back to List<String>
  final RangeValues priceRange;
  final String searchQuery;

  FilterData({
    this.selectedMainCategory = 'All',
    this.selectedCategories = const [],
    this.selectedUniversities = const [], // empty List<String>
    this.priceRange = const RangeValues(0, 1000000),
    this.searchQuery = '',
  });

  FilterData copyWith({
    String? selectedMainCategory,
    List<String>? selectedCategories,
    List<String>? selectedUniversities, // Change this back to List<String>
    RangeValues? priceRange,
    String? searchQuery,
  }) {
    return FilterData(
      selectedMainCategory: selectedMainCategory ?? this.selectedMainCategory,
      selectedCategories: selectedCategories ?? this.selectedCategories,
      selectedUniversities: selectedUniversities ?? this.selectedUniversities,
      priceRange: priceRange ?? this.priceRange,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

// Global ValueNotifier to hold the filter state
final ValueNotifier<FilterData> globalFilterState = ValueNotifier(FilterData());
