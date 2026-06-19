import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:nature_biotic/services/local_database_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:nature_biotic/services/pdf_service.dart';
import 'add_stock_entry_screen.dart';

class StockManagementScreen extends StatefulWidget {
  final String farmId;
  final String farmName;
  final String? farmerName;
  final String? cropName;

  const StockManagementScreen({
    super.key,
    required this.farmId,
    required this.farmName,
    this.farmerName,
    this.cropName,
  });

  @override
  State<StockManagementScreen> createState() => _StockManagementScreenState();
}

class _StockManagementScreenState extends State<StockManagementScreen> {
  List<Map<String, dynamic>> _transactions = [];
  Map<String, Map<String, dynamic>> _balances = {};
  List<Map<String, dynamic>> _allProducts = [];
  bool _isLoading = true;
  String? _farmLocation;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      List<Map<String, dynamic>> remoteData = [];
      try {
        remoteData = await SupabaseService.getStockTransactions(widget.farmId);
      } catch (_) {}

      final products = await SupabaseService.getHierarchicalDropdownOptions(
        'product_name',
      );

      List<Map<String, dynamic>> localData = [];
      if (!kIsWeb) {
        localData = await LocalDatabaseService.getData(
          'stock_transactions',
          where: 'farm_id = ?',
          whereArgs: [widget.farmId],
        );
      }

      final profile = await SupabaseService.getProfile().catchError(
        (_) => null,
      );
      
      String? fetchedLocation;
      try {
        if (!kIsWeb) {
          final localFarms = await LocalDatabaseService.getData('farms', where: 'id = ?', whereArgs: [widget.farmId]);
          if (localFarms.isNotEmpty) {
            fetchedLocation = localFarms.first['location']?.toString();
          }
        }
        if (fetchedLocation == null) {
          final farmData = await SupabaseService.client.from('farms').select('location').eq('id', widget.farmId).maybeSingle();
          if (farmData != null) {
            fetchedLocation = farmData['location']?.toString();
          }
        }
      } catch (_) {}
      final role = profile?['role']?.toString().toLowerCase();
      final userId = SupabaseService.client.auth.currentUser?.id.toLowerCase();

      // Merge and De-duplicate
      final Map<String, Map<String, dynamic>> combined = {};
      for (var tx in localData) {
        combined[tx['id'].toString()] = tx;
      }
      for (var tx in remoteData) {
        combined[tx['id'].toString()] = tx;
      }

      var sortedTransactions = combined.values.toList();

      // Apply explicit final UI-level security lock
      if ((role == 'executive' || role == 'telecaller') && userId != null) {
        sortedTransactions =
            sortedTransactions.where((t) {
              final txId = t['executive_id']?.toString().toLowerCase();
              return txId == userId;
            }).toList();
      }

      sortedTransactions.sort(
        (a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''),
      );

      _calculateBalances(sortedTransactions);

