import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:nature_biotic/services/local_database_service.dart';
import 'package:nature_biotic/services/sync_manager.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';

class AddFarmScreen extends StatefulWidget {
  final Map<String, dynamic>? farm;
  final String? farmerId;
  const AddFarmScreen({super.key, this.farm, this.farmerId});

  @override
  State<AddFarmScreen> createState() => _AddFarmScreenState();
}

class _AddFarmScreenState extends State<AddFarmScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _placeController = TextEditingController();
  final _placeKeywordsController = TextEditingController();
  final _areaController = TextEditingController();
  final _landmarkController = TextEditingController();

  String? _soilType;
  String? _intercrop;
  String? _irrigationType;
  String? _waterSource;
  String? _waterQty;
  String? _powerSource;

  List<String> _soilTypes = ['Red', 'Black', 'Loomy', 'Aluvial'];
  List<String> _irrigationTypes = ['Flood', 'Drip irrigation'];
  List<String> _waterSources = [
    'Well',
    'Borewell',
    'canal/Pond',
    'River/Stream',
  ];
  List<String> _waterQtys = ['Ample', 'surplus', 'Scarcity'];
  List<String> _powerSources = ['EB', 'Diesel Pump', 'Solar'];
  List<String> _intercropOptions = ['Yes', 'No'];

  // Additional Contacts
  final List<Map<String, TextEditingController>> _contactControllers = [];

  bool _isLoading = false;
  bool _isLocationLoading = false;
  bool _isEdit = false;
  String? _userRole;
  bool _isResolvingAuto = false;

  PlatformFile? _selectedReport;
  String? _existingReportUrl;

  @override
  void initState() {
    super.initState();
    _fetchOptions();
    if (widget.farm != null) {
      _isEdit = true;
      _nameController.text = widget.farm!['name'] ?? '';
      
      String fullPlace = widget.farm!['place'] ?? '';
      if (fullPlace.contains(' | Keywords: ')) {
        final parts = fullPlace.split(' | Keywords: ');
        _placeController.text = parts[0];
        _placeKeywordsController.text = parts[1];
      } else {
        _placeController.text = fullPlace;
      }
      
      _areaController.text = (widget.farm!['area'] ?? '').toString();
      _soilType = widget.farm!['soil_type'];
      _irrigationType = widget.farm!['irrigation_type'];
      _waterSource = widget.farm!['water_source'];
      _waterQty = widget.farm!['water_quantity'];
      _powerSource = widget.farm!['power_source'];
      _landmarkController.text = widget.farm!['landmark'] ?? '';
      _intercrop = widget.farm!['intercrop'];
      _existingReportUrl = widget.farm!['report_url'];

      // Load existing contacts
      if (widget.farm!['contacts'] != null) {
        try {
          final dynamic contactsData = widget.farm!['contacts'];
          List<dynamic> contacts = [];
          if (contactsData is String) {
            contacts = jsonDecode(contactsData);
          } else if (contactsData is List) {
            contacts = contactsData;
          }

          for (var contact in contacts) {
            _contactControllers.add({
              'name': TextEditingController(
                text: contact['name']?.toString() ?? '',
              ),
              'phone': TextEditingController(
                text: contact['phone']?.toString() ?? '',
              ),
            });
          }
        } catch (e) {
          debugPrint('Error parsing contacts: $e');
        }
      }
    }
  }

  Future<void> _fetchOptions() async {
    try {
      final profile = await SupabaseService.getProfile();
      final results = await Future.wait([
        SupabaseService.getDropdownOptions('soil_type'),
        SupabaseService.getDropdownOptions('irrigation_type'),
        SupabaseService.getDropdownOptions('water_source'),
        SupabaseService.getDropdownOptions('water_quantity'),
        SupabaseService.getDropdownOptions('power_source'),
      ]);

      if (mounted) {
        setState(() {
          _userRole = profile?['role'];
          if (results[0].isNotEmpty) {
            _soilTypes = results[0].map((e) => e['label'].toString()).toList();
          }
          if (results[1].isNotEmpty) {
            _irrigationTypes =
                results[1].map((e) => e['label'].toString()).toList();
          }
          if (results[2].isNotEmpty) {
            _waterSources =
                results[2].map((e) => e['label'].toString()).toList();
          }
          if (results[3].isNotEmpty) {
            _waterQtys = results[3].map((e) => e['label'].toString()).toList();
          }
          if (results[4].isNotEmpty) {
            _powerSources =
                results[4].map((e) => e['label'].toString()).toList();
          }

          // Ensure selected values are in the lists, but only if they are not null
          if (_soilType != null && _soilTypes.isNotEmpty && !_soilTypes.contains(_soilType)) {
            _soilType = _soilTypes.first;
          }
          if (_intercrop != null && _intercropOptions.isNotEmpty && !_intercropOptions.contains(_intercrop)) {
            _intercrop = null;
          }
          if (_irrigationType != null &&
              _irrigationTypes.isNotEmpty &&
              !_irrigationTypes.contains(_irrigationType)) {
            _irrigationType = _irrigationTypes.first;
          }
          if (_waterSource != null && _waterSources.isNotEmpty && !_waterSources.contains(_waterSource)) {
            _waterSource = _waterSources.first;
          }
          if (_waterQty != null && _waterQtys.isNotEmpty && !_waterQtys.contains(_waterQty)) {
            _waterQty = _waterQtys.first;
          }
          if (_powerSource != null && _powerSources.isNotEmpty && !_powerSources.contains(_powerSource)) {
            _powerSource = _powerSources.first;
          }
        });
      }
    } catch (e) {
      debugPrint('Error in _fetchOptions: $e');
    }
  }

  Future<void> _resolveGoogleMapsLink() async {
    final TextEditingController linkController = TextEditingController();
    final link = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Text(
              'Resolve Farm Location',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Paste the Google Maps link shared by the farmer below:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: linkController,
                  decoration: InputDecoration(
                    hintText: 'https://maps.app.goo.gl/...',
                    labelText: 'Google Maps Link',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  autofocus: true,
                  onSubmitted: (val) {
                    Navigator.pop(context, val.trim());
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Note: This will extract the coordinates and address from the link.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textGray.withOpacity(0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.textGray),
                ),
              ),
              ElevatedButton(
                onPressed:
                    () => Navigator.pop(context, linkController.text.trim()),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Resolve'),
              ),
            ],
          ),
    );

    if (link != null && link.isNotEmpty) {
      _performLocationResolution(link);
    }
  }

  Future<void> _performLocationResolution(String link) async {
    if (link.isEmpty) return;

    setState(() => _isLocationLoading = true);
    try {
      String finalUrl = link;

      // If it's a short link, we need to follow the redirect to get coordinates from final URL
      if (link.contains('maps.app.goo.gl') || link.contains('goo.gl/maps')) {
        try {
          final response = await http.get(
            Uri.parse(link),
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
            },
          );
          if (response.request != null) {
            finalUrl = response.request!.url.toString();
          }
        } catch (e) {
          debugPrint('Error following redirect: $e');
        }
      }

      // More robust regex to find coordinates in various Google Maps URL formats
      final decodedUrl = Uri.decodeComponent(finalUrl);

      RegExp coordRegex = RegExp(r'(@|q=|ll=)(-?\d+\.\d+),\s*(-?\d+\.\d+)');
      var match = coordRegex.firstMatch(decodedUrl);

      double? lat;
      double? lng;

      if (match != null) {
        lat = double.tryParse(match.group(2)!);
        lng = double.tryParse(match.group(3)!);
      } else {
        final internalRegex = RegExp(r'!3d(-?\d+\.\d+)!4d(-?\d+\.\d+)');
        final internalMatch = internalRegex.firstMatch(decodedUrl);
        if (internalMatch != null) {
          lat = double.tryParse(internalMatch.group(1)!);
          lng = double.tryParse(internalMatch.group(2)!);
        }
      }

      final nameRegex = RegExp(r'/maps/place/([^/]+)/@');
      final nameMatch = nameRegex.firstMatch(decodedUrl);

      if (nameMatch != null && _nameController.text.isEmpty) {
        String extractedName = nameMatch.group(1)!.replaceAll('+', ' ');
        setState(() {
          _nameController.text = extractedName;
        });
      }

      if (lat != null && lng != null) {
        String address = "";
        try {
          if (kIsWeb) {
            address = await _getAddressFromCoordinatesWeb(lat, lng);
          } else {
            List<Placemark> placemarks = await placemarkFromCoordinates(
              lat,
              lng,
            );
            if (placemarks.isNotEmpty) {
              Placemark place = placemarks[0];
              List<String> parts = [
                if (place.name != null && place.name != place.subLocality)
                  place.name!,
                if (place.subLocality != null) place.subLocality!,
                if (place.locality != null) place.locality!,
                if (place.subAdministrativeArea != null)
                  place.subAdministrativeArea!,
                if (place.administrativeArea != null) place.administrativeArea!,
                if (place.postalCode != null) place.postalCode!,
              ];
              address = parts.where((p) => p.isNotEmpty).join(', ');
            } else {
              address = "$lat, $lng";
            }
          }
        } catch (e) {
          debugPrint('Geocoding error: $e');
          address = "$lat, $lng"; // Fallback to coordinates if lookup fails
        }

        if (mounted) {
          setState(() {
            _placeController.text = address;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Farm details resolved successfully!'),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      } else {
        String errorMsg = 'Could not extract coordinates.';
        if (kIsWeb &&
            (link.contains('maps.app.goo.gl') || link.contains('goo.gl'))) {
          errorMsg =
              'Short link resolution blocked by browser security. Please paste the full URL from your browser bar instead.';
        }
        throw errorMsg;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocationLoading = false);
    }
  }

  Future<String> _getAddressFromCoordinatesWeb(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng',
      );
      // Nominatim requires a user-agent
      final response = await http.get(
        url,
        headers: {'User-Agent': 'NatureBioticApp/1.0'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['display_name'] ?? "$lat, $lng";
      }
    } catch (_) {}
    return "$lat, $lng";
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() => _isLocationLoading = true);
    try {
      bool serviceEnabled;
      LocationPermission permission;

      // Test if location services are enabled.
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Location services are disabled.';
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions are denied';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Location permissions are permanently denied';
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // Web does not support reverse geocoding with this plugin
      if (kIsWeb) {
        final address = await _getAddressFromCoordinatesWeb(
          position.latitude,
          position.longitude,
        );
        setState(() {
          _placeController.text = address;
        });
        return;
      }

      // Reverse geocoding (Mobile only)
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          String address =
              "${place.name ?? ''}, ${place.subLocality ?? ''}, ${place.locality ?? ''}, ${place.postalCode ?? ''}";
          // Clean up address (remove double commas/spaces)
          address = address.replaceAll(RegExp(r',\s*,'), ',').trim();
          if (address.startsWith(',')) address = address.substring(1).trim();

          setState(() {
            _placeController.text = address;
          });
        } else {
          setState(() {
            _placeController.text =
                "${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}";
          });
        }
      } catch (_) {
        // If geocoding fails, fallback to coordinates
        setState(() {
          _placeController.text =
              "${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}";
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.orange),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocationLoading = false);
    }
  }

  Future<void> _pickReport() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.size > 5 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('File size must be less than 5MB'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
        setState(() {
          _selectedReport = file;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _addContactRow() {
    setState(() {
      _contactControllers.add({
        'name': TextEditingController(),
        'phone': TextEditingController(),
      });
    });
  }

  void _removeContactRow(int index) {
    setState(() {
      _contactControllers[index]['name']?.dispose();
      _contactControllers[index]['phone']?.dispose();
      _contactControllers.removeAt(index);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _placeController.dispose();
    _areaController.dispose();
    for (var controllers in _contactControllers) {
      controllers['name']?.dispose();
      controllers['phone']?.dispose();
    }
    _placeKeywordsController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      String? reportUrl = _existingReportUrl;

      if (_selectedReport != null && _selectedReport!.bytes != null) {
        final fileName =
            'report_${DateTime.now().millisecondsSinceEpoch}.${_selectedReport!.extension}';
        reportUrl = await SupabaseService.uploadImage(
          _selectedReport!.bytes!,
          fileName,
          'farm_reports',
        );
      }

      final userProfile = await SupabaseService.getProfile();
      final currentUserId = SupabaseService.client.auth.currentUser?.id;

      final farmData = {
        'name': _nameController.text.trim(),
        'place': _placeKeywordsController.text.isEmpty 
            ? _placeController.text.trim()
            : '${_placeController.text.trim()} | Keywords: ${_placeKeywordsController.text.trim()}',
        'area': double.tryParse(_areaController.text) ?? 0.0,
        'soil_type': _soilType,
        'irrigation_type': _irrigationType,
        'water_source': _waterSource,
        'water_quantity': _waterQty,
        'power_source': _powerSource,
        'landmark': _landmarkController.text.trim(),
        'intercrop': _intercrop,
        'farmer_id': widget.farmerId ?? widget.farm?['farmer_id'],
        'report_url': reportUrl,
        'created_at': DateTime.now().toIso8601String(),
        'created_by': currentUserId,
      };

      // Collect additional contacts
      final List<Map<String, String>> contacts =
          _contactControllers
              .where(
                (c) =>
                    c['name']!.text.isNotEmpty || c['phone']!.text.isNotEmpty,
              )
              .map(
                (c) => {
                  'name': c['name']!.text.trim(),
                  'phone': c['phone']!.text.trim(),
                },
              )
              .toList();

      if (contacts.isNotEmpty) {
        farmData['contacts'] = contacts;
      }

      // Auto-assign if created by an executive/telecaller (and not just an edit)
      if (!_isEdit &&
          (userProfile?['role'] == 'executive' || userProfile?['role'] == 'telecaller') &&
          currentUserId != null) {
        farmData['assigned_to'] = currentUserId;
      } else if (_isEdit) {
        // Keep existing assignment if editing
        farmData['assigned_to'] = widget.farm?['assigned_to'];
      }

      // NEW OFFLINE-FIRST LOGIC
      final String op = _isEdit ? 'UPDATE' : 'INSERT';
      final Map<String, dynamic> offlineData = {
        ...farmData,
        if (_isEdit) 'id': widget.farm!['id'].toString(),
      };

      if (kIsWeb) {
        if (_isEdit) {
          await SupabaseService.updateFarm(widget.farm!['id'], farmData);
        } else {
          await SupabaseService.addFarm(farmData);
        }
      } else {
        await LocalDatabaseService.saveAndQueue(
          tableName: 'farms',
          data: offlineData,
          operation: op,
        );
        // Attempt to sync
        SyncManager().sync();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEdit
                  ? 'Farm Updated Successfully'
                  : 'Farm Registered Successfully',
            ),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.pop(context, true);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(_isEdit ? 'Edit Farm' : 'Add Farm')),
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
                    'Farm Details',
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
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Farm Name',
                            hintText: 'e.g. Green Valley Farm',
                            fillColor: Colors.white,
                          ),
                          validator:
                              (v) =>
                                  (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _placeController,
                          onChanged: (v) {
                            if (_isResolvingAuto) return;
                            // Strictly allow link resolution ONLY for non-executives/non-telecallers
                            // Wait, telecallers ARE office-based, so they SHOULD have link resolution.
                            // The logic currently excludes executives. I will exclude executives only.
                            if (_userRole != 'executive' &&
                                v.startsWith('http') &&
                                (v.contains('maps.app.goo.gl') ||
                                    v.contains('google.com/maps') ||
                                    v.contains('goo.gl'))) {
                              setState(() {
                                _isResolvingAuto = true;
                                _placeController.text = 'Resolving location...';
                              });
                              _performLocationResolution(v.trim()).then((_) {
                                setState(() => _isResolvingAuto = false);
                              });
                            }
                          },
                          decoration: InputDecoration(
                            labelText: 'Farm Location',
                            hintText: 'Enter farm location',
                            fillColor: Colors.white,
                            suffixIcon: IconButton(
                              icon:
                                  _isLocationLoading
                                      ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : Icon(
                                        (_userRole == 'telecaller' ||
                                                _userRole == 'admin' ||
                                                _userRole == 'manager')
                                            ? Icons.link_rounded
                                            : Icons.my_location_rounded,
                                        color: AppColors.primary,
                                      ),
                              onPressed:
                                  _isLocationLoading
                                      ? null
                                      : ((_userRole == 'telecaller' ||
                                              _userRole == 'admin' ||
                                              _userRole == 'manager')
                                          ? _resolveGoogleMapsLink
                                          : _fetchCurrentLocation),
                              tooltip:
                                  (_userRole == 'telecaller' ||
                                          _userRole == 'admin' ||
                                          _userRole == 'manager')
                                      ? 'Resolve from Google Maps Link'
                                      : 'Get Current Location',
                            ),
                          ),
                          validator:
                              (v) =>
                                  (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _placeKeywordsController,
                          decoration: const InputDecoration(
                            labelText: 'Place / Village / District',
                            hintText: 'Type your own keywords or village name',
                            fillColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _landmarkController,
                          decoration: const InputDecoration(
                            labelText: 'Landmark',
                            hintText: 'Enter nearby landmark',
                            fillColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _areaController,
                          decoration: const InputDecoration(
                            labelText: 'Total Area (Acres)',
                            hintText: 'Enter area in acres',
                            fillColor: Colors.white,
                          ),
                          keyboardType: TextInputType.number,
                          validator:
                              (v) =>
                                  (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        _buildDropdown(
                          'Soil Type',
                          _soilTypes,
                          _soilType,
                          (v) => setState(() => _soilType = v ?? _soilType),
                        ),
                        const SizedBox(height: 16),
                        _buildDropdown(
                          'Intercrop',
                          _intercropOptions,
                          _intercrop,
                          (v) => setState(() => _intercrop = v ?? _intercrop),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Infrastructure & Resources',
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
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        _buildDropdown(
                          'Irrigation Type',
                          _irrigationTypes,
                          _irrigationType,
                          (v) => setState(
                            () => _irrigationType = v ?? _irrigationType,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildDropdown(
                          'Water Source',
                          _waterSources,
                          _waterSource,
                          (v) =>
                              setState(() => _waterSource = v ?? _waterSource),
                        ),
                        const SizedBox(height: 16),
                        _buildDropdown(
                          'Water Quantity',
                          _waterQtys,
                          _waterQty,
                          (v) => setState(() => _waterQty = v ?? _waterQty),
                        ),
                        const SizedBox(height: 16),
                        _buildDropdown(
                          'Power Source',
                          _powerSources,
                          _powerSource,
                          (v) =>
                              setState(() => _powerSource = v ?? _powerSource),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Additional Contacts',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textBlack,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _addContactRow,
                        icon: const Icon(
                          Icons.add_circle_outline_rounded,
                          size: 20,
                        ),
                        label: const Text('Add Contact'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_contactControllers.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No additional contacts added. (Optional)',
                        style: TextStyle(
                          color: AppColors.textGray.withOpacity(0.6),
                          fontStyle: FontStyle.italic,
                          fontSize: 13,
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _contactControllers.length,
                      separatorBuilder:
                          (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.1),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller:
                                          _contactControllers[index]['name'],
                                      decoration: const InputDecoration(
                                        labelText: 'Contact Person Name',
                                        hintText: 'e.g. Farm Manager',
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: () => _removeContactRow(index),
                                    icon: const Icon(
                                      Icons.remove_circle_outline_rounded,
                                      color: Colors.red,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _contactControllers[index]['phone'],
                                decoration: const InputDecoration(
                                  labelText: 'Contact Number',
                                  hintText: 'Enter 10 digit number',
                                  isDense: true,
                                ),
                                keyboardType: TextInputType.phone,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(10),
                                ],
                                validator: (v) {
                                  if (v != null &&
                                      v.isNotEmpty &&
                                      v.length != 10) {
                                    return 'Must be 10 digits';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 24),
                  const Text(
                    'Soil & Water Reports',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textBlack,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.2),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _selectedReport != null
                              ? Icons.description_rounded
                              : Icons.cloud_upload_outlined,
                          size: 48,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _selectedReport != null
                              ? _selectedReport!.name
                              : 'Upload PDF or Image',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_selectedReport == null &&
                            _existingReportUrl != null) ...[
                          const SizedBox(height: 4),
                          const Text(
                            'Existing report will be kept',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        const Text(
                          'Max size 5MB',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textGray,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: _pickReport,
                              style: TextButton.styleFrom(
                                backgroundColor: AppColors.primary.withOpacity(
                                  0.1,
                                ),
                                foregroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                _selectedReport != null
                                    ? 'Change File'
                                    : 'Browse Files',
                              ),
                            ),
                            if (_selectedReport != null) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed:
                                    () =>
                                        setState(() => _selectedReport = null),
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.red,
                                ),
                                tooltip: 'Remove selected file',
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
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
                                _isEdit
                                    ? 'Update Farm Details'
                                    : 'Save Farm Details',
                              ),
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    List<String> items,
    String? value,
    Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: (value != null && (items ?? []).contains(value)) ? value : null,
      decoration: InputDecoration(labelText: label, fillColor: Colors.white),
      items:
          (items ?? []).map((String item) {
            return DropdownMenuItem(value: item, child: Text(item));
          }).toList(),
      onChanged: onChanged,
      validator: (v) => (v == null || v.isEmpty) ? 'Selection required' : null,
    );
  }
}
