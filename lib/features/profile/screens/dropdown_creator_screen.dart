import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'dropdown_option_dialog.dart';

class DropdownCreatorScreen extends StatefulWidget {
  const DropdownCreatorScreen({super.key});

  @override
  State<DropdownCreatorScreen> createState() => _DropdownCreatorScreenState();
}

class _DropdownCreatorScreenState extends State<DropdownCreatorScreen> {
  bool _isLoading = false;
  String? _selectedType;
  List<Map<String, dynamic>> _options = [];
  List<Map<String, dynamic>> _problemCategories = [];
  List<Map<String, dynamic>> _problemSubCategories = [];
  List<Map<String, dynamic>> _masterCrops = [];
  int? _selectedParentId;
  int? _selectedSubParentId; // Added for 3-level hierarchy
  bool _tableMissing = false;
  final bool _isUploadingImage = false;

  final Map<String, String> _typeLabels = {
    'farmer_category': 'Farmer Categories',
    'soil_type': 'Soil Types',
    'irrigation_type': 'Irrigation Types',
    'water_source': 'Water Sources',
    'water_quantity': 'Water Quantities',
    'power_source': 'Power Sources',
    'problem_category': 'Problem Categories',
    'problem_subcategory': 'Problem Sub-Categories',
    'problem_item': 'Problem Items (Specific)',
    'master_crop': 'Crops & Varieties',
    'age_unit': 'Age Units',
    'life_unit': 'Life Units',
    'count_unit': 'Count Units',
    'acre_unit': 'Area/Scale Units',
    'yield_unit': 'Yield Units',
    'yield_period': 'Yield Periods (e.g. Per Month)',
    'filler_material': 'Filler Materials (e.g. Water, Soil)',
    'product_name': 'Product Names',
    'application_method': 'Application Methods',
    'dose_unit': 'Dose Units',
    'filler_unit': 'Filler Units',
    'per_unit': 'Per Units (e.g. L, Acre, Plant)',
    'vendor_name': 'Vendors List',
    'stock_vendor': 'Stock (Default Vendors)',
  };

  @override
  void initState() {
    super.initState();
  }

