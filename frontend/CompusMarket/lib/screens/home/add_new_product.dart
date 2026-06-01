import 'dart:io';
import 'package:compusmarket/services/profile_api_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/university_service.dart';
import '../../services/category_service.dart';
import 'home_products_grid.dart';
import '../../services/announcement_service.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class AddNewProductScreen extends StatefulWidget {
  final Map<String, dynamic>? product;
  const AddNewProductScreen({super.key, this.product});

  @override
  State<AddNewProductScreen> createState() => _AddNewProductScreenState();
}

class _AddNewProductScreenState extends State<AddNewProductScreen> {
  final _formKey = GlobalKey<FormState>();
  List<File> _selectedImages = [];

  // existing image URLs shown in edit mode
  List<String> _existingImageUrls = [];

  final ImagePicker _picker = ImagePicker();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();

  int _currentImageIndex = 0;

  bool _isSubmitting = false;
 // bool _isReserved = false;
 String _selectedStatus = 'active';

  final List<String> _types = [
    'Books',
    'Electronics',
    'Accessories',
    'Clothing',
    'Furniture',
    'Sports',
    'Vehicles',
  ];
  String _selectedType = 'Books';

  List<dynamic> _universitiesList = [];
  List<dynamic> _categoriesList = [];
  bool _isLoadingUniversities = true;
  bool _universitiesFailed = false;

  String? _pendingUniversityName;
  String? _selectedUniversity;

  @override
  void initState() {
    super.initState();

    if (widget.product != null) {
      final p = widget.product!;

      _nameController.text = p['name'] ?? p['title'] ?? '';
      _modelController.text = p['model']?.toString() ?? '';
      _descriptionController.text = p['description'] ?? '';
      _selectedStatus = p['status']?.toString() ?? 'active';

      //_isReserved = p['status'] == 'reserved';

      // ✅ category: match case-insensitively against _types list
      final rawCategory = (p['category'] ?? '').toString();
      final matchedType = _types.firstWhere(
        (t) => t.toLowerCase() == rawCategory.toLowerCase(),
        orElse: () => 'Books',
      );
      _selectedType = matchedType;

      // ✅ price: prefer priceValue (already a number), fall back to price string
      final dynamic rawPrice = p['priceValue'] ?? p['price'] ?? '0';
      double parsedPrice = 0.0;
      if (rawPrice is num) {
        parsedPrice = rawPrice.toDouble();
      } else {
        // strip everything except digits and dot (handles "42444.00 DA")
        parsedPrice = double.tryParse(
                rawPrice.toString().replaceAll(RegExp(r'[^0-9.]'), '')) ??
            0.0;
      }
      _priceController.text = parsedPrice.toInt().toString();
      print('💰 Price raw=$rawPrice parsed=${_priceController.text}');

      // ✅ university: normalize apostrophes before comparing
      final location = p['location']?.toString().trim() ??
          p['university']?.toString().trim() ??
          '';
      // replace curly/fancy apostrophes with straight apostrophe
      _pendingUniversityName = location.isNotEmpty
          ? location.replaceAll('\u2019', "'").replaceAll('\u2018', "'")
          : null;
      print('🏫 Pending university: $_pendingUniversityName');

      // load existing image URLs
      final images = p['images'];
      if (images is List) {
        _existingImageUrls = images.map((e) => e.toString()).toList();
      } else {
        final singleImage = p['image']?.toString() ?? '';
        if (singleImage.isNotEmpty) _existingImageUrls = [singleImage];
      }
    }

    _fetchData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<File> _compressImage(File file) async {
    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      '${file.parent.path}/compressed_${file.uri.pathSegments.last}.jpg',
      quality: 70,
      minWidth: 1024,
      minHeight: 1024,
      format: CompressFormat.jpeg,
    );
    return result != null ? File(result.path) : file;
  }

