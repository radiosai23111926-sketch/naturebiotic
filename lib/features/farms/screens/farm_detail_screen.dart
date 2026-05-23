import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:intl/intl.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:nature_biotic/features/crops/screens/add_crop_screen.dart';
import 'package:nature_biotic/features/crops/screens/crop_detail_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nature_biotic/services/local_database_service.dart';
import 'package:nature_biotic/features/farms/screens/stock_management_screen.dart';
import 'package:nature_biotic/features/farms/screens/collection_history_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:nature_biotic/core/call_tracker.dart';
import 'dart:convert';
import 'package:nature_biotic/features/profile/screens/edit_request_dialog.dart';

class FarmDetailScreen extends StatefulWidget {
  final Map<String, dynamic> farm;

  const FarmDetailScreen({super.key, required this.farm});

  @override
  State<FarmDetailScreen> createState() => _FarmDetailScreenState();
}

class _FarmDetailScreenState extends State<FarmDetailScreen> with WidgetsBindingObserver {
  late Map<String, dynamic> _farm;
  List<Map<String, dynamic>> _crops = [];
  List<Map<String, dynamic>> _masterCrops = [];
  Map<String, dynamic>? _farmer;
  bool _isAdmin = false;
  bool _isManager = false;
  bool _isLoading = true;

