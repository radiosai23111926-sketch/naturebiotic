import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:nature_biotic/services/local_database_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:nature_biotic/features/reports/screens/report_generator_screen.dart';
import 'package:intl/intl.dart';
import 'package:nature_biotic/features/crops/screens/add_crop_screen.dart';
import 'package:nature_biotic/features/reports/screens/create_report_screen.dart';
import 'package:nature_biotic/features/profile/screens/edit_request_dialog.dart';

class CropDetailScreen extends StatefulWidget {
  final Map<String, dynamic> crop;
  final String? farmName;
  final String? farmerName;

  const CropDetailScreen({
    super.key,
    required this.crop,
    this.farmName,
    this.farmerName,
  });

  @override
  State<CropDetailScreen> createState() => _CropDetailScreenState();
}

class __CropDetailScreenState extends State<CropDetailScreen> {
  List<Map<String, dynamic>> _reports = [];
  String? _userRole;
  bool _isLoadingReports = true;
  late Map<String, dynamic> _crop;
  String? _cropImageUrl;

  @override
  void initState() {
    super.initState();
    _crop = widget.crop;
    _loadUserRole();
    _loadReports();
    _loadCropImage();
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

  Future<void> _loadCropImage() async {
    try {
      final cropName = _crop['name']?.toString().trim();
      if (cropName == null || cropName.isEmpty) return;

      final masterCrops = await SupabaseService.getMasterCrops();
      final matchingCrop = masterCrops.firstWhere(
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

      // Live Supabase fallback if image URL is not found in cache or masterCrops
      if (imageUrl == null || imageUrl.isEmpty || imageUrl == 'null') {
        try {
          final liveData = await SupabaseService.client
              .from('master_crops')
              .select('image_url')
              .ilike('name', cropName)
              .maybeSingle();
          if (liveData != null && liveData['image_url'] != null && liveData['image_url'] != 'null') {
            imageUrl = liveData['image_url'] as String?;
          }
        } catch (e) {
          debugPrint('Error loading crop image from live DB: $e');
        }
      }

      if (mounted) {
        setState(() {
          _cropImageUrl = (imageUrl != null && imageUrl.isNotEmpty && imageUrl != 'null') ? imageUrl : null;
        });
      }
    } catch (e) {
      debugPrint('Error loading crop image: $e');
    }
  }

  Future<void> _refreshCropData() async {
    try {
      setState(() => _isLoadingReports = true);
      
      final cropId = _crop['id'].toString();
      Map<String, dynamic>? updatedCrop;
      
      if (kIsWeb) {
        final res = await SupabaseService.client
            .from('crops')
            .select()
            .eq('id', cropId)
            .maybeSingle();
        if (res != null) {
          updatedCrop = Map<String, dynamic>.from(res);
        }
      } else {
        final res = await LocalDatabaseService.getData(
          'crops',
          where: 'id = ?',
          whereArgs: [cropId],
        );
        if (res.isNotEmpty) {
          updatedCrop = res.first;
        }
      }
      
      if (mounted && updatedCrop != null) {
        setState(() {
          _crop = updatedCrop!;
        });
        await _loadCropImage();
        await _loadReports();
      }
    } catch (e) {
      debugPrint('Error refreshing crop data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingReports = false);
      }
    }
  }

  Future<void> _loadUserRole() async {
    final profile = await SupabaseService.getProfile();
    if (mounted) {
      setState(() {
        _userRole = profile?['role'];
      });
    }
  }

  Future<void> _loadReports() async {
    try {
      final farmId = _crop['farm_id']?.toString();
      final remoteReports = await SupabaseService.getReportsForCrop(
        _crop['id'].toString(),
        cropName: _crop['name'],
        farmId: farmId,
      );
      List<Map<String, dynamic>> localReports = [];

      if (!kIsWeb) {
        final cropName = _crop['name'] ?? '';
        localReports = await LocalDatabaseService.getData(
          'reports',
          where: 'farm_id = ? AND (crop_id = ? OR problem LIKE ?)',
          whereArgs: [farmId ?? '', _crop['id'].toString(), '%--- Crop: $cropName ---%'],
          columns: [
            'id',
            'farm_id',
            'crop_id',
            'problem',
            'previous_inputs',
            'recommendations',
            'estimated_cost',
            'signature_url',
            'created_by',
            'created_at',
          ],
        );
      }

      if (mounted) {
        setState(() {
          // Merge and De-duplicate
          final Map<String, Map<String, dynamic>> combinedMap = {};

          for (var report in localReports) {
            combinedMap[report['id'].toString()] = report;
          }
          for (var report in remoteReports) {
            combinedMap[report['id'].toString()] = report;
          }

          _reports = combinedMap.values.toList();
          _reports.sort(
            (a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''),
          );
          _isLoadingReports = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingReports = false);
    }
  }

  @override
  Widget build(BuildContext context) {

    final width = MediaQuery.sizeOf(context).width;
    final bool isWide = width > 1100;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_crop['name'] ?? 'Crop Details'),
        actions: [
          if (_userRole == 'admin' || (_userRole != 'manager' && _crop['is_verified'] != true))
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => AddCropScreen(
                          crop: _crop,
                          farmId: _crop['farm_id']?.toString(),
                        ),
                  ),
                ).then((value) async {
                  if (value == true) {
                    await _refreshCropData();
                  }
                });
              },
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Info
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: _cropImageUrl != null && _cropImageUrl!.isNotEmpty && _cropImageUrl != 'null'
                              ? Colors.white
                              : _getCropColor(_crop['name'] ?? ''),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: _cropImageUrl != null && _cropImageUrl!.isNotEmpty && _cropImageUrl != 'null'
                              ? Image.network(
                                  _cropImageUrl!,
                                  width: 52,
                                  height: 52,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Center(
                                      child: Text(
                                        _getCropEmoji(_crop['name'] ?? ''),
                                        style: const TextStyle(fontSize: 24),
                                      ),
                                    );
                                  },
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return const Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : Center(
                                  child: Text(
                                    _getCropEmoji(_crop['name'] ?? ''),
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _crop['variety'] ?? 'Unknown Variety',
                              style: const TextStyle(
                                color: AppColors.textGray,
                                fontSize: 11,
                              ),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _crop['name'] ?? 'N/A',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (_crop['is_verified'] == true)
                                  const Icon(Icons.verified_rounded, color: Colors.blue, size: 18),
                              ],
                            ),
                            if (_crop['is_verified'] == true) ...[
                              const SizedBox(height: 6),
                              _buildRiseTokenButton(),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                if (_userRole == 'manager' && _crop['is_verified'] != true) ...[
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          await SupabaseService.verifyItem('crops', _crop['id']);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Crop Verified Successfully'), backgroundColor: Colors.green),
                            );
                            setState(() => _crop['is_verified'] = true);
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Verification failed: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.verified_user_rounded),
                      label: const Text('Verify Crop Entry', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                const Text(
                  'Crop Metrics',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textBlack,
                  ),
                ),
                const SizedBox(height: 16),

                // Grid for Growth and Scale
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isGridWide = constraints.maxWidth > 600;
                    return GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: isGridWide ? 4 : 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: isGridWide ? 1.5 : 2.2,
                      children: [
                        _infoCard(
                          Icons.history_rounded,
                          'Current Age',
                          _crop['age'] ?? 'N/A',
                        ),
                        _infoCard(
                          Icons.timer_rounded,
                          'Total Life',
                          _crop['life'] ?? 'N/A',
                        ),
                        _infoCard(
                          Icons.straighten_rounded,
                          'Acres',
                          _crop['acre'] ?? 'N/A',
                        ),
                        _infoCard(
                          Icons.numbers_rounded,
                          'Count',
                          _crop['count'] ?? 'N/A',
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 24),
                const Text(
                  'Yield Expectations',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textBlack,
                  ),
                ),
                const SizedBox(height: 16),
                _infoCard(
                  Icons.show_chart_rounded,
                  'Expected Yield',
                  _crop['expected_yield'] ?? 'N/A',
                ),

                if (_userRole != 'manager')
                  const SizedBox(height: 32),
                if (_userRole != 'manager')
                  Center(
                    child: SizedBox(
                      width: isWide ? 400 : double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => CreateReportScreen(
                                    preSelectedFarmId:
                                        _crop['farm_id']?.toString(),
                                    preSelectedCropId:
                                        _crop['id']?.toString(),
                                  ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add_task_rounded),
                        label: const Text(
                          'Add New Visit (Analysis Report)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 48),
                Center(
                  child: Text(
                    'Report History',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textBlack,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildReportHistoryTable(isWide: isWide),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReportHistoryTable({bool isWide = false}) {
    if (_isLoadingReports) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_reports.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.secondary.withOpacity(0.3),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 40,
              color: AppColors.textGray,
            ),
            SizedBox(height: 12),
            Text(
              'No report history available',
              style: TextStyle(color: AppColors.textGray),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: isWide ? 860 : 0),
            child: DataTable(
              horizontalMargin: isWide ? 24 : 16,
              columnSpacing: isWide ? 48 : 24,
              headingRowColor: WidgetStateProperty.all(
                AppColors.secondary.withOpacity(0.5),
              ),
              columns: [
                const DataColumn(
                  label: Text(
                    'Date',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const DataColumn(
                  label: Text(
                    'Problem Identified',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (isWide)
                  const DataColumn(
                    label: Text(
                      'Recommendations',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                const DataColumn(
                  label: Text('', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
              rows:
                  _reports.map((report) {
                    final date = DateTime.parse(report['created_at']);
    
                    // Clean up problem text (remove image metadata if present)
                    String problemDisplay = report['problem'] ?? 'N/A';
                    if (problemDisplay.contains('{img:')) {
                      problemDisplay = problemDisplay.split('{img:')[0].trim();
                    }
    
                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            DateFormat('MMM dd, yyyy').format(date),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        DataCell(
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: isWide ? 220 : 180),
                            child: Text(
                              problemDisplay,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                        if (isWide)
                          DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 300),
                              child: Text(
                                report['recommendations'] ?? 'N/A',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ),
                        DataCell(
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => ReportGeneratorScreen(
                                        report: report,
                                        farmName: widget.farmName,
                                        cropName: _crop['name'],
                                        farmerName: widget.farmerName,
                                      ),
                                ),
                              );
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 0),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'View More',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  _InfoCardTheme _getCardTheme(String label) {
    switch (label.toLowerCase().trim()) {
      case 'current age':
        return const _InfoCardTheme(
          gradientColors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
          glowColor: Color(0xFFA5D6A7),
          iconColor: Color(0xFF2E7D32),
          iconBgColor: Color(0x66FFFFFF),
          textColor: Color(0xFF1B5E20),
          labelColor: Color(0xCC2E7D32),
        );
      case 'total life':
        return const _InfoCardTheme(
          gradientColors: [Color(0xFFE0F2F1), Color(0xFFB2DFDB)],
          glowColor: Color(0xFF80CBC4),
          iconColor: Color(0xFF00796B),
          iconBgColor: Color(0x66FFFFFF),
          textColor: Color(0xFF004D40),
          labelColor: Color(0xCC00796B),
        );
      case 'acres':
        return const _InfoCardTheme(
          gradientColors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)],
          glowColor: Color(0xFFFFCC80),
          iconColor: Color(0xFFE65100),
          iconBgColor: Color(0x66FFFFFF),
          textColor: Color(0xFFBF360C),
          labelColor: Color(0xCCE65100),
        );
      case 'count':
        return const _InfoCardTheme(
          gradientColors: [Color(0xFFF3E5F5), Color(0xFFE1BEE7)],
          glowColor: Color(0xFFCE93D8),
          iconColor: Color(0xFF6A1B9A),
          iconBgColor: Color(0x66FFFFFF),
          textColor: Color(0xFF4A148C),
          labelColor: Color(0xCC6A1B9A),
        );
      case 'expected yield':
        return const _InfoCardTheme(
          gradientColors: [Color(0xFFFFFDE7), Color(0xFFFFF9C4)],
          glowColor: Color(0xFFFFF59D),
          iconColor: Color(0xFFF9A825),
          iconBgColor: Color(0x66FFFFFF),
          textColor: Color(0xFFF57F17),
          labelColor: Color(0xCCF9A825),
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

  Widget _infoCard(IconData icon, String label, String value) {
    final theme = _getCardTheme(label);

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

  Widget _buildRiseTokenButton() {
    return TextButton.icon(
      onPressed: () {
        EditRequestDialog.show(
          context,
          entityType: 'crops',
          entityId: _crop['id'].toString(),
          currentData: _crop,
          fieldMap: {
            'name': 'Crop Name',
            'variety': 'Variety',
            'age': 'Current Age',
            'life': 'Total Life',
            'acre': 'Acres',
            'count': 'Count / Trees',
            'expected_yield': 'Expected Yield',
          },
        );
      },
      icon: const Icon(
        Icons.add_alert_rounded,
        size: 14,
        color: Colors.orange,
      ),
      label: const Text(
        'Rise Token',
        style: TextStyle(
          color: Colors.orange,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
      style: TextButton.styleFrom(
        backgroundColor: Colors.orange.withOpacity(0.1),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _CropDetailScreenState extends __CropDetailScreenState {}

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