      if (mounted) {
        setState(() {
          _transactions = sortedTransactions;
          _allProducts = products;
          _farmLocation = fetchedLocation;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _calculateBalances(List<Map<String, dynamic>> transactions) {
    final Map<String, Map<String, dynamic>> balanceMap = {};

    for (var tx in transactions) {
      final item = tx['item_name'] ?? 'Unknown';
      // Clean unit from packed metadata if present
      final rawUnit = tx['unit']?.toString() ?? 'Standard';
      final packetSize = rawUnit.split(' {₹')[0].trim();
      final key = "$item ($packetSize)";
      final qty = double.tryParse(tx['quantity'].toString()) ?? 0.0;
      final type = tx['transaction_type'];

      if (!balanceMap.containsKey(key)) {
        balanceMap[key] = {'balance': 0.0, 'item': item, 'unit': packetSize};
      }

      if (type == 'RECEIVED') {
        balanceMap[key]!['balance'] += qty;
      } else if (type == 'DELIVERED' || type == 'RETURN') {
        balanceMap[key]!['balance'] -= qty;
      }
    }
    _balances = balanceMap;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sales History', style: TextStyle(fontSize: 16)),
            Text(
              '${widget.farmerName ?? 'Farmer'} • ${widget.farmName}${widget.cropName != null ? ' • ${widget.cropName}' : ''}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSummaryCard(),
                      const SizedBox(height: 24),
                      const Text(
                        'Transaction History',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textBlack,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_transactions.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Text(
                              'No sales activities recorded yet.',
                              style: TextStyle(color: AppColors.textGray),
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _transactions.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            return _buildTransactionCard(_transactions[index]);
                          },
                        ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'stock_fab',
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => AddStockEntryScreen(
                    farmId: widget.farmId,
                    farmName: widget.farmName,
                    farmerName: widget.farmerName,
                    cropName: widget.cropName,
                  ),
            ),
          );
          if (result == true) _loadData();
        },
        label: const Text('New Entry'),
        icon: const Icon(Icons.add_rounded),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Widget _buildSummaryCard() {
    if (_balances.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.secondary,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 48,
              color: AppColors.primary,
            ),
            SizedBox(height: 12),
            Text(
              'No Stock in Hand',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              'Record activities to see current balance',
              style: TextStyle(color: AppColors.textGray, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.analytics_outlined, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Current Balances',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const Divider(height: 24),
          ..._balances.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.value['item'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Size: ${e.value['unit']}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${e.value['balance']} Pkts',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color:
                          (e.value['balance'] as double) < 0
                              ? Colors.red
                              : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> tx) {
    final type = tx['transaction_type'];
    final bool isAddition = type == 'RECEIVED';
    final Color color =
        type == 'RECEIVED'
            ? Colors.green
            : (type == 'RETURN' ? Colors.blue : Colors.orange);

    final IconData icon =
        type == 'RECEIVED'
            ? Icons.download_rounded
            : (type == 'RETURN'
                ? Icons.settings_backup_restore_rounded
                : Icons.upload_rounded);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx['item_name'] ?? 'N/A',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  _formatType(type),
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Builder(
                    builder: (context) {
                      String unitDisplay = tx['unit'] ?? 'N/A';

                      // Remove old `{₹...}` suffix if it exists for backwards compatibility
                      if (unitDisplay.contains('{₹')) {
                        unitDisplay = unitDisplay.split(' {₹')[0];
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${isAddition ? "+" : "-"}${tx['quantity']} x $unitDisplay',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color:
                                  isAddition
                                      ? Colors.green
                                      : (type == 'RETURN'
                                          ? Colors.blue
                                          : Colors.orange),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _viewChallan(tx),
                    icon: const Icon(
                      Icons.receipt_long_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    tooltip: 'View Challan',
                  ),
                ],
              ),
              Text(
                _formatDate(tx['created_at']),
                style: const TextStyle(color: AppColors.textGray, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _viewChallan(Map<String, dynamic> tx) async {
    // 1. Find all items recorded at the same time (within 1 second)
    final createdAt = DateTime.parse(tx['created_at'].toString());
    final sameBatch =
        _transactions.where((t) {
          final tDate = DateTime.parse(t['created_at'].toString());
          return tDate.difference(createdAt).inSeconds.abs() <= 1 &&
              t['transaction_type'] == tx['transaction_type'];
        }).toList();

    // 2. Prepare items with pricing
    final itemsForChallan =
        sameBatch.map((item) {
          final itemName = item['item_name'];
          final unit = item['unit'];

          // Calculate Revenue logic (similar to Dashboard)
          final product = _allProducts.firstWhere(
            (p) => p['label'] == itemName,
            orElse: () => {},
          );
          final List variants = product['variants'] ?? [];
          final variant = variants.firstWhere(
            (v) => v['label'] == unit,
            orElse: () => {},
          );

          final price =
              double.tryParse(variant['offer_price']?.toString() ?? '0') ?? 0.0;

          return {
            'name': itemName,
            'unit': unit,
            'quantity': double.tryParse(item['quantity'].toString()) ?? 0.0,
            'price': price,
          };
        }).toList();

    try {
      await PdfService.generateStockChallan(
        items: itemsForChallan,
        farmName: widget.farmName,
        farmerName: widget.farmerName ?? 'N/A',
        cropName: widget.cropName ?? 'N/A',
        transactionType: tx['transaction_type'],
        date: createdAt,
        placeOfSupply: _farmLocation,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing challan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatType(String type) {
    switch (type) {
      case 'RECEIVED':
        return 'SALES RECEIVED';
      case 'DELIVERED':
        return 'SALES DELIVERED';
      case 'RETURN':
        return 'SALES RETURN';
      default:
        return type;
    }
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr.toString());
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return dateStr.toString();
    }
  }
}