  Future<void> _fetchData() async {
    if (mounted) {
      setState(() {
        _isLoadingUniversities = true;
        _universitiesFailed = false;
      });
    }
    try {
      final results = await Future.wait([
        UniversityService.getUniversities(),
        CategoryService.getCategories(),
      ]);
      if (mounted) {
        setState(() {
          _universitiesList = results[0];
          _categoriesList = results[1];
          _isLoadingUniversities = false;
          _universitiesFailed = false;

          // match pending university name now that the list is loaded
          if (_pendingUniversityName != null) {
            // normalize both sides: replace curly apostrophes with straight
            final normalizedPending = _pendingUniversityName!
                .trim()
                .replaceAll('\u2019', "'")
                .replaceAll('\u2018', "'");
            print('🔍 Matching university: "$normalizedPending"');
            for (final u in _universitiesList) {
              if (u is Map) {
                final uName = u['name']
                    .toString()
                    .trim()
                    .replaceAll('\u2019', "'")
                    .replaceAll('\u2018', "'");
                print('   vs "$uName"');
                if (uName == normalizedPending) {
                  _selectedUniversity = u['name'].toString();
                  print('✅ University matched: $_selectedUniversity');
                  break;
                }
              }
            }
            if (_selectedUniversity == null) {
              print('❌ No university match found for "$normalizedPending"');
            }
          }
        });
      }
    } catch (e) {
      print('❌ Failed to load data: $e');
      if (mounted) {
        setState(() {
          _isLoadingUniversities = false;
          _universitiesFailed = true;
        });
      }
    }
  }