  // Tracking
  DateTime? _callStartTime;
  String? _dialedNumber;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _farm = widget.farm;
    _checkAdminStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _callStartTime != null && _dialedNumber != null) {
      final startTime = _callStartTime!;
      final dialedNumber = _dialedNumber!;
      
      _callStartTime = null;
      _dialedNumber = null;

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          CallTracker.processCallResult(
            context, 
            dialedNumber, 
            startTime, 
            farmerId: _farm['farmer_id'].toString()
          );
        }
      });
    }
  }

  void _initiateCall() {
    final number = _farmer?['mobile']?.toString();
    if (number == null || number.isEmpty) return;

    _callStartTime = DateTime.now();
    _dialedNumber = number;
    CallTracker.makeCall(context, number, farmerId: _farm['farmer_id'].toString());
  }

  void _callAdditionalContact(String name, String number) {
    if (number.isEmpty) return;
    _callStartTime = DateTime.now();
    _dialedNumber = number;
    CallTracker.makeCall(context, number, farmerId: _farm['farmer_id'].toString());
  }

  List<Map<String, dynamic>> _getContacts() {
    final dynamic contactsData = _farm['contacts'];
    if (contactsData == null) return [];
    
    try {
      if (contactsData is String) {
        return List<Map<String, dynamic>>.from(jsonDecode(contactsData));
      } else if (contactsData is List) {
        return List<Map<String, dynamic>>.from(contactsData);
      }
    } catch (e) {
      debugPrint('Error parsing contacts in detail screen: $e');
    }
    return [];
  }

  Future<void> _checkAdminStatus() async {
    final profile = await SupabaseService.getProfile();
    if (mounted) {
      setState(() {
        _isAdmin = profile?['role'] == 'admin';
        _isManager = profile?['role'] == 'manager';
        _isLoading = false;
      });
      _loadAssignedExecutive();
      _loadCrops();
      _loadFarmer();
    }
  }

  bool _isCropNameMatch(String name1, String name2) {
    final n1 = name1.trim().toLowerCase();
    final n2 = name2.trim().toLowerCase();
    if (n1 == n2) return true;
    
    // Handle Tomato / Tomoto
    if ((n1.contains('tomato') || n1.contains('tomoto')) &&
        (n2.contains('tomato') || n2.contains('tomoto'))) {
      return true;
    }
    
    // Handle Chilli / Chili
    if ((n1.contains('chilli') || n1.contains('chili')) &&
        (n2.contains('chilli') || n2.contains('chili'))) {
      return true;
    }
    
    // Handle Guava / Gauva
    if ((n1.contains('guava') || n1.contains('gauva')) &&
        (n2.contains('guava') || n2.contains('gauva'))) {
      return true;
    }

    if (n1.contains(n2) || n2.contains(n1)) {
      return true;
    }

    return false;
  }

  String _getCropEmoji(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('tomato') || lower.contains('tomoto')) return '🍅';
    if (lower.contains('paddy') || lower.contains('rice')) return '🌾';
    if (lower.contains('onion')) return '🧅';
    if (lower.contains('mango')) return '🥭';
    if (lower.contains('maize') || lower.contains('corn')) return '🌽';
    if (lower.contains('lemon')) return '🍋';
    if (lower.contains('jasmine') || lower.contains('flower')) return '🌸';
    if (lower.contains('gauva') || lower.contains('guava')) return '🍈';
    if (lower.contains('coconut')) return '🥥';
    if (lower.contains('chilli') || lower.contains('pepper')) return '🌶️';
    if (lower.contains('cardamom') || lower.contains('spice')) return '🌿';
    if (lower.contains('brinjal') || lower.contains('eggplant')) return '🍆';
    if (lower.contains('banana')) return '🍌';
    if (lower.contains('grape')) return '🍇';
    if (lower.contains('apple')) return '🍎';
    if (lower.contains('orange')) return '🍊';
    if (lower.contains('chili')) return '🌶️';
    return '🌱';
  }

  Color _getCropColor(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('tomato') || lower.contains('tomoto')) return const Color(0xFFFFEBEE);
    if (lower.contains('paddy') || lower.contains('rice')) return const Color(0xFFFFF8E1);
    if (lower.contains('onion')) return const Color(0xFFF3E5F5);
    if (lower.contains('mango')) return const Color(0xFFFFF3E0);
    if (lower.contains('maize') || lower.contains('corn')) return const Color(0xFFFFFDE7);
    if (lower.contains('lemon')) return const Color(0xFFFFFDE7);
    if (lower.contains('jasmine') || lower.contains('flower')) return const Color(0xFFFCE4EC);
    if (lower.contains('gauva') || lower.contains('guava')) return const Color(0xFFE8F5E9);
    if (lower.contains('coconut')) return const Color(0xFFEFEBE9);
    if (lower.contains('chilli') || lower.contains('pepper')) return const Color(0xFFFFEBEE);
    if (lower.contains('cardamom') || lower.contains('spice')) return const Color(0xFFE8F5E9);
    if (lower.contains('brinjal') || lower.contains('eggplant')) return const Color(0xFFF3E5F5);
    return const Color(0xFFE8F5E9);
  }

  Future<void> _loadFarmer() async {
    if (_farm['farmer_id'] != null) {
      try {
        final response = await SupabaseService.client
            .from('farmers')
            .select()
            .eq('id', _farm['farmer_id'])
            .maybeSingle();
        if (mounted) {
          setState(() {
            _farmer = response;
          });
        }
      } catch (e) {
        debugPrint('Error loading farmer: $e');
      }
    }
  }

  Future<void> _loadCrops() async {
    try {
      final remoteCrops = await SupabaseService.getCrops(_farm['id']);
      List<Map<String, dynamic>> localCrops = [];
      List<Map<String, dynamic>> masterCrops = [];
      
      try {
        masterCrops = await SupabaseService.getMasterCrops();
      } catch (e) {
        debugPrint('Error loading master crops in farm details: $e');
      }

      if (!kIsWeb) {
        localCrops = await LocalDatabaseService.getData(
          'crops', 
          where: 'farm_id = ?', 
          whereArgs: [_farm['id'].toString()]
        );
      }

      if (mounted) {
        setState(() {
          // Merge and De-duplicate
          final Map<String, Map<String, dynamic>> combinedMap = {};
          
          for (var crop in remoteCrops) {
            combinedMap[crop['id'].toString()] = crop;
          }
          for (var crop in localCrops) {
            combinedMap[crop['id'].toString()] = crop;
          }

          _crops = combinedMap.values.toList();
          _crops.sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));
          _masterCrops = masterCrops;
        });
      }
    } catch (e) {
      debugPrint('Error loading crops: $e');
    }
  }

  Future<void> _loadAssignedExecutive() async {
    if (_farm['assigned_to'] != null && _farm['assigned_executive'] == null) {
      final executive = await SupabaseService.getProfileById(_farm['assigned_to']);
      if (mounted) {
        setState(() {
          _farm['assigned_executive'] = executive;
        });
      }
    }
  }

  Future<void> _showAssignDialog() async {
    showDialog(
      context: context,
      builder: (context) => _AssignExecutiveDialog(
        currentAssignedId: _farm['assigned_to'],
        onAssign: (executive) async {
          await SupabaseService.assignFarm(_farm['id'], executive?['id']);
          // Refresh local state
          setState(() {
            _farm['assigned_to'] = executive?['id'];
            _farm['assigned_executive'] = executive;
          });
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final assignedExecutive = _farm['assigned_executive'];
    final executiveName = assignedExecutive?['full_name'] ?? 'Not Assigned';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Farm Details',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Summary Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, Color(0xFF2E7D32)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(Icons.agriculture_rounded, size: 36, color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _farm['name'] ?? 'Farm Record',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 22,
                                      letterSpacing: -0.5,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (_farm['is_verified'] == true) 
                                  const Icon(
                                    Icons.verified_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                              ],
                            ),
                            if (_farm['is_verified'] == true) ...[
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: _buildRiseTokenButton(),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Text(
                              'Registered: ${_formatDate(_farm['created_at'])}',
                              style: GoogleFonts.outfit(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                if (_isManager && _farm['is_verified'] != true) ...[
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () async {
                            setState(() => _isLoading = true);
                            try {
                              await SupabaseService.verifyItem(
                                'farms',
                                _farm['id'],
                              );
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Farm Verified Successfully'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                setState(() {
                                  _farm['is_verified'] = true;
                                  _isLoading = false;
                                });
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Verification failed: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                setState(() => _isLoading = false);
                              }
                            }
                          },
                    icon: const Icon(Icons.verified_rounded),
                    label: const Text('Verify Farm Entry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 64),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 8,
                      shadowColor: AppColors.primary.withOpacity(0.3),
                    ),
                  ),
                ],
                
                if (_isAdmin) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                      border: Border.all(color: Colors.black.withOpacity(0.02)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.admin_panel_settings_rounded, color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Assigned Executive', 
                                style: GoogleFonts.outfit(
                                  color: AppColors.textGray.withOpacity(0.6), 
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                )
                              ),
                              Text(
                                executiveName, 
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w700, 
                                  fontSize: 15,
                                  color: AppColors.textBlack,
                                )
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: _showAssignDialog,
                          style: TextButton.styleFrom(
                            backgroundColor: AppColors.primary.withOpacity(0.05),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(
                            'Change', 
                            style: GoogleFonts.outfit(
                              fontSize: 12, 
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            )
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
    
                if (_farmer != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                      border: Border.all(color: Colors.black.withOpacity(0.02)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.person_rounded, color: Colors.blue, size: 20),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Farm Owner (Farmer)', 
                                style: GoogleFonts.outfit(
                                  color: AppColors.textGray.withOpacity(0.6), 
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                )
                              ),
                              Row(
                                children: [
                                  Text(
                                    _farmer?['name'] ?? 'N/A', 
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w700, 
                                      fontSize: 15,
                                      color: AppColors.textBlack,
                                    )
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.verified_rounded, size: 14, color: Colors.blue),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (_farmer?['mobile'] != null)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: IconButton(
                              onPressed: _initiateCall,
                              icon: const Icon(Icons.call_rounded, color: Colors.white, size: 18),
                              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
    
                const SizedBox(height: 32),
                Text(
                  'Farm Information', 
                  style: GoogleFonts.outfit(
                    fontSize: 20, 
                    fontWeight: FontWeight.w800, 
                    color: AppColors.textBlack,
                    letterSpacing: -0.5,
                  )
                ),
                const SizedBox(height: 16),
                
                // Grid of Info Cards
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 600;
                    return GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: isWide ? 3 : 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: isWide ? 2.5 : 1.8,
                      children: [
                        _infoCard(Icons.location_on_rounded, 'Place', _farm['place'] ?? 'N/A'),
                        _infoCard(Icons.straighten_rounded, 'Area', '${_farm['area'] ?? '0'} Acres'),
                        _infoCard(Icons.grain_rounded, 'Soil', _farm['soil_type'] ?? 'N/A'),
                        _infoCard(Icons.water_rounded, 'Irrigation', _farm['irrigation_type'] ?? 'N/A'),
                        _infoCard(Icons.waves_rounded, 'Source', _farm['water_source'] ?? 'N/A'),
                        _infoCard(Icons.inventory_2_rounded, 'Qty', _farm['water_quantity'] ?? 'N/A'),
                        _infoCard(Icons.bolt_rounded, 'Power', _farm['power_source'] ?? 'N/A'),
                        _infoCard(
                          Icons.layers_rounded, 
                          'Strategy', 
                          (_farm['intercrop']?.toString() == 'Yes' 
                              ? 'Intercrop' 
                              : _farm['intercrop']?.toString() == 'No' 
                                  ? 'Normal' 
                                  : (_farm['intercrop'] ?? 'Normal'))
                        ),
                        if (_farm['report_url'] != null && _farm['report_url'].toString().isNotEmpty)
                          GestureDetector(
                            onTap: () async {
                              final uri = Uri.parse(_farm['report_url']);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            },
                            child: _infoCard(
                              Icons.assignment_rounded, 
                              'Report', 
                              'View Report',
                              isLink: true,
                            ),
                          ),
                      ],
                    );
                  }
                ),
                
                const SizedBox(height: 24),
                
                if (_getContacts().isNotEmpty) ...[
                  const SizedBox(height: 32),
                  Text(
                    'Additional Contacts', 
                    style: GoogleFonts.outfit(
                      fontSize: 18, 
                      fontWeight: FontWeight.w800, 
                      color: AppColors.textBlack,
                    )
                  ),
                  const SizedBox(height: 16),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _getContacts().length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final contact = _getContacts()[index];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                          border: Border.all(color: Colors.black.withOpacity(0.02)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.contact_phone_rounded, color: AppColors.primary, size: 20),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    contact['name'] ?? 'Additional Contact', 
                                    style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14)
                                  ),
                                  Text(
                                    contact['phone'] ?? 'No number', 
                                    style: GoogleFonts.outfit(color: AppColors.textGray.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.w500)
                                  ),
                                ],
                              ),
                            ),
                            if (contact['phone'] != null && contact['phone'].toString().isNotEmpty)
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: IconButton(
                                  onPressed: () => _callAdditionalContact(contact['name'] ?? 'Contact', contact['phone'].toString()),
                                  icon: const Icon(Icons.call_rounded, color: Colors.white, size: 18),
                                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],

                const SizedBox(height: 32),
                Text(
                  'Crops in this Farm', 
                  style: GoogleFonts.outfit(
                    fontSize: 20, 
                    fontWeight: FontWeight.w800, 
                    color: AppColors.textBlack,
                    letterSpacing: -0.5,
                  )
                ),
                const SizedBox(height: 16),
                if (_crops.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.black.withOpacity(0.02)),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.eco_rounded, size: 48, color: AppColors.primary.withOpacity(0.1)),
                        const SizedBox(height: 12),
                        Text(
                          'No crops added yet', 
                          style: GoogleFonts.outfit(
                            color: AppColors.textGray, 
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          )
                        ),
                      ],
                    ),
                  )
                else
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _crops.length,
                      itemBuilder: (context, index) {
                        final crop = _crops[index];
                        return _cropCard(crop);
                      },
                    ),
                  ),
                
                if (!_isManager) ...[
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddCropScreen(farmId: _farm['id']),
                        ),
                      );
                      if (result == true) {
                        _loadCrops();
                      }
                    },
                    icon: const Icon(Icons.add_task_rounded),
                    label: const Text('Add New Crop'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
                      minimumSize: const Size(double.infinity, 64),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cropCard(Map<String, dynamic> crop) {
    final cropName = crop['name'] ?? 'Unknown';
    // Robust defensive check for _masterCrops to avoid null/undefined crashes during hot-reload or load state
    final matchingCrop = (_masterCrops == null || _masterCrops.isEmpty)
        ? <String, dynamic>{}
        : _masterCrops.firstWhere(
            (c) {
              final mName = c['name']?.toString().trim();
              if (mName == null) return false;
              return _isCropNameMatch(mName, cropName);
            },
            orElse: () => <String, dynamic>{},
          );
    String? imageUrl;
    if (matchingCrop.isNotEmpty) {
      imageUrl = matchingCrop['image_url'] as String?;
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CropDetailScreen(
              crop: crop,
              farmName: _farm['name'],
              farmerName: _farmer?['name'],
            ),
          ),
        );
      },
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 16, bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(color: Colors.black.withOpacity(0.02)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: imageUrl != null && imageUrl.isNotEmpty && imageUrl != 'null'
                        ? Colors.white
                        : _getCropColor(cropName),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 3,
                        offset: const Offset(0, 1.5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: imageUrl != null && imageUrl.isNotEmpty && imageUrl != 'null'
                        ? Image.network(
                            imageUrl,
                            width: 32,
                            height: 32,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Center(
                              child: Text(
                                _getCropEmoji(cropName),
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child: SizedBox(
                                  width: 10,
                                  height: 10,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                                  ),
                                ),
                              );
                            },
                          )
                        : Center(
                            child: Text(
                              _getCropEmoji(cropName),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    cropName,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w800, 
                      fontSize: 16,
                      color: AppColors.textBlack,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (crop['is_verified'] == true)
                  const Icon(Icons.verified_rounded, color: Colors.blue, size: 16),
              ],
            ),
            if (crop['is_verified'] != true) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.orange.withOpacity(0.2)),
                ),
                child: const Text(
                  'PENDING',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Variety: ${crop['variety'] ?? 'N/A'}', 
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textGray.withOpacity(0.6), fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'Area: ${crop['acre'] ?? 'N/A'} Acre', 
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textGray.withOpacity(0.6), fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${crop['count'] ?? 'N/A'} Nos', 
                      style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary)
                    ),
                    Text(
                      crop['age'] ?? 'N/A', 
                      style: GoogleFonts.outfit(fontSize: 10, color: AppColors.textGray.withOpacity(0.5), fontWeight: FontWeight.w700)
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.primary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  _InfoCardTheme _getCardTheme(String label, bool isLink) {
    if (isLink) {
      return const _InfoCardTheme(
        gradientColors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
        glowColor: Color(0xFFA5D6A7),
        iconColor: Color(0xFF2E7D32),
        iconBgColor: Color(0x66FFFFFF),
        textColor: Color(0xFF1B5E20),
        labelColor: Color(0xCC2E7D32),
      );
    }

    switch (label.toLowerCase().trim()) {
      case 'place':
        return const _InfoCardTheme(
          gradientColors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
          glowColor: Color(0xFF90CAF9),
          iconColor: Color(0xFF1565C0),
          iconBgColor: Color(0x66FFFFFF),
          textColor: Color(0xFF0D47A1),
          labelColor: Color(0xCC1565C0),
        );
      case 'area':
        return const _InfoCardTheme(
          gradientColors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
          glowColor: Color(0xFFA5D6A7),
          iconColor: Color(0xFF2E7D32),
          iconBgColor: Color(0x66FFFFFF),
          textColor: Color(0xFF1B5E20),
          labelColor: Color(0xCC2E7D32),
        );
      case 'soil':
        return const _InfoCardTheme(
          gradientColors: [Color(0xFFEFEBE9), Color(0xFFD7CCC8)],
          glowColor: Color(0xFFBCAAA4),
          iconColor: Color(0xFF5D4037),
          iconBgColor: Color(0x66FFFFFF),
          textColor: Color(0xFF3E2723),
          labelColor: Color(0xCC5D4037),
        );
      case 'irrigation':
        return const _InfoCardTheme(
          gradientColors: [Color(0xFFE0F2F1), Color(0xFFB2DFDB)],
          glowColor: Color(0xFF80CBC4),
          iconColor: Color(0xFF00796B),
          iconBgColor: Color(0x66FFFFFF),
          textColor: Color(0xFF004D40),
          labelColor: Color(0xCC00796B),
        );
      case 'source':
        return const _InfoCardTheme(
          gradientColors: [Color(0xFFE0F7FA), Color(0xFFB2EBF2)],
          glowColor: Color(0xFF80DEEA),
          iconColor: Color(0xFF00838F),
          iconBgColor: Color(0x66FFFFFF),
          textColor: Color(0xFF006064),
          labelColor: Color(0xCC00838F),
        );
      case 'qty':
        return const _InfoCardTheme(
          gradientColors: [Color(0xFFF1F8E9), Color(0xFFDCEDC8)],
          glowColor: Color(0xFFC5E1A5),
          iconColor: Color(0xFF558B2F),
          iconBgColor: Color(0x66FFFFFF),
          textColor: Color(0xFF33691E),
          labelColor: Color(0xCC558B2F),
        );
      case 'power':
        return const _InfoCardTheme(
          gradientColors: [Color(0xFFFFFDE7), Color(0xFFFFF9C4)],
          glowColor: Color(0xFFFFF59D),
          iconColor: Color(0xFFF9A825),
          iconBgColor: Color(0x66FFFFFF),
          textColor: Color(0xFFF57F17),
          labelColor: Color(0xCCF9A825),
        );
      case 'strategy':
        return const _InfoCardTheme(
          gradientColors: [Color(0xFFF3E5F5), Color(0xFFE1BEE7)],
          glowColor: Color(0xFFCE93D8),
          iconColor: Color(0xFF6A1B9A),
          iconBgColor: Color(0x66FFFFFF),
          textColor: Color(0xFF4A148C),
          labelColor: Color(0xCC6A1B9A),
        );
      default:
        return const _InfoCardTheme(
          gradientColors: [Color(0xFFF5F5F5), Color(0xFFEEEEEE)],
          glowColor: Color(0xFFE0E0E0),
          iconColor: Color(0xFF616161),
          iconBgColor: Color(0x66FFFFFF),
          textColor: Color(0xFF212121),
          labelColor: Color(0xCC616161),
        );
    }
  }

  Widget _infoCard(IconData icon, String label, String value, {bool isLink = false}) {
    final theme = _getCardTheme(label, isLink);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.glowColor.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Background with beautiful linear gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: theme.gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.6),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            
            // "Light Element" 1: Glowing soft white radial sphere at the top-right
            Positioned(
              top: -30,
              right: -30,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withOpacity(0.55),
                      Colors.white.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),

            // "Light Element" 2: Soft tinted glowing sphere at the bottom-left
            Positioned(
              bottom: -20,
              left: -20,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      theme.glowColor.withOpacity(0.6),
                      theme.glowColor.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),

            // Card Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // Glassmorphic translucent squircle icon container
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.iconBgColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.7),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: theme.iconColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          style: GoogleFonts.outfit(
                            color: theme.labelColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          value,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: theme.textColor,
                            decoration: isLink ? TextDecoration.underline : null,
                            decorationColor: theme.textColor,
                            decorationThickness: 1.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  String _formatDate(dynamic dateStr) {
    if (dateStr == null || dateStr.toString().isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateStr.toString());
      return DateFormat('MMMM dd, yyyy').format(date);
    } catch (_) {
      return dateStr.toString();
    }
  }

  Widget _buildRiseTokenButton() {
    return TextButton.icon(
      onPressed: () {
        EditRequestDialog.show(
          context,
          entityType: 'farms',
          entityId: _farm['id'].toString(),
          currentData: _farm,
          fieldMap: {
            'name': 'Farm Name',
            'area': 'Area (Acres)',
            'soil_type': 'Soil Type',
            'irrigation_type': 'Irrigation Type',
            'water_source': 'Water Source',
            'water_quantity': 'Water Quantity',
            'power_source': 'Power Source',
            'landmark': 'Landmark',
            'intercrop': 'Intercrop Strategy',
          },
        );
      },
      icon: const Icon(
        Icons.add_alert_rounded,
        size: 14,
        color: Colors.orangeAccent,
      ),
      label: const Text(
        'Rise Token',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
      style: TextButton.styleFrom(
        backgroundColor: Colors.orange.withOpacity(0.2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.orange.withOpacity(0.5)),
        ),
      ),
    );
  }
}

