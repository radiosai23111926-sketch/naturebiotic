import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:nature_biotic/services/local_database_service.dart';
import 'package:nature_biotic/services/sync_manager.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';

class AddFarmerScreen extends StatefulWidget {
  final Map<String, dynamic>? farmer;
  const AddFarmerScreen({super.key, this.farmer});

  @override
  State<AddFarmerScreen> createState() => _AddFarmerScreenState();
}

class _AddFarmerScreenState extends State<AddFarmerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _villageController = TextEditingController();
  final _mobileController = TextEditingController();
  final _talukController = TextEditingController();
  final _districtController = TextEditingController();
  final _landmarkController = TextEditingController();
  String? _selectedCategory;
  List<String> _categories = ['Hot', 'Warm', 'Cold'];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    if (widget.farmer != null) {
      _nameController.text = widget.farmer!['name'] ?? '';
      _villageController.text = widget.farmer!['village'] ?? '';
      _mobileController.text = widget.farmer!['mobile'] ?? '';
      String addr = widget.farmer!['address'] ?? '';
      List<String> parts = addr.split('\n');
      if (parts.length >= 3) {
        _talukController.text = parts[0];
        _districtController.text = parts[1];
        _landmarkController.text = parts[2];
      } else {
        _talukController.text = addr;
      }
      _selectedCategory = widget.farmer!['category'];
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final options = await SupabaseService.getDropdownOptions(
        'farmer_category',
      );
      if (options.isNotEmpty) {
        setState(() {
          _categories = options.map((e) => e['label'].toString()).toList();
          // Safety check: if current selection is not in new list, reset it
          if (_selectedCategory != null &&
              !_categories.contains(_selectedCategory)) {
            _selectedCategory = _categories.first;
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching categories: $e');
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final currentUserId = SupabaseService.client.auth.currentUser?.id;

      final data = {
        'name': _nameController.text.trim(),
        'village': _villageController.text.trim(),
        'mobile': _mobileController.text.trim(),
        'address':
            '${_talukController.text.trim()}\n${_districtController.text.trim()}\n${_landmarkController.text.trim()}',
        'category': _selectedCategory,
        'created_at': DateTime.now().toIso8601String(),
        'created_by': currentUserId,
      };

      // NEW OFFLINE-FIRST LOGIC
      final String op = widget.farmer != null ? 'UPDATE' : 'INSERT';
      final Map<String, dynamic> offlineData = {
        ...data,
        if (widget.farmer != null) 'id': widget.farmer!['id'].toString(),
      };

      if (kIsWeb) {
        if (widget.farmer != null) {
          await SupabaseService.updateFarmer(
            widget.farmer!['id'].toString(),
            data,
          );
        } else {
          await SupabaseService.addFarmer(data);
        }
      } else {
        await LocalDatabaseService.saveAndQueue(
          tableName: 'farmers',
          data: offlineData,
          operation: op,
        );
        // Attempt to sync in background
        SyncManager().sync();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.farmer != null
                  ? 'Farmer Updated Successfully'
                  : 'Farmer Added Successfully',
            ),
            backgroundColor: AppColors.primary,
          ),
        );
        // Return the updated data map so the detail screen can update immediately
        Navigator.pop(context, offlineData);
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Error: $e';
        if (e.toString().contains('farmers_category_check')) {
          errorMessage =
              'Database Error: The selected category is not allowed by the database constraint. Please update the "farmers_category_check" constraint in Supabase.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadCsv() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        setState(() => _isLoading = true);

        final file = result.files.first;
        String input;

        if (file.bytes != null) {
          input = utf8.decode(file.bytes!);
        } else if (file.path != null) {
          input = await File(file.path!).readAsString();
        } else {
          throw 'File could not be read';
        }

        List<List<dynamic>> rows = const CsvToListConverter().convert(input);

        if (rows.isEmpty) throw 'CSV is empty';

        // Assume first row is header
        final headers =
            rows[0].map((e) => e.toString().toLowerCase().trim()).toList();
        final dataRows = rows.sublist(1);

        List<Map<String, dynamic>> farmers = [];
        for (var row in dataRows) {
          if (row.isEmpty) continue;

          Map<String, dynamic> farmer = {};
          for (int i = 0; i < headers.length; i++) {
            if (i < row.length) {
              String key = headers[i];
              String? dbKey;

              if (key.contains('name')) {
                dbKey = 'name';
              } else if (key.contains('mobile') || key.contains('phone'))
                dbKey = 'mobile';
              else if (key.contains('village'))
                dbKey = 'village';
              else if (key.contains('taluk'))
                dbKey = 'taluk';
              else if (key.contains('district'))
                dbKey = 'district';
              else if (key.contains('landmark'))
                dbKey = 'landmark';
              else if (key.contains('address'))
                dbKey = 'address';
              else if (key.contains('category'))
                dbKey = 'category';

              if (dbKey != null) {
                String val = row[i].toString().trim();
                if (dbKey == 'category') {
                  // DB requires exact case: Hot, Warm, or Cold
                  String normalized = val.toLowerCase();
                  if (normalized.contains('hot')) {
                    val = 'Hot';
                  } else if (normalized.contains('warm'))
                    val = 'Warm';
                  else if (normalized.contains('cold'))
                    val = 'Cold';
                  else
                    val = 'Warm'; // Fallback
                }
                farmer[dbKey] = val;
              }
            }
          }

          // Basic validation: name is required and mobile must be 10 digits
          final nameStr = farmer['name']?.toString() ?? '';
          final mobileStr = farmer['mobile']?.toString() ?? '';

          // Clean mobile number (keep only digits)
          final cleanMobile = mobileStr.replaceAll(RegExp(r'\D'), '');

          if (nameStr.isNotEmpty) {
            if (cleanMobile.isNotEmpty && cleanMobile.length != 10) {
              // Optionally skip or throw error. Let's throw for clarity in bulk upload.
              throw 'Invalid mobile number for "$nameStr": $mobileStr (Must be 10 digits)';
            }

            farmer['mobile'] = cleanMobile;

            // Reconstruct address if separate fields were provided
            if (farmer['taluk'] != null ||
                farmer['district'] != null ||
                farmer['landmark'] != null) {
              farmer['address'] =
                  '${farmer['taluk'] ?? ''}\n${farmer['district'] ?? ''}\n${farmer['landmark'] ?? ''}';
            }

            // Ensure all recognized keys exist in every map to maintain consistent schema
            for (var k in ['mobile', 'village', 'address', 'category']) {
              farmer[k] ??= (k == 'category' ? 'Warm' : null);
            }
            farmers.add(farmer);
          }
        }

        if (farmers.isEmpty) {
          throw 'No valid farmer records found. Ensure CSV has a "name" column.';
        }

        await SupabaseService.addFarmersBulk(farmers);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${farmers.length} Farmers Uploaded Successfully'),
              backgroundColor: AppColors.primary,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadTemplate() async {
    try {
      setState(() => _isLoading = true);

      const headers = [
        'name',
        'mobile',
        'village',
        'taluk',
        'district',
        'landmark',
        'category',
      ];
      const exampleRow = [
        'John Doe',
        '9876543210',
        'Greenfield',
        'Maddur',
        'Mandya',
        'Near Post Office',
        'Warm',
      ];

      String csvContent = const ListToCsvConverter().convert([
        headers,
        exampleRow,
      ]);
      final Uint8List bytes = Uint8List.fromList(utf8.encode(csvContent));

      if (kIsWeb) {
        await FilePicker.platform.saveFile(
          fileName: 'farmer_template.csv',
          bytes: bytes,
        );
      } else if (Platform.isAndroid || Platform.isIOS) {
        // For mobile, passing bytes to saveFile handles the write operation
        // safely via the system's storage APIs. Manual writing via File()
        // fails on Android due to virtual paths (URIs).
        await FilePicker.platform.saveFile(
          dialogTitle: 'Save CSV Template',
          fileName: 'farmer_template.csv',
          type: FileType.custom,
          allowedExtensions: ['csv'],
          bytes: bytes,
        );
      } else {
        // Desktop handling (Windows/macOS/Linux)
        final String? outputPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save CSV Template',
          fileName: 'farmer_template.csv',
          type: FileType.custom,
          allowedExtensions: ['csv'],
          bytes: bytes,
        );

        // On desktop, we still do a manual write to ensure compatibility
        // as some versions of the plugin on desktop only pick the path.
        if (outputPath != null) {
          final file = File(outputPath);
          await file.writeAsBytes(bytes);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Template Downloaded Successfully'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading template: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.farmer != null ? 'Edit Farmer' : 'Add Farmer'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _downloadTemplate,
            icon: const Icon(Icons.file_download),
            tooltip: 'Download CSV Template',
          ),
          IconButton(
            onPressed: _isLoading ? null : _pickAndUploadCsv,
            icon: const Icon(Icons.upload_file),
            tooltip: 'Bulk Upload CSV',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Farmer Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textBlack,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Full Name',
                            hintText: 'Enter farmer name',
                            fillColor: Colors.white,
                          ),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _mobileController,
                          decoration: const InputDecoration(
                            labelText: 'Mobile Number',
                            hintText: 'Enter 10 digit mobile number',
                            fillColor: Colors.white,
                          ),
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            if (v.length != 10) {
                              return 'Enter exactly 10 digits';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _villageController,
                          decoration: const InputDecoration(
                            labelText: 'Village',
                            hintText: 'Enter village name',
                            fillColor: Colors.white,
                          ),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Other Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textBlack,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _talukController,
                          decoration: const InputDecoration(
                            labelText: 'Taluk',
                            hintText: 'Enter taluk',
                            fillColor: Colors.white,
                          ),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _districtController,
                          decoration: const InputDecoration(
                            labelText: 'District',
                            hintText: 'Enter district',
                            fillColor: Colors.white,
                          ),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _landmarkController,
                          decoration: const InputDecoration(
                            labelText: 'Landmark',
                            hintText: 'Enter landmark (e.g. Near Bus Stand)',
                            fillColor: Colors.white,
                          ),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue:
                              (_selectedCategory != null &&
                                      _categories.contains(_selectedCategory))
                                  ? _selectedCategory
                                  : null,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            fillColor: Colors.white,
                          ),
                          items:
                              _categories.map((String category) {
                                return DropdownMenuItem(
                                  value: category,
                                  child: Text(category),
                                );
                              }).toList(),
                          onChanged: (String? value) {
                            setState(() {
                              _selectedCategory = value;
                            });
                          },
                          validator:
                              (v) =>
                                  (v == null || v.isEmpty)
                                      ? 'Selection required'
                                      : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSubmit,
                      child:
                          _isLoading
                              ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                              : Text(
                                widget.farmer != null
                                    ? 'Update Farmer Details'
                                    : 'Submit Farmer Details',
                              ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