  Future<void> _fetchOptions() async {
    if (_selectedType == null) return;

    setState(() => _isLoading = true);
    try {
      if (_selectedType == 'problem_subcategory') {
        if (_problemCategories.isEmpty) {
          _problemCategories = await SupabaseService.getDropdownOptions(
            'problem_category',
          );
        }
        if (_selectedParentId == null && _problemCategories.isNotEmpty) {
          _selectedParentId = _problemCategories[0]['id'];
        }
        if (_selectedParentId != null) {
          _options = await SupabaseService.getDropdownOptions(
            _selectedType!,
            parentId: _selectedParentId,
          );
        } else {
          _options = [];
        }
      } else if (_selectedType == 'problem_item') {
        if (_problemCategories.isEmpty) {
          _problemCategories = await SupabaseService.getDropdownOptions(
            'problem_category',
          );
        }
        if (_selectedParentId == null && _problemCategories.isNotEmpty) {
          _selectedParentId = _problemCategories[0]['id'];
        }

        // Fetch subcategories for the selected category
        if (_selectedParentId != null) {
          _problemSubCategories = await SupabaseService.getDropdownOptions(
            'problem_subcategory',
            parentId: _selectedParentId,
          );
          if (_selectedSubParentId == null &&
              _problemSubCategories.isNotEmpty) {
            _selectedSubParentId = _problemSubCategories[0]['id'];
          }
        } else {
          _problemSubCategories = [];
          _selectedSubParentId = null;
        }

        if (_selectedSubParentId != null) {
          _options = await SupabaseService.getDropdownOptions(
            _selectedType!,
            parentId: _selectedSubParentId,
          );
        } else {
          _options = [];
        }

        if (_masterCrops.isEmpty) {
          _masterCrops = await SupabaseService.getMasterCrops();
        }
      } else if (_selectedType == 'master_crop') {
        _options = await SupabaseService.getMasterCrops();
      } else if (_selectedType == 'product_name') {
        _options = await SupabaseService.getHierarchicalDropdownOptions(
          'product_name',
        );
      } else if (_selectedType == 'stock_vendor') {
        final products = await SupabaseService.getHierarchicalDropdownOptions(
          'product_name',
        );
        final mappings = await SupabaseService.getDropdownOptions(
          'product_vendor_map',
        );
        _options =
            products.map((p) {
              final mapping = mappings.firstWhere(
                (m) => m['parent_id'] == p['id'],
                orElse: () => {},
              );
              return {
                ...p,
                'default_vendor': mapping['label'] ?? '',
                'mapping_id': mapping['id'],
              };
            }).toList();
      } else {
        _options = await SupabaseService.getDropdownOptions(_selectedType!);
      }
      setState(() => _tableMissing = false);
    } catch (e) {
      if (mounted) {
        final errorStr = e.toString();
        if (errorStr.contains('PGRST205') ||
            errorStr.contains('PGRST200') ||
            errorStr.contains('dropdown_options') ||
            errorStr.contains('master_crops')) {
          setState(() => _tableMissing = true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error fetching options: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String?> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );
    if (image == null) return null;

    final bytes = await image.readAsBytes();
    final fileName = '${const Uuid().v4()}.jpg';
    return await SupabaseService.uploadImage(
      bytes,
      fileName,
      'dropdown_covers',
    );
  }

  Future<void> _addOption() async {
    if (_selectedType == 'master_crop') {
      _addMasterCrop();
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (context) => DropdownOptionDialog(
            title: 'Add ${_typeLabels[_selectedType]}',
            isProductName: _selectedType == 'product_name',
            onPickImage: _pickAndUploadImage,
          ),
    );

    if (result != null && result['label'].isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        final parentToUse =
            (_selectedType == 'problem_item')
                ? _selectedSubParentId
                : _selectedParentId;
        final newOption = await SupabaseService.addDropdownOption(
          _selectedType!,
          result['label'],
          parentId: parentToUse,
          mrp: result['mrp'],
          offerPrice: result['offerPrice'],
          imageUrl: result['imageUrl'],
        );

        if (_selectedType == 'problem_item') {
          await _showCropMappingDialog(newOption);
        }

        await _fetchOptions();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error adding option: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  // --- Hierarchical Crop Methods ---

  Future<void> _addMasterCrop() async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add New Crop'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Crop Name (e.g. Lemon)',
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Add'),
              ),
            ],
          ),
    );

    if (result == true && controller.text.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        await SupabaseService.addMasterCrop(controller.text.trim());
        await _fetchOptions();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error adding crop: $e'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _addOrEditVariety(
    int cropId, [
    Map<String, dynamic>? variety,
  ]) async {
    final varietyController = TextEditingController(
      text: variety?['variety_name'],
    );
    final lifeController = TextEditingController(text: variety?['life']);

    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(variety == null ? 'Add Variety' : 'Edit Variety'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: varietyController,
                  decoration: const InputDecoration(
                    labelText: 'Variety Name',
                    hintText: 'e.g. Alphonso',
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: lifeController,
                  decoration: const InputDecoration(
                    labelText: 'Life Cycle',
                    hintText: 'e.g. 20 Years',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(variety == null ? 'Add' : 'Save'),
              ),
            ],
          ),
    );

    if (result == true && varietyController.text.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        if (variety == null) {
          await SupabaseService.addMasterVariety(
            cropId,
            varietyController.text.trim(),
            lifeController.text.trim(),
          );
        } else {
          await SupabaseService.updateMasterVariety(
            variety['id'],
            varietyController.text.trim(),
            lifeController.text.trim(),
          );
        }
        await _fetchOptions();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving variety: $e'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _deleteMasterCrop(Map<String, dynamic> crop) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Crop'),
            content: Text(
              'Are you sure you want to delete "${crop['name']}" and all its varieties?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await SupabaseService.deleteMasterCrop(crop['id']);
        await _fetchOptions();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting crop: $e'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _deleteMasterVariety(Map<String, dynamic> variety) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Variety'),
            content: Text(
              'Are you sure you want to delete "${variety['variety_name']}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await SupabaseService.deleteMasterVariety(variety['id']);
        await _fetchOptions();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting variety: $e'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  // --- End Hierarchical Crop Methods ---

  Future<void> _editOption(Map<String, dynamic> option) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (context) => DropdownOptionDialog(
            title: 'Edit ${_typeLabels[_selectedType]}',
            initialLabel: option['label'],
            initialImageUrl: option['image_url'],
            initialMrp: option['mrp'],
            initialOfferPrice: option['offer_price'],
            isProductName: _selectedType == 'product_name',
            onPickImage: _pickAndUploadImage,
          ),
    );

    if (result != null && result['label'].isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        await SupabaseService.updateDropdownOption(
          option['id'],
          result['label'],
          mrp: result['mrp'],
          offerPrice: result['offerPrice'],
          imageUrl: result['imageUrl'],
        );
        await _fetchOptions();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating option: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteOption(Map<String, dynamic> option) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirm Delete'),
            content: Text(
              'Are you sure you want to delete "${option['label']}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await SupabaseService.deleteDropdownOption(option['id']);
        await _fetchOptions();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting option: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showCropMappingDialog(Map<String, dynamic> problem) async {
    final existingMappings = await SupabaseService.getCropProblemMappings(
      problem['id'],
    );
    final List<int> selectedCropIds =
        existingMappings.map((m) => m['crop_id'] as int).toList();

    if (!mounted) return;

    await showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text('Link "${problem['label']}" to Crops'),
                content: SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _masterCrops.length,
                    itemBuilder: (context, index) {
                      final crop = _masterCrops[index];
                      final isSelected = selectedCropIds.contains(crop['id']);
                      return CheckboxListTile(
                        title: Text(crop['name']),
                        value: isSelected,
                        activeColor: AppColors.primary,
                        onChanged: (bool? value) {
                          setDialogState(() {
                            if (value == true) {
                              selectedCropIds.add(crop['id']);
                            } else {
                              selectedCropIds.remove(crop['id']);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Skip'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        await SupabaseService.updateCropProblemMappings(
                          problem['id'],
                          selectedCropIds,
                        );
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error saving mappings: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    child: const Text('Save Links'),
                  ),
                ],
              );
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Drop down Creator')),
      body:
          _tableMissing
              ? _buildSetupGuide()
              : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    children: [
                      // Header / Type Selector
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(32),
                            bottomRight: Radius.circular(32),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Select Dropdown Type',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: _selectedType,
                              decoration: const InputDecoration(
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              hint: const Text('Choose a category to manage'),
                              items: [
                                // Farmer Profile
                                const DropdownMenuItem(
                                  enabled: false,
                                  child: Text(
                                    'FARMER PROFILE',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                ...['farmer_category'].map(
                                  (key) => DropdownMenuItem(
                                    value: key,
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 12),
                                      child: Text(_typeLabels[key]!),
                                    ),
                                  ),
                                ),

                                // Farm Registration
                                const DropdownMenuItem(
                                  enabled: false,
                                  child: Text(
                                    'FARM REGISTRATION',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                ...[
                                  'soil_type',
                                  'irrigation_type',
                                  'water_source',
                                  'water_quantity',
                                  'power_source',
                                  'acre_unit',
                                ].map(
                                  (key) => DropdownMenuItem(
                                    value: key,
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 12),
                                      child: Text(_typeLabels[key]!),
                                    ),
                                  ),
                                ),

                                // Report & Analysis
                                const DropdownMenuItem(
                                  enabled: false,
                                  child: Text(
                                    'REPORT & ANALYSIS',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                ...[
                                  'problem_category',
                                  'problem_subcategory',
                                  'problem_item',
                                ].map(
                                  (key) => DropdownMenuItem(
                                    value: key,
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 12),
                                      child: Text(_typeLabels[key]!),
                                    ),
                                  ),
                                ),

                                // Crop & Yield
                                const DropdownMenuItem(
                                  enabled: false,
                                  child: Text(
                                    'CROP & YIELD',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                ...[
                                  'master_crop',
                                  'age_unit',
                                  'life_unit',
                                  'count_unit',
                                  'yield_unit',
                                  'yield_period',
                                ].map(
                                  (key) => DropdownMenuItem(
                                    value: key,
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 12),
                                      child: Text(_typeLabels[key]!),
                                    ),
                                  ),
                                ),

                                // Product & Treatment
                                const DropdownMenuItem(
                                  enabled: false,
                                  child: Text(
                                    'PRODUCT & TREATMENT',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                ...[
                                  'product_name',
                                  'filler_material',
                                  'application_method',
                                  'dose_unit',
                                  'filler_unit',
                                  'per_unit',
                                ].map(
                                  (key) => DropdownMenuItem(
                                    value: key,
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 12),
                                      child: Text(_typeLabels[key]!),
                                    ),
                                  ),
                                ),

                                // Stock Management
                                const DropdownMenuItem(
                                  enabled: false,
                                  child: Text(
                                    'STOCK',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                ...['vendor_name', 'stock_vendor'].map(
                                  (key) => DropdownMenuItem(
                                    value: key,
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 12),
                                      child: Text(_typeLabels[key]!),
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (v) {
                                setState(() {
                                  _selectedType = v;
                                  _selectedParentId = null;
                                  _options = [];
                                });
                                _fetchOptions();
                              },
                            ),
                            if (_selectedType == 'problem_subcategory' ||
                                _selectedType == 'problem_item') ...[
                              const SizedBox(height: 16),
                              const Text(
                                'Select Parent Category',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<int>(
                                value: _selectedParentId,
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                items:
                                    _problemCategories
                                        .map(
                                          (c) => DropdownMenuItem<int>(
                                            value: c['id'],
                                            child: Text(c['label']),
                                          ),
                                        )
                                        .toList(),
                                onChanged: (v) {
                                  setState(() {
                                    _selectedParentId = v;
                                    _selectedSubParentId = null;
                                  });
                                  _fetchOptions();
                                },
                              ),
                            ],
                            if (_selectedType == 'problem_item') ...[
                              const SizedBox(height: 16),
                              const Text(
                                'Select Parent Sub-Category',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<int>(
                                value: _selectedSubParentId,
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                items:
                                    _problemSubCategories
                                        .map(
                                          (c) => DropdownMenuItem<int>(
                                            value: c['id'],
                                            child: Text(c['label']),
                                          ),
                                        )
                                        .toList(),
                                onChanged: (v) {
                                  setState(() => _selectedSubParentId = v);
                                  _fetchOptions();
                                },
                              ),
                            ],
                          ],
                        ),
                      ),

                      // List View (Combined for flat and hierarchical)
                      Expanded(
                        child:
                            _isLoading
                                ? const Center(
                                  child: CircularProgressIndicator(),
                                )
                                : _selectedType == null
                                ? const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.list_alt_rounded,
                                        size: 64,
                                        color: AppColors.secondary,
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        'Please select a dropdown type above',
                                        style: TextStyle(
                                          color: AppColors.textGray,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                : _options.isEmpty
                                ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text(
                                        'No options found for this category',
                                      ),
                                      const SizedBox(height: 16),
                                      ElevatedButton.icon(
                                        onPressed: _addOption,
                                        icon: const Icon(Icons.add),
                                        label: const Text('Add First Option'),
                                      ),
                                    ],
                                  ),
                                )
                                : _selectedType == 'master_crop'
                                ? _buildCropListView()
                                : _selectedType == 'product_name'
                                ? _buildHierarchicalProductView()
                                : _selectedType == 'stock_vendor'
                                ? _buildStockVendorView()
                                : _buildFlatListView(),
                      ),
                    ],
                  ),
                ),
              ),
      floatingActionButton:
          _selectedType != null && !_isLoading && !_tableMissing
              ? FloatingActionButton.extended(
                heroTag: 'dropdown_fab',
                onPressed: _addOption,
                label: Text(
                  _selectedType == 'master_crop'
                      ? 'Add New Category'
                      : 'Add Option',
                ),
                icon: const Icon(Icons.add),
                backgroundColor: AppColors.primary,
              )
              : null,
    );
  }

  Widget _buildStockVendorView() {
    if (_options.isEmpty) {
      return const Center(child: Text('No products found to map vendors to.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _options.length,
      itemBuilder: (context, index) {
        final item = _options[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: AppColors.secondary,
                child: Icon(
                  Icons.inventory_2_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['label'] ?? 'Unknown Product',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['default_vendor'].isEmpty
                          ? 'No default vendor set'
                          : 'Vendor: ${item['default_vendor']}',
                      style: TextStyle(
                        color:
                            item['default_vendor'].isEmpty
                                ? Colors.grey
                                : AppColors.primary,
                        fontSize: 13,
                        fontStyle:
                            item['default_vendor'].isEmpty
                                ? FontStyle.italic
                                : FontStyle.normal,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.edit_note_rounded,
                  color: AppColors.primary,
                ),
                onPressed: () => _editStockVendor(item),
                tooltip: 'Set Default Vendor',
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editStockVendor(Map<String, dynamic> item) async {
    setState(() => _isLoading = true);
    List<Map<String, dynamic>> vendors = [];
    try {
      vendors = await SupabaseService.getDropdownOptions('vendor_name');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching vendors: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = false);

    if (vendors.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please create Vendors first from "Vendors List".'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    String? selectedVendor = item['default_vendor'];
    if (selectedVendor != null && selectedVendor.isEmpty) {
      selectedVendor = null;
    }
    if (selectedVendor != null && !vendors.any((v) => v['label'] == selectedVendor)) {
      selectedVendor = null;
    }

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Set Vendor for ${item['label']}'),
              content: DropdownButtonFormField<String>(
                value: selectedVendor,
                decoration: const InputDecoration(
                  labelText: 'Select Vendor',
                ),
                items: vendors
                    .map(
                      (v) => DropdownMenuItem<String>(
                        value: v['label'],
                        child: Text(v['label']),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  setDialogState(() {
                    selectedVendor = val;
                  });
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, selectedVendor),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() => _isLoading = true);
      try {
        if (item['mapping_id'] != null) {
          // Update existing
          await SupabaseService.updateDropdownOption(
            item['mapping_id'],
            result.trim(),
          );
        } else {
          // Add new
          await SupabaseService.addDropdownOption(
            'product_vendor_map',
            result.trim(),
            parentId: item['id'],
          );
        }
        await _fetchOptions();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving vendor: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildFlatListView() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _options.length,
      itemBuilder: (context, index) {
        final option = _options[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              if (option['image_url'] != null)
                Container(
                  width: 50,
                  height: 50,
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: Image.network(option['image_url']).image,
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else
                Container(
                  width: 50,
                  height: 50,
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.image_not_supported_outlined,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option['label'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (option['mrp'] != null)
                      Text(
                        'MRP: ₹${option['mrp']} | Offer: ₹${option['offer_price']}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textGray,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                onPressed: () => _editOption(option),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red,
                  size: 20,
                ),
                onPressed: () => _deleteOption(option),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCropListView() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _options.length,
      itemBuilder: (context, index) {
        final crop = _options[index];
        final List varieties = crop['master_crop_varieties'] ?? [];

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.secondary.withOpacity(0.5),
                child: const Icon(
                  Icons.eco_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              title: Text(
                crop['name'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              subtitle: Text('${varieties.length} varieties established'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.black26,
                      size: 18,
                    ),
                    onPressed: () => _deleteMasterCrop(crop),
                  ),
                  const Icon(Icons.expand_more_rounded),
                ],
              ),
              children: [
                const Divider(height: 1, indent: 16, endIndent: 16),
                ...varieties.map(
                  (v) => ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 4,
                    ),
                    title: Text(
                      v['variety_name'],
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text('Expected Life: ${v['life'] ?? 'Not set'}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: AppColors.primary,
                            size: 18,
                          ),
                          onPressed: () => _addOrEditVariety(crop['id'], v),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.red,
                            size: 18,
                          ),
                          onPressed: () => _deleteMasterVariety(v),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextButton.icon(
                    onPressed: () => _addOrEditVariety(crop['id']),
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    label: const Text('Add Variety for this Crop'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHierarchicalProductView() {
    if (_options.isEmpty) {
      return const Center(
        child: Text('No products found. Add one to get started.'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _options.length,
      itemBuilder: (context, index) {
        final product = _options[index];
        final List variants = product['variants'] ?? [];

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.secondary.withOpacity(0.5),
                child: const Icon(
                  Icons.inventory_2_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              title: Text(
                product['label'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              subtitle: Text('${variants.length} package sizes available'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.black26,
                      size: 18,
                    ),
                    onPressed: () => _deleteOption(product),
                  ),
                  const Icon(Icons.expand_more_rounded),
                ],
              ),
              children: [
                const Divider(height: 1, indent: 16, endIndent: 16),
                ...variants.map(
                  (v) => ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 4,
                    ),
                    title: Text(
                      v['label'],
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'MRP: ₹${v['mrp'] ?? 0} | Offer: ₹${v['offer_price'] ?? 0}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: AppColors.primary,
                            size: 18,
                          ),
                          onPressed: () => _editVariant(product['id'], v),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.red,
                            size: 18,
                          ),
                          onPressed: () => _deleteOption(v),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Wrap(
                    alignment: WrapAlignment.spaceEvenly,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      TextButton.icon(
                        onPressed: () => _addVariant(product['id']),
                        icon: const Icon(Icons.add_circle_outline_rounded),
                        label: const Text('Add Package Size'),
                      ),
                      TextButton.icon(
                        onPressed: () => _editOption(product),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit Product Name'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _addVariant(int productId) async {
    final controller = TextEditingController();
    final mrpController = TextEditingController();
    final offerController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add Package Size'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Size (e.g. 500ml)',
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: mrpController,
                        decoration: const InputDecoration(labelText: 'MRP'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: offerController,
                        decoration: const InputDecoration(
                          labelText: 'Offer Price',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Add'),
              ),
            ],
          ),
    );

    if (result == true && controller.text.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        await SupabaseService.addDropdownOption(
          'product_name',
          controller.text.trim(),
          parentId: productId,
          mrp: double.tryParse(mrpController.text),
          offerPrice: double.tryParse(offerController.text),
        );
        await _fetchOptions();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error adding variant: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _editVariant(int productId, Map<String, dynamic> variant) async {
    final controller = TextEditingController(text: variant['label']);
    final mrpController = TextEditingController(
      text: variant['mrp']?.toString(),
    );
    final offerController = TextEditingController(
      text: variant['offer_price']?.toString(),
    );

    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Edit Package Size'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Size (e.g. 500ml)',
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: mrpController,
                        decoration: const InputDecoration(labelText: 'MRP'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: offerController,
                        decoration: const InputDecoration(
                          labelText: 'Offer Price',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Save'),
              ),
            ],
          ),
    );

    if (result == true && controller.text.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        await SupabaseService.updateDropdownOption(
          variant['id'],
          controller.text.trim(),
          mrp: double.tryParse(mrpController.text),
          offerPrice: double.tryParse(offerController.text),
        );
        await _fetchOptions();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating variant: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildSetupGuide() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
            size: 64,
          ),
          const SizedBox(height: 24),
          const Text(
            'Database Setup Required',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            'The required tables (dropdown_options, master_crops, or varieties) were not found. Please run this combined SQL in your Supabase Editor:',
            style: TextStyle(color: AppColors.textGray, height: 1.5),
          ),
          const SizedBox(height: 32),
          _stepItem(1, 'Open your Supabase Dashboard'),
          _stepItem(2, 'Go to the SQL Editor'),
          _stepItem(3, 'Paste the following SQL and click "Run":'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            child: const SelectableText(
              '-- 1. Create main dropdown table\n'
              'create table if not exists public.dropdown_options (\n'
              '  id bigint generated by default as identity primary key,\n'
              '  type text not null,\n'
              '  label text not null,\n'
              '  parent_id bigint references public.dropdown_options(id) on delete cascade,\n'
              '  image_url text,\n'
              '  created_at timestamptz default now()\n'
              ');\n\n'
              '-- 2. Create hierarchical crop tables\n'
              'create table if not exists public.master_crops (\n'
              '  id bigint generated by default as identity primary key,\n'
              '  name text not null unique,\n'
              '  created_at timestamptz default now()\n'
              ');\n\n'
              'create table if not exists public.master_crop_varieties (\n'
              '  id bigint generated by default as identity primary key,\n'
              '  crop_id bigint references public.master_crops(id) on delete cascade,\n'
              '  variety_name text not null,\n'
              '  life text,\n'
              '  created_at timestamptz default now()\n'
              ');\n\n'
              '-- 3. Insert initial dropdown data\n'
              'insert into public.dropdown_options (type, label) values \n'
              "('farmer_category', 'Hot'), ('farmer_category', 'Warm'), ('farmer_category', 'Cold'),\n"
              "('soil_type', 'Red'), ('soil_type', 'Black'), ('soil_type', 'Loomy'), ('soil_type', 'Aluvial'),\n"
              "('irrigation_type', 'Flood'), ('irrigation_type', 'Drip irrigation'),\n"
              "('water_source', 'Well'), ('water_source', 'Borewell'), ('water_source', 'canal/Pond'), ('water_source', 'River/Stream'),\n"
              "('water_quantity', 'Ample'), ('water_quantity', 'surplus'), ('water_quantity', 'Scarcity'),\n"
              "('power_source', 'EB'), ('power_source', 'Diesel Pump'), ('power_source', 'Solar'),\n"
              "('problem_category', 'Pests'), ('problem_category', 'Diseases'), ('problem_category', 'Deficiency'), ('problem_category', 'Others'),\n"
              "('age_unit', 'Years'), ('age_unit', 'Months'),\n"
              "('life_unit', 'Years'), ('life_unit', 'Months'),\n"
              "('count_unit', 'Plants'), ('count_unit', 'Saplings'),\n"
              "('acre_unit', 'Acres'), ('acre_unit', 'Cent'),\n"
              "('yield_unit', 'Tons'), ('yield_unit', 'Kg'), ('yield_unit', 'Quintals')\n"
              'on conflict do nothing;',
              style: TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              setState(() => _tableMissing = false);
              _fetchOptions();
            },
            child: const Text('I have run the SQL, check again'),
          ),
        ],
      ),
    );
  }

  Widget _stepItem(int num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AppColors.primary,
            child: Text(
              num.toString(),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
