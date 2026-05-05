import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:nature_biotic/features/farms/screens/add_farm_screen.dart';
import 'package:nature_biotic/features/farms/screens/farm_detail_screen.dart';
import 'package:nature_biotic/features/farms/screens/stock_management_screen.dart';
import 'package:nature_biotic/services/local_database_service.dart';
import 'package:nature_biotic/core/widgets/animations.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:nature_biotic/services/pdf_service.dart';

class FarmListScreen extends StatefulWidget {
  final bool isStockMode;
  const FarmListScreen({super.key, this.isStockMode = false});

  @override
  State<FarmListScreen> createState() => _FarmListScreenState();
}

class _FarmListScreenState extends State<FarmListScreen> {
  List<Map<String, dynamic>> _farms = [];
  Map<String, List<Map<String, dynamic>>> _farmBalances = {};
  String? _userRole;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFarms();
  }

  Future<void> _loadFarms() async {
    setState(() => _isLoading = true);
    try {
      final profile = await SupabaseService.getProfile();
      _userRole = profile?['role'];
      
      final remoteData = await SupabaseService.getFarms();
      List<Map<String, dynamic>> localData = [];

      if (!kIsWeb) {
        localData = await LocalDatabaseService.getData('farms');
      }

      // Merge and De-duplicate
      final Map<String, Map<String, dynamic>> combinedMap = {};
      for (var farm in remoteData) {
        combinedMap[farm['id'].toString()] = farm;
      }
      for (var farm in localData) {
        combinedMap[farm['id'].toString()] = farm;
      }

      final farms = combinedMap.values.toList();
      farms.sort(
        (a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''),
      );

      // If in stock mode, fetch and calculate balances
      if (widget.isStockMode) {
        final transactions = await SupabaseService.getAllStockTransactions();
        _calculateAllBalances(transactions);
      }

      if (mounted) {
        setState(() {
          _farms = farms;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading farms: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load farms: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _calculateAllBalances(List<Map<String, dynamic>> transactions) {
    final Map<String, Map<String, Map<String, dynamic>>> farmItemMap = {};

    for (var tx in transactions) {
      final farmId = tx['farm_id']?.toString() ?? 'unknown';
      final item = tx['item_name'] ?? 'Unknown';
      final unit = tx['unit'] ?? 'Std';
      final qty = double.tryParse(tx['quantity'].toString()) ?? 0.0;
      final type = tx['transaction_type'];

      if (!farmItemMap.containsKey(farmId)) farmItemMap[farmId] = {};
      final itemKey = "$item ($unit)";

      if (!farmItemMap[farmId]!.containsKey(itemKey)) {
        farmItemMap[farmId]![itemKey] = {
          'item': item,
          'unit': unit,
          'balance': 0.0,
        };
      }

      if (type == 'RECEIVED') {
        farmItemMap[farmId]![itemKey]!['balance'] += qty;
      } else if (type == 'DELIVERED' || type == 'RETURN') {
        farmItemMap[farmId]![itemKey]!['balance'] -= qty;
      }
    }

    setState(() {
      _farmBalances = farmItemMap.map(
        (fid, items) => MapEntry(fid, items.values.toList()),
      );
    });
  }

  Future<void> _editFarm(Map<String, dynamic> farm) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddFarmScreen(farm: farm)),
    );
    _loadFarms();
  }

  Future<void> _deleteFarm(Map<String, dynamic> farm) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Farm'),
            content: Text('Are you sure you want to delete ${farm['name']}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        await SupabaseService.deleteFarm(farm['id']);
        _loadFarms();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Farm deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting farm: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showStockDownloadDialog() async {
    final Set<String> selectedIds =
        _farms.map((f) => f['id'].toString()).toSet();

    await showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              final allSelected = selectedIds.length == _farms.length;

              return AlertDialog(
                title: Row(
                  children: [
                    const Icon(
                      Icons.picture_as_pdf_rounded,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Download Stock Report')),
                  ],
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CheckboxListTile(
                        title: const Text(
                          'Select All Farms',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        value: allSelected,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) {
                          setDialogState(() {
                            if (val == true) {
                              selectedIds.addAll(
                                _farms.map((f) => f['id'].toString()),
                              );
                            } else {
                              selectedIds.clear();
                            }
                          });
                        },
                      ),
                      const Divider(),
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _farms.length,
                          itemBuilder: (context, index) {
                            final farm = _farms[index];
                            final farmId = farm['id'].toString();
                            return CheckboxListTile(
                              title: Text(farm['name'] ?? 'Unknown Farm'),
                              subtitle: Text(
                                farm['place'] ?? '',
                                style: const TextStyle(fontSize: 11),
                              ),
                              value: selectedIds.contains(farmId),
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (val) {
                                setDialogState(() {
                                  if (val == true) {
                                    selectedIds.add(farmId);
                                  } else {
                                    selectedIds.remove(farmId);
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
                    onPressed:
                        selectedIds.isEmpty
                            ? null
                            : () {
                              Navigator.pop(context);
                              _handlePdfGeneration(selectedIds.toList());
                            },
                    child: const Text('Download PDF'),
                  ),
                ],
              );
            },
          ),
    );
  }

  Future<void> _handlePdfGeneration(List<String> farmIds) async {
    setState(() => _isLoading = true);
    try {
      final transactions = await SupabaseService.getAllStockTransactions();

      // Calculate balances for each farm
      final List<Map<String, dynamic>> reportData = [];

      for (var farmId in farmIds) {
        final farm = _farms.firstWhere(
          (f) => f['id'].toString() == farmId,
          orElse: () => {},
        );
        if (farm.isEmpty) continue;

        final farmName = farm['name'] ?? farm['place'] ?? 'Unknown Farm';

        // Calculate balance for this specific farm
        final Map<String, Map<String, dynamic>> balancesPerItem = {};
        final farmTransactions = transactions.where(
          (tx) => tx['farm_id'].toString() == farmId,
        );

        for (var tx in farmTransactions) {
          final item = tx['item_name'] ?? 'Unknown';
          final unit = tx['unit'] ?? 'Std';
          final qty = double.tryParse(tx['quantity'].toString()) ?? 0.0;
          final type = tx['transaction_type'];
          final key = "$item ($unit)";

          if (!balancesPerItem.containsKey(key)) {
            balancesPerItem[key] = {'item': item, 'unit': unit, 'balance': 0.0};
          }

          if (type == 'RECEIVED') {
            balancesPerItem[key]!['balance'] += qty;
          } else if (type == 'DELIVERED' || type == 'RETURN') {
            balancesPerItem[key]!['balance'] -= qty;
          }
        }

        reportData.add({
          'farmName': farmName,
          'balances': balancesPerItem.values.toList(),
        });
      }

      await PdfService.generateMultiFarmStockReport(
        farmData: reportData,
        date: DateTime.now(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock report generated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
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
        title: const Text('Farms'),
        actions: [
          IconButton(
            onPressed: _showStockDownloadDialog,
            icon: const Icon(
              Icons.picture_as_pdf_outlined,
              color: AppColors.primary,
            ),
            tooltip: 'Download Stock Report',
          ),
          IconButton(
            onPressed: _loadFarms,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _farms.isEmpty
              ? const Center(child: Text('No farms registered.'))
              : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(24.0),
                    itemCount: _farms.length,
                    itemBuilder: (context, index) {
                      final farm = _farms[index];
                      return EntranceAnimation(
                        delay: 100 + (index * 100),
                        child: FarmCard(
                          name: farm['name'] ?? farm['place'] ?? 'N/A',
                          place: farm['place'] ?? 'N/A',
                          area: '${farm['area'] ?? '0'} Acres',
                          soilType: farm['soil_type'] ?? 'N/A',
                          onEdit: () => _editFarm(farm),
                          onDelete: () => _deleteFarm(farm),
                          onViewDetails: () {
                            debugPrint(
                              'Opening farm details for: ${farm['name']}',
                            );
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => FarmDetailScreen(farm: farm),
                              ),
                            );
                          },
                          onManageStock: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => StockManagementScreen(
                                      farmId: farm['id'].toString(),
                                      farmName:
                                          farm['name'] ??
                                          farm['place'] ??
                                          'N/A',
                                    ),
                              ),
                            );
                          },
                          balances: _farmBalances[farm['id'].toString()],
                          isVerified: farm['is_verified'] == true,
                          isManager: _userRole == 'manager',
                          isAdmin: _userRole == 'admin',
                        ),
                      );
                    },
                  ),
                ),
              ),
      floatingActionButton: null,
    );
  }
}

class FarmCard extends StatelessWidget {
  final String name;
  final String place;
  final String area;
  final String soilType;
  final VoidCallback? onViewDetails;
  final VoidCallback? onManageStock;
  final List<Map<String, dynamic>>? balances;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool isVerified;
  final bool isManager;
  final bool isAdmin;

  const FarmCard({
    super.key,
    required this.name,
    required this.place,
    required this.area,
    required this.soilType,
    this.onViewDetails,
    this.onManageStock,
    this.balances,
    this.onEdit,
    this.onDelete,
    this.isVerified = true,
    this.isManager = false,
    this.isAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.agriculture_rounded,
                  color: AppColors.primary,
                ),
              ),
              if (isAdmin || (!isManager && !isVerified))
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onEdit?.call();
                    if (value == 'delete') onDelete?.call();
                  },
                  itemBuilder:
                      (context) => [
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            'Delete',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: AppColors.textGray,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textBlack,
            ),
          ),
          Text(
            place,
            style: const TextStyle(fontSize: 14, color: AppColors.textGray),
          ),
          if (!isVerified) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.pending_actions_rounded, size: 14, color: Colors.orange),
                  SizedBox(width: 8),
                  Text(
                    'PENDING VERIFICATION',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              _infoTile(Icons.square_foot_rounded, area),
              const SizedBox(width: 16),
              _infoTile(Icons.waves_rounded, soilType),
            ],
          ),
          if (balances != null && balances!.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Stock in Hand:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  balances!
                      .map(
                        (b) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (b['balance'] as double) > 0
                                    ? Colors.teal.withOpacity(0.1)
                                    : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  (b['balance'] as double) > 0
                                      ? Colors.teal.withOpacity(0.3)
                                      : Colors.red.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            '${b['item']}: ${b['balance'].toString().replaceAll(RegExp(r'\.0$'), '')}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color:
                                  (b['balance'] as double) > 0
                                      ? Colors.teal
                                      : Colors.red,
                            ),
                          ),
                        ),
                      )
                      .toList(),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: OutlinedButton.icon(
                  onPressed: onManageStock,
                  icon: const Icon(Icons.inventory_2_rounded, size: 16),
                  label: const Text('Stock', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.teal,
                    side: const BorderSide(color: Colors.teal),
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 5,
                child: ElevatedButton(
                  onPressed: onViewDetails,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    minimumSize: const Size(0, 44),
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text(
                    'View Details',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textGray),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textGray),
        ),
      ],
    );
  }
}
