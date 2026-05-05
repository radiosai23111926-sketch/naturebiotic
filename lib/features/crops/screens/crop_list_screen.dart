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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCrops();
  }

  Future<void> _loadCrops() async {
    setState(() => _isLoading = true);
    try {
      final crops = await SupabaseService.getAllCrops();
      if (mounted) {
        setState(() {
          _crops = crops;
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

                                return EntranceAnimation(
                                  delay: 100 + (index * 100),
                                  child: CropCard(
                                    cropName: crop['name'] ?? 'Unknown',
                                    variety: crop['variety'] ?? 'Unknown',
                                    age: crop['age'] ?? 'N/A',
                                    expectedYield:
                                        crop['expected_yield'] ?? 'N/A',
                                    farmName: farmName,
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
}

class CropCard extends StatelessWidget {
  final String cropName;
  final String variety;
  final String age;
  final String expectedYield;
  final String farmName;
  final VoidCallback onTap;

  const CropCard({
    super.key,
    required this.cropName,
    required this.variety,
    required this.age,
    required this.expectedYield,
    required this.farmName,
    required this.onTap,
  });

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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.eco_rounded,
                    color: AppColors.primary,
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