class _AssignExecutiveDialog extends StatefulWidget {
  final String? currentAssignedId;
  final Function(Map<String, dynamic>?) onAssign;

  const _AssignExecutiveDialog({this.currentAssignedId, required this.onAssign});

  @override
  State<_AssignExecutiveDialog> createState() => _AssignExecutiveDialogState();
}

class _AssignExecutiveDialogState extends State<_AssignExecutiveDialog> {
  List<Map<String, dynamic>> _executives = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExecutives();
  }

  Future<void> _loadExecutives() async {
    final data = await SupabaseService.getExecutives();
    if (mounted) {
      setState(() {
        _executives = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Assign Executive'),
      content: _isLoading 
        ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
        : SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _executives.length + 1, // +1 for "Unassign"
              itemBuilder: (context, index) {
                if (index == 0) {
                  return ListTile(
                    leading: const Icon(Icons.person_off_rounded),
                    title: const Text('Unassign'),
                    onTap: () => widget.onAssign(null),
                  );
                }
                final executive = _executives[index - 1];
                final isSelected = widget.currentAssignedId == executive['id'];
                
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.secondary,
                    child: Text(executive['full_name']?[0] ?? 'E'),
                  ),
                  title: Text(executive['full_name'] ?? 'N/A'),
                  subtitle: Text('@${executive['username']}'),
                  trailing: isSelected ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
                  onTap: () => widget.onAssign(executive),
                );
              },
            ),
          ),
    );
  }
}

class _InfoCardTheme {
  final List<Color> gradientColors;
  final Color glowColor;
  final Color iconColor;
  final Color iconBgColor;
  final Color textColor;
  final Color labelColor;

  const _InfoCardTheme({
    required this.gradientColors,
    required this.glowColor,
    required this.iconColor,
    required this.iconBgColor,
    required this.textColor,
    required this.labelColor,
  });
}

