import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/features/crops/screens/crop_detail_screen.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:nature_biotic/core/widgets/animations.dart';

class CropListScreen extends StatefulWidget {
  const CropListScreen({super.key});

  @override
  State<CropListScreen> createState() => _CropListScreenState();
}

class _CropListScreenState extends State<CropListScreen> {
  List<Map<String, dynamic>> _crops = [];
  List<Map<String, dynamic>> _masterCrops = [];
  bool _isLoading = true;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _loadCrops();
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

  Future<void> _loadCrops() async {
    setState(() => _isLoading = true);
    try {
      final profile = await SupabaseService.getProfile();
      _userRole = profile?['role'];
      
      final crops = await SupabaseService.getAllCrops();
      List<Map<String, dynamic>> masterCrops = [];
      try {
        masterCrops = await SupabaseService.getMasterCrops();
      } catch (e) {
        debugPrint('Error loading master crops: $e');
      }

      if (mounted) {
        setState(() {
          _crops = crops;
          _masterCrops = masterCrops;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading crops: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Crops'),
        actions: [
          IconButton(
            onPressed: _loadCrops,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _loadCrops,
                child:
                    _crops.isEmpty
                        ? _buildEmptyState()
                        : Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 800),
                            child: ListView.builder(
                              padding: const EdgeInsets.all(24.0),
                              itemCount: _crops.length,
                              itemBuilder: (context, index) {
                                final crop = _crops[index];
                                final farmName =
                                    crop['farms']?['name'] ?? 'N/A';
                                final farmerName =
                                    crop['farms']?['farmers']?['name'] ?? 'N/A';

                                final cropName = crop['name'] ?? 'Unknown';
                                final matchingCrop = _masterCrops.firstWhere(
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

                                return EntranceAnimation(
                                  delay: 100 + (index * 100),
                                  child: CropCard(
                                    cropName: cropName,
                                    variety: crop['variety'] ?? 'Unknown',
                                    age: crop['age'] ?? 'N/A',
                                    expectedYield:
                                        crop['expected_yield'] ?? 'N/A',
                                    farmName: farmName,
                                    imageUrl: imageUrl,
                                    isAdmin: _userRole == 'admin',
                                    onDelete: () => _handleDeleteCrop(crop),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) => CropDetailScreen(
                                                crop: crop,
                                                farmName: farmName,
                                                farmerName: farmerName,
                                              ),
                                        ),
                                      ).then((value) {
                                        if (value == true) _loadCrops();
                                      });
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
              ),
      floatingActionButton: null,
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.eco_outlined, size: 64, color: AppColors.textGray),
          SizedBox(height: 16),
          Text(
            'No crops found',
            style: TextStyle(color: AppColors.textGray, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteCrop(Map<String, dynamic> crop) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Crop'),
        content: Text('Are you sure you want to delete "${crop['name']}" variety of "${crop['variety']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await SupabaseService.deleteRecord('farm_crops', crop['id']);
        _loadCrops();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Crop deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}

class CropCard extends StatelessWidget {
  final String cropName;
  final String variety;
  final String age;
  final String expectedYield;
  final String farmName;
  final String? imageUrl;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final bool isAdmin;

  const CropCard({
    super.key,
    required this.cropName,
    required this.variety,
    required this.age,
    required this.expectedYield,
    required this.farmName,
    required this.onTap,
    this.imageUrl,
    this.onDelete,
    this.isAdmin = false,
  });

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

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.secondary,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: imageUrl != null && imageUrl!.isNotEmpty && imageUrl != 'null'
                        ? Colors.white
                        : _getCropColor(cropName),
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
                    child: imageUrl != null && imageUrl!.isNotEmpty && imageUrl != 'null'
                        ? Image.network(
                            imageUrl!,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Text(
                                  _getCropEmoji(cropName),
                                  style: const TextStyle(fontSize: 22),
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                                  ),
                                ),
                              );
                            },
                          )
                        : Center(
                            child: Text(
                              _getCropEmoji(cropName),
                              style: const TextStyle(fontSize: 22),
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
                        farmName,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        cropName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textBlack,
                        ),
                      ),
                      Text(
                        variety,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textGray,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isAdmin)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, color: AppColors.primary),
                    onSelected: (val) {
                      if (val == 'delete') onDelete?.call();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  )
                else
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.primary,
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _dataCell('Crop Age', age),
                _dataCell('Exp. Yield', expectedYield),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dataCell(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textGray),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}
