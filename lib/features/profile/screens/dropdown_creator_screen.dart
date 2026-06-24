import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'dropdown_option_dialog.dart';
import 'package:nature_biotic/services/local_database_service.dart';
import 'package:nature_biotic/services/sync_manager.dart';

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
  List<Map<String, dynamic>> _masterCrops = [];
  int? _selectedParentId;
  bool _tableMissing = false;
  int? _uploadingCropId;
  int? _uploadingProductId;
  int? _uploadingOptionId;

  // Billing Config variables
  final _billingFormKey = GlobalKey<FormState>();
  final _accountNameController = TextEditingController();
  final _accountNoController = TextEditingController();
  final _ifscCodeController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _branchController = TextEditingController();
  final _companyGstinController = TextEditingController();
  String? _qrUrl;
  String? _signatureUrl;
  bool _isUploadingQr = false;
  bool _isUploadingSignature = false;

  final Map<String, String> _typeLabels = {
    'farmer_category': 'Farmer Categories',
    'soil_type': 'Soil Types',
    'irrigation_type': 'Irrigation Types',
    'water_source': 'Water Sources',
    'water_quantity': 'Water Quantities',
    'power_source': 'Power Sources',
    'problem_category': 'Problem Categories',
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
    'billing_config': 'Billing Details',
    'place_of_supply': 'Place of Supply',
    'farmer_gst': 'Farmer GST Mappings',
  };

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _accountNameController.dispose();
    _accountNoController.dispose();
    _ifscCodeController.dispose();
    _bankNameController.dispose();
    _branchController.dispose();
    _companyGstinController.dispose();
    super.dispose();
  }

  Future<void> _loadBillingConfig() async {
    setState(() => _isLoading = true);
    try {
      final config = await SupabaseService.getBillingConfig();
      _accountNameController.text = config['account_name'] ?? '';
      _accountNoController.text = config['account_no'] ?? '';
      _ifscCodeController.text = config['ifsc_code'] ?? '';
      _bankNameController.text = config['bank_name'] ?? '';
      _branchController.text = config['branch'] ?? '';
      _companyGstinController.text = config['company_gstin'] ?? config['gstin'] ?? '';
      setState(() {
        _qrUrl = config['qr_url'] ?? '';
        _signatureUrl = config['signature_url'] ?? '';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading billing config: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadImageForBilling({required bool isQr}) async {
    try {
      setState(() {
        if (isQr) {
          _isUploadingQr = true;
        } else {
          _isUploadingSignature = true;
        }
      });

      final url = await _pickAndUploadImage();
      if (url != null) {
        setState(() {
          if (isQr) {
            _qrUrl = url;
          } else {
            _signatureUrl = url;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        if (isQr) {
          _isUploadingQr = false;
        } else {
          _isUploadingSignature = false;
        }
      });
    }
  }

  Future<void> _saveBillingConfig() async {
    if (!_billingFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final config = {
        'account_name': _accountNameController.text.trim(),
        'account_no': _accountNoController.text.trim(),
        'ifsc_code': _ifscCodeController.text.trim(),
        'bank_name': _bankNameController.text.trim(),
        'branch': _branchController.text.trim(),
        'company_gstin': _companyGstinController.text.trim(),
        'qr_url': _qrUrl ?? '',
        'signature_url': _signatureUrl ?? '',
      };
      await SupabaseService.saveBillingConfig(config);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Billing details saved successfully!'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving billing details: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildBillingConfigEditor() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _billingFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bank Account Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _accountNameController,
              decoration: const InputDecoration(
                labelText: 'Account Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (val) =>
                  val == null || val.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _accountNoController,
              decoration: const InputDecoration(
                labelText: 'Account Number',
                prefixIcon: Icon(Icons.account_balance_wallet_outlined),
              ),
              validator: (val) =>
                  val == null || val.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ifscCodeController,
              decoration: const InputDecoration(
                labelText: 'IFSC Code',
                prefixIcon: Icon(Icons.code_outlined),
              ),
              validator: (val) =>
                  val == null || val.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bankNameController,
              decoration: const InputDecoration(
                labelText: 'Bank Name',
                prefixIcon: Icon(Icons.account_balance_outlined),
              ),
              validator: (val) =>
                  val == null || val.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _branchController,
              decoration: const InputDecoration(
                labelText: 'Branch',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              validator: (val) =>
                  val == null || val.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _companyGstinController,
              decoration: const InputDecoration(
                labelText: 'Company GSTIN',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              validator: (val) =>
                  val == null || val.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 32),
            const Text(
              'Payment QR Code & Signature',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // QR Code Upload
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'Payment QR Code',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _isUploadingQr ? null : () => _uploadImageForBilling(isQr: true),
                        child: Container(
                          height: 150,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: _isUploadingQr
                              ? const Center(child: CircularProgressIndicator())
                              : _qrUrl != null && _qrUrl!.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(15),
                                      child: Image.network(
                                        _qrUrl!,
                                        fit: BoxFit.contain,
                                      ),
                                    )
                                  : const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.qr_code_2_rounded,
                                          size: 48,
                                          color: Colors.grey,
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'Tap to upload QR',
                                          style: TextStyle(color: Colors.grey, fontSize: 12),
                                        ),
                                      ],
                                    ),
                        ),
                      ),
                      if (_qrUrl != null && _qrUrl!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        TextButton.icon(
                          onPressed: () => setState(() => _qrUrl = ''),
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 16),
                          label: const Text('Remove', style: TextStyle(color: Colors.red, fontSize: 12)),
                        ),
                      ]
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                // Signature Upload
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'Authorized Signature',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _isUploadingSignature ? null : () => _uploadImageForBilling(isQr: false),
                        child: Container(
                          height: 150,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: _isUploadingSignature
                              ? const Center(child: CircularProgressIndicator())
                              : _signatureUrl != null && _signatureUrl!.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(15),
                                      child: Image.network(
                                        _signatureUrl!,
                                        fit: BoxFit.contain,
                                      ),
                                    )
                                  : const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.draw_rounded,
                                          size: 48,
                                          color: Colors.grey,
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'Tap to upload Signature',
                                          style: TextStyle(color: Colors.grey, fontSize: 12),
                                        ),
                                      ],
                                    ),
                        ),
                      ),
                      if (_signatureUrl != null && _signatureUrl!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        TextButton.icon(
                          onPressed: () => setState(() => _signatureUrl = ''),
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 16),
                          label: const Text('Remove', style: TextStyle(color: Colors.red, fontSize: 12)),
                        ),
                      ]
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _saveBillingConfig,
                icon: const Icon(Icons.save),
                label: const Text(
                  'Save Billing Details',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchOptions({bool showLoader = true}) async {
    if (_selectedType == null) return;

    if (showLoader) {
      setState(() => _isLoading = true);
    }
    try {
      if (_selectedType == 'problem_item') {
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
            errorStr.contains('master_crops') ||
            errorStr.contains('product_dropdown_mapping')) {
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
    try {
      Uint8List? bytes;
      String? name;

      if (kIsWeb) {
        debugPrint('[ImageUpload] Picking image on Web...');
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
        );
        if (result == null || result.files.isEmpty) {
          debugPrint('[ImageUpload] Web picker returned null or empty files');
          return null;
        }
        final file = result.files.first;
        bytes = file.bytes;
        name = file.name;
        debugPrint('[ImageUpload] Web picked file: $name, size: ${bytes?.length} bytes');
      } else {
        debugPrint('[ImageUpload] Picking image on Mobile...');
        final picker = ImagePicker();
        final image = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 50,
        );
        if (image == null) {
          debugPrint('[ImageUpload] Mobile picker returned null');
          return null;
        }
        bytes = await image.readAsBytes();
        name = image.name;
        debugPrint('[ImageUpload] Mobile picked file: $name, size: ${bytes.length} bytes');
      }

      if (bytes == null) throw 'Failed to read image bytes';

      final extension = name.split('.').last.toLowerCase();
      final fileName = '${const Uuid().v4()}.$extension';
      
      debugPrint('[ImageUpload] Uploading $fileName to bucket: dropdown_covers...');
      final url = await SupabaseService.uploadImage(
        bytes,
        fileName,
        'dropdown_covers',
      );
      debugPrint('[ImageUpload] Upload success. Public URL: $url');
      return url;
    } catch (e) {
      debugPrint('[ImageUpload] Error in _pickAndUploadImage: $e');
      rethrow;
    }
  }

  Future<void> _addOption() async {
    if (_selectedType == 'master_crop') {
      _addMasterCrop();
      return;
    }
    if (_selectedType == 'farmer_gst') {
      _addFarmerGst();
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
        final newOption = await SupabaseService.addDropdownOption(
          _selectedType!,
          result['label'],
          parentId: _selectedParentId,
          mrp: result['mrp'],
          offerPrice: result['offerPrice'],
          imageUrl: result['imageUrl'],
          taxPercentage: result['taxPercentage'],
          hsnCode: result['hsnCode'],
          description: result['description'],
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
    final isProduct = _selectedType == 'product_name';
    final isParent = option['parent_id'] == null;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (context) => DropdownOptionDialog(
            title: 'Edit ${_typeLabels[_selectedType]}',
            initialLabel: option['label'],
            initialImageUrl: option['image_url'],
            initialMrp: option['mrp'],
            initialOfferPrice: option['offer_price'],
            initialTaxPercentage: option['tax_percentage'] != null ? (option['tax_percentage'] as num).toDouble() : null,
            initialHsnCode: option['hsn_code'],
            initialDescription: option['description'],
            isProductName: isProduct,
            showCascadeOption: isProduct && isParent,
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
          taxPercentage: result['taxPercentage'],
          hsnCode: result['hsnCode'],
          description: result['description'],
        );
        if (isProduct && isParent && result['applyToVariants'] == true) {
          await SupabaseService.updateVariantsTaxHsnAndDesc(
            option['id'],
            taxPercentage: result['taxPercentage'],
            hsnCode: result['hsnCode'] ?? '',
            description: result['description'] ?? '',
          );
        }
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

  Future<void> _showProblemMappingDialog(Map<String, dynamic> crop) async {
    setState(() => _isLoading = true);
    List<Map<String, dynamic>> allProblems = [];
    List<Map<String, dynamic>> existingMappings = [];
    try {
      if (_problemCategories.isEmpty) {
        _problemCategories = await SupabaseService.getDropdownOptions('problem_category');
      }
      allProblems = await SupabaseService.getDropdownOptions('problem_item');
      existingMappings = await SupabaseService.getProblemsByCrop(crop['id']);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading mapping data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = false);

    final List<int> selectedProblemIds = existingMappings
        .map((m) => m['problem_id'] as int)
        .toList();

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          String query = '';
          return AlertDialog(
            title: Text('Link Problems to "${crop['name']}"'),
            content: StatefulBuilder(
              builder: (context, setInnerState) {
                final filteredProblems = allProblems.where((p) {
                  return p['label'].toString().toLowerCase().contains(query.toLowerCase());
                }).toList();

                return SizedBox(
                  width: double.maxFinite,
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search problem items...',
                          prefixIcon: Icon(Icons.search),
                          isDense: true,
                        ),
                        onChanged: (val) {
                          setInnerState(() {
                            query = val;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: filteredProblems.isEmpty
                            ? const Center(child: Text('No problems found'))
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: filteredProblems.length,
                                itemBuilder: (context, index) {
                                  final problem = filteredProblems[index];
                                  final isSelected = selectedProblemIds.contains(problem['id']);
                                  
                                  final parentCat = _problemCategories.firstWhere(
                                    (c) => c['id'] == problem['parent_id'],
                                    orElse: () => {},
                                  );
                                  final catLabel = parentCat.isNotEmpty ? ' (${parentCat['label']})' : '';

                                  return CheckboxListTile(
                                    title: Text(problem['label']),
                                    subtitle: catLabel.isNotEmpty
                                        ? Text(
                                            parentCat['label'],
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          )
                                        : null,
                                    value: isSelected,
                                    activeColor: AppColors.primary,
                                    onChanged: (bool? value) {
                                      setDialogState(() {
                                        if (value == true) {
                                          selectedProblemIds.add(problem['id']);
                                        } else {
                                          selectedProblemIds.remove(problem['id']);
                                        }
                                      });
                                      setInnerState(() {});
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  setState(() => _isLoading = true);
                  try {
                    await SupabaseService.updateProblemsForCrop(
                      crop['id'],
                      selectedProblemIds,
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Crop mappings updated successfully!'),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error saving mappings: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _isLoading = false);
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

                                // Billing details
                                const DropdownMenuItem(
                                  enabled: false,
                                  child: Text(
                                    'BILLING',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                 ...['billing_config', 'place_of_supply', 'farmer_gst'].map(
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
                                if (v == 'billing_config') {
                                  _loadBillingConfig();
                                } else {
                                  _fetchOptions();
                                }
                              },
                            ),
                            if (_selectedType == 'problem_item') ...[
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
                                  });
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
                                : _selectedType == 'billing_config'
                                ? _buildBillingConfigEditor()
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
                                : _selectedType == 'farmer_gst'
                                ? _buildFarmerGstView()
                                : _buildFlatListView(),
                      ),
                    ],
                  ),
                ),
              ),
      floatingActionButton:
          _selectedType != null && !_isLoading && !_tableMissing && _selectedType != 'billing_config'
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
                        'MRP: ₹${option['mrp']} | Offer: ₹${option['offer_price']}${option['tax_percentage'] != null ? ' | Tax: ${option['tax_percentage']}%' : ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textGray,
                        ),
                      )
                    else if (option['tax_percentage'] != null)
                      Text(
                        'Tax: ${option['tax_percentage']}%',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textGray,
                        ),
                      ),
                  ],
                ),
              ),
              if (_selectedType == 'place_of_supply')
                IconButton(
                  icon: const Icon(
                    Icons.people_outline_rounded,
                    color: Colors.orange,
                    size: 20,
                  ),
                  tooltip: 'Map Farmers',
                  onPressed: () => _mapFarmersToPlaceOfSupply(option),
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

  Future<void> _mapFarmersToPlaceOfSupply(Map<String, dynamic> option) async {
    setState(() => _isLoading = true);
    List<Map<String, dynamic>> farmers = [];
    try {
      farmers = await SupabaseService.getFarmers();
    } catch (e) {
      debugPrint('Error fetching farmers: $e');
    } finally {
      setState(() => _isLoading = false);
    }

    if (farmers.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No farmers found.')),
        );
      }
      return;
    }

    if (!mounted) return;

    final placeName = option['label'].toString();
    final List<String> initialMappedIds = farmers
        .where((f) => f['place_of_supply']?.toString() == placeName)
        .map((f) => f['id'].toString())
        .toList();
        
    List<String> selectedIds = List.from(initialMappedIds);
    String searchQuery = '';

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredFarmers = farmers.where((f) {
              final name = (f['name'] ?? '').toString().toLowerCase();
              final mobile = (f['mobile'] ?? '').toString().toLowerCase();
              final village = (f['village'] ?? '').toString().toLowerCase();
              final q = searchQuery.toLowerCase();
              return name.contains(q) || mobile.contains(q) || village.contains(q);
            }).toList();

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Map Farmers to $placeName',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select farmers belonging to this place of supply.',
                    style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              content: SizedBox(
                width: 400,
                height: 450,
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search by name, phone or village...',
                        prefixIcon: const Icon(Icons.search),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      onChanged: (val) {
                        setDialogState(() {
                          searchQuery = val;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: filteredFarmers.isEmpty
                          ? const Center(child: Text('No matching farmers found.'))
                          : ListView.builder(
                              itemCount: filteredFarmers.length,
                              itemBuilder: (context, idx) {
                                final farmer = filteredFarmers[idx];
                                final fId = farmer['id'].toString();
                                final isChecked = selectedIds.contains(fId);
                                
                                return CheckboxListTile(
                                  value: isChecked,
                                  title: Text(
                                    farmer['name'] ?? 'N/A',
                                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  subtitle: Text(
                                    '${farmer['village'] ?? ''} • ${farmer['mobile'] ?? ''}',
                                    style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
                                  ),
                                  onChanged: (val) {
                                    setDialogState(() {
                                      if (val == true) {
                                        selectedIds.add(fId);
                                      } else {
                                        selectedIds.remove(fId);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    setState(() => _isLoading = true);
                    try {
                      final toAdd = selectedIds.where((id) => !initialMappedIds.contains(id)).toList();
                      final toRemove = initialMappedIds.where((id) => !selectedIds.contains(id)).toList();

                      int updateCount = 0;

                      for (final id in toAdd) {
                        final farmerObj = farmers.firstWhere((f) => f['id'].toString() == id);
                        if (kIsWeb) {
                          await SupabaseService.updateFarmer(id, {'place_of_supply': placeName});
                        } else {
                          final localData = await LocalDatabaseService.getDataById('farmers', id) ?? farmerObj;
                          await LocalDatabaseService.saveAndQueue(
                            tableName: 'farmers',
                            data: {...localData, 'place_of_supply': placeName},
                            operation: 'UPDATE',
                          );
                        }
                        updateCount++;
                      }

                      for (final id in toRemove) {
                        final farmerObj = farmers.firstWhere((f) => f['id'].toString() == id);
                        if (kIsWeb) {
                          await SupabaseService.updateFarmer(id, {'place_of_supply': null});
                        } else {
                          final localData = await LocalDatabaseService.getDataById('farmers', id) ?? farmerObj;
                          await LocalDatabaseService.saveAndQueue(
                            tableName: 'farmers',
                            data: {...localData, 'place_of_supply': null},
                            operation: 'UPDATE',
                          );
                        }
                        updateCount++;
                      }

                      if (!kIsWeb && updateCount > 0) {
                        SyncManager().sync();
                      }

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Successfully updated $updateCount farmer mappings.'),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error mapping farmers: $e'), backgroundColor: Colors.red),
                        );
                      }
                    } finally {
                      setState(() => _isLoading = false);
                    }
                  },
                  child: const Text('Save Mappings'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFarmerGstView() {
    if (_options.isEmpty) {
      return const Center(child: Text('No farmer GST mappings found.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _options.length,
      itemBuilder: (context, index) {
        final option = _options[index];
        String farmerName = 'Unknown Farmer';
        String gstin = 'N/A';
        String placeOfSupply = 'N/A';
        
        try {
          final desc = jsonDecode(option['description'] ?? '{}') as Map<String, dynamic>;
          farmerName = desc['farmer_name']?.toString() ?? 'Unknown Farmer';
          gstin = desc['gstin']?.toString() ?? 'N/A';
          placeOfSupply = desc['place_of_supply']?.toString() ?? 'N/A';
        } catch (_) {}

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
                  Icons.person_pin_rounded,
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
                      farmerName,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textBlack,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'GSTIN: $gstin | Place of Supply: $placeOfSupply',
                      style: GoogleFonts.outfit(
                        color: AppColors.textGray,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                onPressed: () => _addFarmerGst(existingOption: option),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Mapping'),
                      content: const Text('Are you sure you want to delete this GST mapping?'),
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
                          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                        );
                      }
                    } finally {
                      setState(() => _isLoading = false);
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addFarmerGst({Map<String, dynamic>? existingOption}) async {
    setState(() => _isLoading = true);
    List<Map<String, dynamic>> farmers = [];
    List<String> placesOfSupply = [];
    try {
      farmers = await SupabaseService.getFarmers();
      final supplyOptions = await SupabaseService.getDropdownOptions('place_of_supply');
      placesOfSupply = supplyOptions.map((e) => e['label'].toString()).toList();
    } catch (e) {
      debugPrint('Error loading dependencies: $e');
    } finally {
      setState(() => _isLoading = false);
    }

    if (farmers.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No farmers found. Please create farmers first.')),
        );
      }
      return;
    }

    String? selectedFarmerId;
    String gstin = '';
    String? selectedPlaceOfSupply;

    if (existingOption != null) {
      selectedFarmerId = existingOption['label'];
      try {
        final desc = jsonDecode(existingOption['description'] ?? '{}') as Map<String, dynamic>;
        gstin = desc['gstin']?.toString() ?? '';
        selectedPlaceOfSupply = desc['place_of_supply']?.toString() ?? '';
      } catch (_) {}
    }

    final gstinCont = TextEditingController(text: gstin);

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(existingOption == null ? 'Add Farmer GST Mapping' : 'Edit GST Mapping'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (existingOption == null) ...[
                      DropdownButtonFormField<String>(
                        value: selectedFarmerId,
                        decoration: const InputDecoration(labelText: 'Select Farmer'),
                        items: farmers.map((f) {
                          return DropdownMenuItem(
                            value: f['id'].toString(),
                            child: Text(f['name']?.toString() ?? 'N/A'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setDialogState(() {
                            selectedFarmerId = val;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      Builder(builder: (context) {
                        final farmerObj = farmers.firstWhere(
                          (f) => f['id'].toString() == selectedFarmerId,
                          orElse: () => {},
                        );
                        final name = farmerObj['name']?.toString() ?? 'Farmer';
                        return Text('Farmer: $name', style: const TextStyle(fontWeight: FontWeight.bold));
                      }),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: gstinCont,
                      decoration: const InputDecoration(labelText: 'GSTIN'),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedPlaceOfSupply,
                      decoration: const InputDecoration(labelText: 'Place of Supply'),
                      items: placesOfSupply.map((p) {
                        return DropdownMenuItem(
                          value: p,
                          child: Text(p),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() {
                          selectedPlaceOfSupply = val;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedFarmerId == null ||
                        gstinCont.text.trim().isEmpty ||
                        selectedPlaceOfSupply == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill all fields')),
                      );
                      return;
                    }
                    Navigator.pop(context);
                    
                    setState(() => _isLoading = true);
                    try {
                      final farmerObj = farmers.firstWhere(
                        (f) => f['id'].toString() == selectedFarmerId,
                        orElse: () => {},
                      );
                      final name = farmerObj['name']?.toString() ?? 'Farmer';
                      final desc = jsonEncode({
                        'gstin': gstinCont.text.trim(),
                        'place_of_supply': selectedPlaceOfSupply,
                        'farmer_name': name,
                      });

                      if (existingOption == null) {
                        final alreadyExists = _options.any((o) => o['label'] == selectedFarmerId);
                        if (alreadyExists) {
                          throw 'Mapping for this farmer already exists. Edit the existing one instead.';
                        }

                        await SupabaseService.addDropdownOption(
                          'farmer_gst',
                          selectedFarmerId!,
                          description: desc,
                        );
                      } else {
                        await SupabaseService.updateDropdownOption(
                          existingOption['id'],
                          existingOption['label'],
                          description: desc,
                        );
                      }
                      await _fetchOptions();
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                        );
                      }
                    } finally {
                      setState(() => _isLoading = false);
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
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
              leading: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () async {
                  if (_uploadingCropId != null) return;
                  try {
                    setState(() {
                      _uploadingCropId = crop['id'];
                    });
                    final uploadedUrl = await _pickAndUploadImage();
                    if (uploadedUrl != null) {
                      // Optimistically update the UI instantly
                      setState(() {
                        crop['image_url'] = uploadedUrl;
                      });

                      await SupabaseService.updateMasterCropImageUrl(
                        crop['id'],
                        uploadedUrl,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Crop image updated successfully!'),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      }
                      await _fetchOptions(showLoader: false);
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error updating crop image: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } finally {
                    if (mounted) {
                      setState(() {
                        _uploadingCropId = null;
                      });
                    }
                  }
                },
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.secondary.withOpacity(0.5),
                      backgroundImage: crop['image_url'] != null &&
                              crop['image_url'].toString().isNotEmpty &&
                              crop['image_url'].toString() != 'null'
                          ? NetworkImage(crop['image_url'].toString())
                          : null,
                      child: crop['image_url'] != null &&
                              crop['image_url'].toString().isNotEmpty &&
                              crop['image_url'].toString() != 'null'
                          ? null
                          : const Icon(
                              Icons.eco_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                    ),
                    if (_uploadingCropId == crop['id'])
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                           Icons.camera_alt_rounded,
                           color: Colors.white,
                           size: 10,
                        ),
                      ),
                    ),
                  ],
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: () => _addOrEditVariety(crop['id']),
                        icon: const Icon(Icons.add_circle_outline_rounded),
                        label: const Text('Add Variety'),
                      ),
                      const SizedBox(width: 24),
                      TextButton.icon(
                        onPressed: () => _showProblemMappingDialog(crop),
                        icon: const Icon(Icons.bug_report_outlined),
                        label: const Text('Map Problems'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                        ),
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
              leading: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () async {
                  if (_uploadingProductId != null) return;
                  try {
                    setState(() {
                      _uploadingProductId = product['id'];
                    });
                    final uploadedUrl = await _pickAndUploadImage();
                    if (uploadedUrl != null) {
                      // Optimistically update the UI instantly
                      setState(() {
                        product['image_url'] = uploadedUrl;
                      });

                      await SupabaseService.updateDropdownOption(
                        product['id'],
                        product['label'],
                        imageUrl: uploadedUrl,
                        taxPercentage: product['tax_percentage'] != null ? (product['tax_percentage'] as num).toDouble() : null,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Product image updated successfully!'),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      }
                      await _fetchOptions(showLoader: false);
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error updating product image: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } finally {
                    if (mounted) {
                      setState(() {
                        _uploadingProductId = null;
                      });
                    }
                  }
                },
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.secondary.withOpacity(0.5),
                      backgroundImage: product['image_url'] != null &&
                              product['image_url'].toString().isNotEmpty &&
                              product['image_url'].toString() != 'null'
                          ? NetworkImage(product['image_url'].toString())
                          : null,
                      child: product['image_url'] != null &&
                              product['image_url'].toString().isNotEmpty &&
                              product['image_url'].toString() != 'null'
                          ? null
                          : const Icon(
                              Icons.inventory_2_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                    ),
                    if (_uploadingProductId == product['id'])
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                           Icons.camera_alt_rounded,
                           color: Colors.white,
                           size: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              title: Text(
                product['label'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${variants.length} package sizes available'),
                  if (product['hsn_code'] != null && product['hsn_code'].toString().trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'HSN/SAC: ${product['hsn_code']}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textGray),
                      ),
                    ),
                  if (product['description'] != null && product['description'].toString().trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        product['description'],
                        style: const TextStyle(fontSize: 12, color: AppColors.textGray, fontStyle: FontStyle.italic),
                      ),
                    ),
                ],
              ),
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
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MRP: ₹${v['mrp'] ?? 0} | Offer: ₹${v['offer_price'] ?? 0}${v['tax_percentage'] != null ? ' | Tax: ${v['tax_percentage']}%' : ''}',
                        ),
                        if (v['hsn_code'] != null && v['hsn_code'].toString().trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'HSN/SAC: ${v['hsn_code']}',
                              style: const TextStyle(fontSize: 11, color: AppColors.textGray),
                            ),
                          ),
                        if (v['description'] != null && v['description'].toString().trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              v['description'],
                              style: const TextStyle(fontSize: 11, color: AppColors.textGray, fontStyle: FontStyle.italic),
                            ),
                          ),
                      ],
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
                      TextButton.icon(
                        onPressed: () => _showProductMappingDialog(product),
                        icon: const Icon(Icons.playlist_add_check_rounded, color: AppColors.primary),
                        label: const Text('Map Treatment Options'),
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
    final taxController = TextEditingController();
    final hsnController = TextEditingController();
    final descriptionController = TextEditingController();

    bool applyToSiblings = false;
    bool applyGlobally = false;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Add Package Size'),
              content: SingleChildScrollView(
                child: Column(
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
                    TextField(
                      controller: hsnController,
                      decoration: const InputDecoration(
                        labelText: 'HSN / SAC Code',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Product Description',
                      ),
                      maxLines: 2,
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
                    const SizedBox(height: 16),
                    TextField(
                      controller: taxController,
                      decoration: const InputDecoration(
                        labelText: 'Tax Percentage (%)',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      title: const Text(
                        'Apply to all packet sizes of this product',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      value: applyToSiblings,
                      onChanged: (val) {
                        setStateDialog(() {
                          applyToSiblings = val ?? false;
                          if (applyToSiblings && applyGlobally) {
                            applyGlobally = false;
                          }
                        });
                      },
                      activeColor: AppColors.primary,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    ),
                    CheckboxListTile(
                      title: const Text(
                        'Apply to all products (global)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      value: applyGlobally,
                      onChanged: (val) {
                        setStateDialog(() {
                          applyGlobally = val ?? false;
                          if (applyGlobally && applyToSiblings) {
                            applyToSiblings = false;
                          }
                        });
                      },
                      activeColor: AppColors.primary,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (controller.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Package size name is required')),
                      );
                      return;
                    }
                    final taxStr = taxController.text.trim();
                    if (taxStr.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Tax percentage is required')),
                      );
                      return;
                    }
                    final taxVal = double.tryParse(taxStr);
                    if (taxVal == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid tax percentage')),
                      );
                      return;
                    }
                    Navigator.pop(context, {
                      'success': true,
                      'applyToSiblings': applyToSiblings,
                      'applyGlobally': applyGlobally,
                    });
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && result['success'] == true && controller.text.trim().isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        await SupabaseService.addDropdownOption(
          'product_name',
          controller.text.trim(),
          parentId: productId,
          mrp: double.tryParse(mrpController.text),
          offerPrice: double.tryParse(offerController.text),
          taxPercentage: double.tryParse(taxController.text),
          hsnCode: hsnController.text.trim(),
          description: descriptionController.text.trim(),
        );

        final taxVal = double.tryParse(taxController.text);
        final hsnVal = hsnController.text.trim();
        final descVal = descriptionController.text.trim();
        if (result['applyGlobally'] == true) {
          await SupabaseService.updateAllVariantsTaxHsnAndDesc(
            taxPercentage: taxVal,
            hsnCode: hsnVal,
            description: descVal,
          );
        } else if (result['applyToSiblings'] == true) {
          await SupabaseService.updateVariantsTaxHsnAndDesc(
            productId,
            taxPercentage: taxVal,
            hsnCode: hsnVal,
            description: descVal,
          );
        }

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
    final taxController = TextEditingController(
      text: variant['tax_percentage']?.toString(),
    );
    final hsnController = TextEditingController(
      text: variant['hsn_code']?.toString() ?? '',
    );
    final descriptionController = TextEditingController(
      text: variant['description']?.toString() ?? '',
    );

    bool applyToSiblings = false;
    bool applyGlobally = false;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Edit Package Size'),
              content: SingleChildScrollView(
                child: Column(
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
                    TextField(
                      controller: hsnController,
                      decoration: const InputDecoration(
                        labelText: 'HSN / SAC Code',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Product Description',
                      ),
                      maxLines: 2,
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
                    const SizedBox(height: 16),
                    TextField(
                      controller: taxController,
                      decoration: const InputDecoration(
                        labelText: 'Tax Percentage (%)',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      title: const Text(
                        'Apply to all packet sizes of this product',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      value: applyToSiblings,
                      onChanged: (val) {
                        setStateDialog(() {
                          applyToSiblings = val ?? false;
                          if (applyToSiblings && applyGlobally) {
                            applyGlobally = false;
                          }
                        });
                      },
                      activeColor: AppColors.primary,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    ),
                    CheckboxListTile(
                      title: const Text(
                        'Apply to all products (global)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      value: applyGlobally,
                      onChanged: (val) {
                        setStateDialog(() {
                          applyGlobally = val ?? false;
                          if (applyGlobally && applyToSiblings) {
                            applyToSiblings = false;
                          }
                        });
                      },
                      activeColor: AppColors.primary,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (controller.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Package size name is required')),
                      );
                      return;
                    }
                    final taxStr = taxController.text.trim();
                    if (taxStr.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Tax percentage is required')),
                      );
                      return;
                    }
                    final taxVal = double.tryParse(taxStr);
                    if (taxVal == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid tax percentage')),
                      );
                      return;
                    }
                    Navigator.pop(context, {
                      'success': true,
                      'applyToSiblings': applyToSiblings,
                      'applyGlobally': applyGlobally,
                    });
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && result['success'] == true && controller.text.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        await SupabaseService.updateDropdownOption(
          variant['id'],
          controller.text.trim(),
          mrp: double.tryParse(mrpController.text),
          offerPrice: double.tryParse(offerController.text),
          taxPercentage: double.tryParse(taxController.text),
          hsnCode: hsnController.text.trim(),
          description: descriptionController.text.trim(),
        );

        final taxVal = double.tryParse(taxController.text);
        final hsnVal = hsnController.text.trim();
        final descVal = descriptionController.text.trim();
        if (result['applyGlobally'] == true) {
          await SupabaseService.updateAllVariantsTaxHsnAndDesc(
            taxPercentage: taxVal,
            hsnCode: hsnVal,
            description: descVal,
          );
        } else if (result['applyToSiblings'] == true) {
          await SupabaseService.updateVariantsTaxHsnAndDesc(
            productId,
            taxPercentage: taxVal,
            hsnCode: hsnVal,
            description: descVal,
          );
        }

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
              '  image_url text,\n'
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
              'on conflict do nothing;\n\n'
              '-- 4. Create product dropdown mappings table\n'
              'create table if not exists public.product_dropdown_mapping (\n'
              '  id bigint generated by default as identity primary key,\n'
              '  product_id bigint references public.dropdown_options(id) on delete cascade,\n'
              '  option_id bigint references public.dropdown_options(id) on delete cascade,\n'
              '  created_at timestamptz default now(),\n'
              '  unique(product_id, option_id)\n'
              ');\n\n'
              'alter table public.product_dropdown_mapping enable row level security;\n'
              'create policy "Allow public read access" on public.product_dropdown_mapping for select using (true);\n'
              'create policy "Allow authenticated full access" on public.product_dropdown_mapping for all using (auth.role() = \'authenticated\');',
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

  Future<void> _showProductMappingDialog(Map<String, dynamic> product) async {
    final productId = product['id'] as int;

    // Show a loading indicator in the main screen
    setState(() => _isLoading = true);
    
    List<Map<String, dynamic>> applicationOptions = [];
    List<Map<String, dynamic>> doseUnitOptions = [];
    List<Map<String, dynamic>> perUnitOptions = [];
    List<Map<String, dynamic>> fillerMaterialOptions = [];
    List<Map<String, dynamic>> existingMappings = [];

    try {
      applicationOptions = await SupabaseService.getDropdownOptions('application_method');
      doseUnitOptions = await SupabaseService.getDropdownOptions('dose_unit');
      perUnitOptions = await SupabaseService.getDropdownOptions('per_unit');
      fillerMaterialOptions = await SupabaseService.getDropdownOptions('filler_material');
      existingMappings = await SupabaseService.getProductDropdownMappings(productId);
    } catch (e) {
      debugPrint('Error loading mapping options: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    final List<int> selectedOptionIds = existingMappings
        .map((m) => m['option_id'] as int)
        .toList();

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) {
        return DefaultTabController(
          length: 4,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text(
                  'Map Options for ${product['label']}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                content: SizedBox(
                  width: 500,
                  height: 450,
                  child: Column(
                    children: [
                      const TabBar(
                        isScrollable: true,
                        labelColor: AppColors.primary,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: AppColors.primary,
                        tabs: [
                          Tab(text: 'Application'),
                          Tab(text: 'Dose Units'),
                          Tab(text: 'Per Units'),
                          Tab(text: 'Filler Materials'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: TabBarView(
                          children: [
                            // 1. Application Methods
                            _buildMappingCheckboxList(
                              options: applicationOptions,
                              selectedIds: selectedOptionIds,
                              onChanged: setDialogState,
                            ),
                            // 2. Dose Units
                            _buildMappingCheckboxList(
                              options: doseUnitOptions,
                              selectedIds: selectedOptionIds,
                              onChanged: setDialogState,
                            ),
                            // 3. Per Units
                            _buildMappingCheckboxList(
                              options: perUnitOptions,
                              selectedIds: selectedOptionIds,
                              onChanged: setDialogState,
                            ),
                            // 4. Filler Materials
                            _buildMappingCheckboxList(
                              options: fillerMaterialOptions,
                              selectedIds: selectedOptionIds,
                              onChanged: setDialogState,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context); // Close dialog
                      setState(() => _isLoading = true);
                      try {
                        await SupabaseService.updateProductDropdownMappings(
                          productId,
                          selectedOptionIds,
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Mappings saved successfully!'),
                              backgroundColor: AppColors.primary,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error saving mappings: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _isLoading = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    child: const Text('Save Mappings'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMappingCheckboxList({
    required List<Map<String, dynamic>> options,
    required List<int> selectedIds,
    required StateSetter onChanged,
  }) {
    if (options.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'No options available.\nAdd them in the main dropdown selector first.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: options.length,
      itemBuilder: (context, index) {
        final option = options[index];
        final id = option['id'] as int;
        final isSelected = selectedIds.contains(id);

        return CheckboxListTile(
          title: Text(option['label'] ?? '', style: const TextStyle(fontSize: 14)),
          value: isSelected,
          activeColor: AppColors.primary,
          onChanged: (bool? value) {
            onChanged(() {
              if (value == true) {
                selectedIds.add(id);
              } else {
                selectedIds.remove(id);
              }
            });
          },
        );
      },
    );
  }
}