  Future<void> _submitForm() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    if (_selectedImages.isEmpty &&
        _existingImageUrls.isEmpty &&
        widget.product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one picture')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    // ✅ FIX: safe category lookup
    String categoryId = '';
    for (final c in _categoriesList) {
      if (c is Map &&
          c['name'].toString().toLowerCase() ==
              _selectedType.toLowerCase()) {
        categoryId = c['id'].toString();
        break;
      }
    }
    print('🔍 Category lookup: $_selectedType → $categoryId');

    // ✅ FIX: safe university lookup
    String universityId = '';
    for (final u in _universitiesList) {
      if (u is Map && u['name'].toString() == _selectedUniversity) {
        universityId = u['id'].toString();
        break;
      }
    }

    // ── EDIT MODE ──
    if (widget.product != null) {
      try {
        final id = int.tryParse(widget.product!['id'].toString()) ?? 0;

        await AnnouncementService.updateAnnouncement(

  id,
  {
    'title': _nameController.text.trim(),
    'description': _descriptionController.text.trim(),
    'price': _priceController.text.trim(),
    'category': categoryId,
    'university': universityId,
    'location': _selectedUniversity ?? '',
    'model': _modelController.text.trim(),
  },
  _selectedImages.isNotEmpty
      ? _selectedImages.map((f) => f.path).toList()
      : null,
);
await AnnouncementService.changeStatus(id, _selectedStatus);
// ✅ No markListingAsSold — backend handles completed_sales in changeStatus
         await AnnouncementService.changeStatus(id, _selectedStatus);


        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product updated successfully! ✅')),
        );
        Navigator.pop(context, true);
      } catch (e) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update product: $e')),
        );
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }

    // ── ADD MODE ──
    } else {
      try {
        final compressedImages = await Future.wait(
          _selectedImages.map((img) => _compressImage(img)),
        );
        final apiProduct = await AnnouncementService.createAnnouncement(
          title: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          price: _priceController.text.trim(),
          categoryId: categoryId,
          universityId: universityId,
          location: _selectedUniversity ?? '',
          model: _modelController.text.trim(),
          photos: compressedImages,
        );

        

        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product posted successfully! ✅')),
        );
        Navigator.pop(context);
      } catch (e) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post product: $e')),
        );
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: screenHeight * 0.065,
                        height: screenHeight * 0.065,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F2F2),
                          borderRadius:
                              BorderRadius.circular(screenWidth * 0.08),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.arrow_back,
                            color: Colors.black87,
                            size: screenWidth * 0.055,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          widget.product != null
                              ? 'Edit Product'
                              : 'Add Product',
                          style: TextStyle(
                            fontSize: screenWidth * 0.065,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: screenHeight * 0.065),
                  ],
                ),
                const SizedBox(height: 30),

                _buildTextField(
                  label: 'Product Name',
                  hint: 'Enter your Product Name ....',
                  controller: _nameController,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty)
                      return 'Please enter a correct product name';
                    if (!RegExp(r'[a-zA-Z]').hasMatch(value))
                      return 'Product name must contain letters';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ✅ FIX: model field is optional (no required validator)
                _buildTextField(
                  label: 'Product model',
                  hint: 'Enter Your Product Model ...',
                  controller: _modelController,
                  validator: (_) => null, // optional field
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  label: 'Product price',
                  hint: 'Enter Your Product Price (DA)',
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty)
                      return 'Please enter the product price';
                    if (!RegExp(r'^\d+$').hasMatch(value.trim()))
                      return 'Price must contain only numbers';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  label: 'Product description',
                  hint: '',
                  controller: _descriptionController,
                  maxLines: 5,
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty) {
                      if (!RegExp(r'[a-zA-Z]').hasMatch(value))
                        return 'Description must contain letters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                const Text(
                  'Type',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                _buildTypeSelector(),
                const SizedBox(height: 40),

                const Text(
                  'University',
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                _buildUniversityDropdown(),
                const SizedBox(height: 16),

                const Text(
                  'Product pictures',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildImageUploadPlaceholder(),
                const SizedBox(height: 40),


                if (widget.product != null) ...[
  const Text(
    'Product Status',
    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
  ),
  const SizedBox(height: 8),
  Container(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      border: Border.all(color: Colors.grey),
      borderRadius: BorderRadius.circular(12),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: _selectedStatus,
        isExpanded: true,
        items: const [
          DropdownMenuItem(value: 'active', child: Row(children: [Icon(Icons.check_circle, color: Colors.green, size: 18), SizedBox(width: 8), Text('Active')])),
          DropdownMenuItem(value: 'sold',   child: Row(children: [Icon(Icons.sell,          color: Color(0xff2853af), size: 18), SizedBox(width: 8), Text('Sold')])),
          DropdownMenuItem(value: 'expired',child: Row(children: [Icon(Icons.timer_off,     color: Colors.orange, size: 18), SizedBox(width: 8), Text('Expired')])),
        ],
        onChanged: (val) => setState(() => _selectedStatus = val ?? 'active'),
      ),
    ),
  ),
  const SizedBox(height: 16),
],

                // ── RESERVED TOGGLE (edit mode only) ──
                // if (widget.product != null) ...[
                //   SwitchListTile(
                //     title: const Text(
                //       'Mark as Reserved',
                //       style: TextStyle(fontWeight: FontWeight.bold),
                //     ),
                //     subtitle: const Text(
                //       'Product will appear as reserved in the home feed',
                //       style: TextStyle(color: Colors.grey, fontSize: 12),
                //     ),
                //     value: _isReserved,
                //     activeColor: const Color(0xFF1A73E8),
                //     onChanged: (val) => setState(() => _isReserved = val),
                //   ),
                //   const SizedBox(height: 16),
                // ],

                _buildMainButton(
                  context,
                  widget.product != null ? 'Save Changes' : 'Post product',
                  _isSubmitting ? null : _submitForm,
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    TextEditingController? controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: InputDecoration(
            hintText: hint,
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _types.map((type) {
          final isSelected = type == _selectedType;
          return GestureDetector(
            onTap: () => setState(() => _selectedType = type),
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.blue.withOpacity(0.15)
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isSelected ? Colors.blue : Colors.transparent,
                ),
              ),
              child: Text(
                type,
                style: TextStyle(
                  color: isSelected ? Colors.blue : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final totalAllowed = 10 - _existingImageUrls.length - _selectedImages.length;
    if (source == ImageSource.gallery) {
      final List<XFile> pickedFiles = await _picker.pickMultiImage();
      if (pickedFiles.isNotEmpty) {
        setState(() {
          int added = 0;
          for (var xfile in pickedFiles) {
            if (added < totalAllowed) {
              _selectedImages.add(File(xfile.path));
              added++;
            }
          }
          if (pickedFiles.length > added) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('You can only select up to 10 images.')),
            );
          }
        });
      }
    } else {
      if (totalAllowed <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('You have already added 10 images.')),
        );
        return;
      }
      final XFile? pickedFile =
          await _picker.pickImage(source: source);
      if (pickedFile != null)
        setState(() => _selectedImages.add(File(pickedFile.path)));
    }
  }

  void _showImagePickerBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildBottomSheetOption(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                _buildBottomSheetOption(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomSheetOption({
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

  Widget _buildImageUploadPlaceholder() {
    final hasExisting = _existingImageUrls.isNotEmpty;
    final hasNew = _selectedImages.isNotEmpty;

    if (!hasExisting && !hasNew) {
      return GestureDetector(
        onTap: _showImagePickerBottomSheet,
        child: Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image, size: 70, color: Colors.grey),
              SizedBox(height: 8),
              Text(
                'Tap to add pictures',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final totalCount = _existingImageUrls.length + _selectedImages.length;

    return Column(
      children: [
        SizedBox(
          height: 250,
          child: Stack(
            children: [
              PageView.builder(
                itemCount: totalCount,
                onPageChanged: (index) {
                  setState(() => _currentImageIndex = index);
                },
                itemBuilder: (context, index) {
                  final isExisting = index < _existingImageUrls.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: isExisting
                            ? NetworkImage(
                                    _existingImageUrls[index])
                                as ImageProvider
                            : FileImage(_selectedImages[
                                index - _existingImageUrls.length]),
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentImageIndex + 1} / $totalCount',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      final isExisting =
                          _currentImageIndex < _existingImageUrls.length;
                      if (isExisting) {
                        _existingImageUrls
                            .removeAt(_currentImageIndex);
                      } else {
                        _selectedImages.removeAt(_currentImageIndex -
                            _existingImageUrls.length);
                      }
                      final newTotal = _existingImageUrls.length +
                          _selectedImages.length;
                      if (_currentImageIndex >= newTotal &&
                          _currentImageIndex > 0) {
                        _currentImageIndex--;
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delete_outline,
                        size: 20, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (totalCount < 10) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _showImagePickerBottomSheet,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: Colors.blue.withOpacity(0.5)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Add more pictures',
                      style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildUniversityDropdown() {
    if (_isLoadingUniversities) {
      return Container(
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_universitiesFailed || _universitiesList.isEmpty) {
      return Container(
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade300),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Failed to load universities',
                style: TextStyle(color: Colors.red)),
            const SizedBox(width: 8),
            TextButton(onPressed: _fetchData, child: const Text('Retry')),
          ],
        ),
      );
    }

    return DropdownButtonFormField<String>(
      isExpanded: true,
      decoration: InputDecoration(
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      hint: const Text('Select a University'),
      value: _selectedUniversity,
      items: _universitiesList.map((dynamic u) {
        final String name = (u is Map && u.containsKey('name'))
            ? u['name'].toString()
            : u.toString();
        return DropdownMenuItem<String>(
          value: name,
          child: Text(name, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: (value) => setState(() => _selectedUniversity = value),
      validator: (value) =>
          value == null ? 'Please select a university' : null,
    );
  }

  Widget _buildMainButton(
    BuildContext context,
    String text,
    VoidCallback? onPressed,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              onPressed == null ? Colors.grey : const Color(0xFF1A73E8),
          padding: EdgeInsets.symmetric(vertical: screenHeight * 0.02),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(screenWidth * 0.03),
          ),
          elevation: 0,
        ),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: screenWidth * 0.038,
          ),
        ),
      ),
    );
  }
}
