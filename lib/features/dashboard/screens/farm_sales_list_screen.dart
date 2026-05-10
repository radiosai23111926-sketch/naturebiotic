import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:nature_biotic/features/farms/screens/stock_management_screen.dart';
import 'package:nature_biotic/features/farms/screens/add_collection_screen.dart';
import 'package:nature_biotic/features/farms/screens/collection_history_screen.dart';
import 'package:nature_biotic/features/farms/screens/add_stock_entry_screen.dart';
import 'package:intl/intl.dart';

class FarmSalesListScreen extends StatefulWidget {
  final List<Map<String, dynamic>> initialTransactions;
  final List<Map<String, dynamic>> initialCollections;
  final List<Map<String, dynamic>> allProducts;
  final List<Map<String, dynamic>> allFarms;
  final String mode; // 'SALES', 'COLLECTION', 'OUTSTANDING'

  const FarmSalesListScreen({
    super.key,
    required this.initialTransactions,
    this.initialCollections = const [],
    required this.allProducts,
    this.allFarms = const [],
    this.mode = 'SALES',
  });

  @override
  State<FarmSalesListScreen> createState() => _FarmSalesListScreenState();
}

class _FarmSalesListScreenState extends State<FarmSalesListScreen> {
  final currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );
  Map<String, Map<String, dynamic>> _farmSales = {};
  List<Map<String, dynamic>> _availableFarms = [];
  bool _isLoading = true;
  TextEditingController? _cachedSearchController;
  TextEditingController get _searchController =>
      _cachedSearchController ??= TextEditingController();

  @override
  void dispose() {
    _cachedSearchController?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _processData();
  }

  Future<void> _processData() async {
    final profile = await SupabaseService.getProfile();
    final role = profile?['role']?.toString().toLowerCase();
    final userId = SupabaseService.client.auth.currentUser?.id;

    final Map<String, Map<String, dynamic>> grouped = {};

    for (var tx in widget.initialTransactions) {
      if ((role == 'executive' || role == 'telecaller') && userId != null) {
        final txExecId = tx['executive_id']?.toString().toLowerCase();
        final currentId = userId.toLowerCase();
        final isOwner = txExecId == currentId;
        if (!isOwner) {
          continue;
        }
      }

      final type = tx['transaction_type']?.toString().toUpperCase();
      final farmId = tx['farm_id']?.toString();
      if (farmId == null) continue;

      if (!grouped.containsKey(farmId)) {
        grouped[farmId] = {
          'farm_id': farmId,
          'farm_name': 'Farm #$farmId',
          'farmer_name': 'Searching...',
          'location': '...',
          'total_revenue': 0.0,
          'total_collection': 0.0,
          'total_items': 0.0,
          'total_returned': 0.0,
          'logs': <Map<String, dynamic>>[],
          'balances': <String, Map<String, dynamic>>{},
        };
      }

      // Track individual transactions
      if (widget.mode == 'SALES' || widget.mode == 'OUTSTANDING') {
        grouped[farmId]!['logs'].add({...tx, '_source': 'transaction'});
      }

      // Calculate Revenue (for SALES and OUTSTANDING)
      if (type == 'RECEIVED' || type == 'RETURN') {
        final itemName = tx['item_name']?.toString().trim().toLowerCase();
        final rawUnit = tx['unit']?.toString().trim().toLowerCase() ?? '';
        final unit = rawUnit.split(' {₹')[0].trim();
        final qty = double.tryParse(tx['quantity']?.toString() ?? '0') ?? 0.0;

        final product = widget.allProducts.firstWhere(
          (p) => p['label']?.toString().trim().toLowerCase() == itemName,
          orElse: () => {},
        );
        final List variants = product['variants'] ?? [];
        final variant = variants.firstWhere(
          (v) => v['label']?.toString().trim().toLowerCase() == unit,
          orElse: () => {},
        );

        final price =
            double.tryParse(variant['offer_price']?.toString() ?? '0') ?? 0.0;
        final amount = price * qty;

        if (type == 'RECEIVED') {
          grouped[farmId]!['total_revenue'] += amount;
          grouped[farmId]!['total_items'] += qty;
        } else if (type == 'RETURN') {
          grouped[farmId]!['total_revenue'] -= amount;
          grouped[farmId]!['total_items'] -= qty;
          grouped[farmId]!['total_returned'] += qty;
        }

        // Accumulate individual product balances
        final Map<String, Map<String, dynamic>> bMap =
            grouped[farmId]!['balances'];
        final bKey = "$itemName ($unit)";
        if (!bMap.containsKey(bKey)) {
          bMap[bKey] = {
            'item': tx['item_name'] ?? 'Unknown',
            'unit': unit,
            'qty': 0.0,
          };
        }
        if (type == 'RECEIVED') {
          bMap[bKey]!['qty'] += qty;
        } else if (type == 'RETURN') {
          bMap[bKey]!['qty'] -= qty;
        }
      }

      // Calculate Collection (for COLLECTION and OUTSTANDING)
      if (type == 'RECEIVED') {
        double amt =
            double.tryParse(tx['collected_amount']?.toString() ?? '0') ?? 0.0;
        if (amt == 0 &&
            tx['unit'] != null &&
            tx['unit'].toString().contains('{₹')) {
          try {
            final unitStr = tx['unit'].toString();
            final start = unitStr.indexOf('{₹') + 2;
            final end = unitStr.indexOf('}', start);
            if (end != -1) {
              amt = double.tryParse(unitStr.substring(start, end)) ?? 0.0;
            }
          } catch (_) {}
        }
        grouped[farmId]!['total_collection'] += amt;
      }
    }

    // 2. Process Dedicated Collections
    for (var col in widget.initialCollections) {
      if (role != 'admin' && userId != null) {
        final creatorId = col['created_by']?.toString().toLowerCase();
        final currentId = userId.toLowerCase();
        if (creatorId != currentId) {
          continue;
        }
      }

      final farmId = col['farm_id']?.toString();
      if (farmId == null) continue;

      if (!grouped.containsKey(farmId)) {
        grouped[farmId] = {
          'farm_id': farmId,
          'farm_name': 'Farm #$farmId',
          'farmer_name': 'Searching...',
          'location': '...',
          'total_revenue': 0.0,
          'total_collection': 0.0,
          'total_items': 0.0,
          'total_returned': 0.0,
          'logs': <Map<String, dynamic>>[],
          'balances': <String, Map<String, dynamic>>{},
        };
      }

      // Track individual collections
      if (widget.mode == 'COLLECTION' || widget.mode == 'OUTSTANDING') {
        grouped[farmId]!['logs'].add({...col, '_source': 'collection'});
      }

      final amt = double.tryParse(col['amount']?.toString() ?? '0') ?? 0.0;
      grouped[farmId]!['total_collection'] += amt;
    }

    // 3. Sort internal logs by date descending for display
    for (final g in grouped.values) {
      final List<Map<String, dynamic>> logs = List<Map<String, dynamic>>.from(
        g['logs'] ?? [],
      );
      logs.sort((a, b) {
        final aStr = a['created_at']?.toString() ?? '';
        final bStr = b['created_at']?.toString() ?? '';
        return bStr.compareTo(aStr);
      });
      g['logs'] = logs;
    }

    if (mounted) {
      setState(() {
        _farmSales = grouped;
        _isLoading = false;
      });
    }

    // First try to resolve from passed allFarms
    if (widget.allFarms.isNotEmpty) {
      _availableFarms = widget.allFarms;
      _applyFarmData(widget.allFarms);
    }

    // Then fetch fresh data
    _loadFarmNames();
  }

  void _applyFarmData(List<Map<String, dynamic>> farms) {
    if (!mounted) return;
    setState(() {
      for (var farm in farms) {
        final id = farm['id'].toString();
        if (_farmSales.containsKey(id)) {
          _farmSales[id]!['farm_name'] = farm['name'] ?? 'Unknown Farm';
          _farmSales[id]!['farmer_name'] =
              farm['farmers']?['name'] ?? 'No Farmer';
          _farmSales[id]!['location'] =
              farm['place'] ?? farm['location'] ?? 'No Location';

          // Handle multi-crop relationships correctly (can be List or Map from Supabase)
          final cropData = farm['crops'];
          String resolvedCrop = 'No Crop';
          if (cropData is Map) {
            resolvedCrop = cropData['name']?.toString() ?? 'No Crop';
          } else if (cropData is List && cropData.isNotEmpty) {
            final names =
                cropData
                    .map((c) => (c is Map ? c['name']?.toString() : null))
                    .where((n) => n != null && n.isNotEmpty)
                    .toList();
            if (names.isNotEmpty) {
              resolvedCrop = names.join(', ');
            }
          }
          _farmSales[id]!['crop_name'] = resolvedCrop;
        }
      }
    });
  }

  Future<void> _loadFarmNames() async {
    try {
      final response = await SupabaseService.client
          .from('farms')
          .select('*, farmers(name), crops(name)')
          .order('created_at');
      final farms = List<Map<String, dynamic>>.from(response);
      if (mounted) {
        setState(() {
          _availableFarms = farms;
        });
      }
      _applyFarmData(farms);
    } catch (e) {
      debugPrint('Error loading farm names: $e');
      final farms = await SupabaseService.getFarms();
      _applyFarmData(farms);
    }
  }

  @override
  Widget build(BuildContext context) {
    var list = _farmSales.values.toList();

    // Filter based on mode
    if (widget.mode == 'SALES') {
      list = list.where((f) => f['total_revenue'] > 0).toList();
      list.sort(
        (a, b) => (b['total_revenue'] as double).compareTo(
          a['total_revenue'] as double,
        ),
      );
    } else if (widget.mode == 'COLLECTION') {
      list = list.where((f) => f['total_collection'] > 0).toList();
      list.sort(
        (a, b) => (b['total_collection'] as double).compareTo(
          a['total_collection'] as double,
        ),
      );
    } else if (widget.mode == 'OUTSTANDING') {
      list =
          list
              .where(
                (f) => (f['total_revenue'] - f['total_collection']).abs() > 0.1,
              )
              .toList();
      list.sort(
        (a, b) => ((b['total_revenue'] - b['total_collection']) as double)
            .compareTo((a['total_revenue'] - a['total_collection']) as double),
      );
    }

    // Apply search filter
    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      list =
          list.where((f) {
            final farmName = (f['farm_name'] ?? '').toString().toLowerCase();
            final farmerName =
                (f['farmer_name'] ?? '').toString().toLowerCase();
            final location = (f['location'] ?? '').toString().toLowerCase();
            return farmName.contains(query) ||
                farmerName.contains(query) ||
                location.contains(query);
          }).toList();
    }

    String title = 'Sales by Farm';
    if (widget.mode == 'COLLECTION') title = 'Collections by Farm';
    if (widget.mode == 'OUTSTANDING') title = 'Outstanding by Farm';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(title)),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search farm or farmer name...',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: AppColors.primary,
                          ),
                          suffixIcon:
                              _searchController.text.isNotEmpty
                                  ? IconButton(
                                    icon: const Icon(Icons.clear_rounded),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {});
                                    },
                                  )
                                  : null,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async => _processData(),
                      child:
                          list.isEmpty
                              ? _buildEmptyState()
                              : ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                itemCount: list.length,
                                itemBuilder:
                                    (context, index) =>
                                        _buildFarmCard(list[index]),
                              ),
                    ),
                  ),
                ],
              ),
      floatingActionButton:
          (widget.mode == 'COLLECTION' || widget.mode == 'SALES')
              ? FloatingActionButton.extended(
                onPressed: () => _showFarmSelectionDialog(context),
                icon: const Icon(Icons.add_rounded),
                label: Text(
                  widget.mode == 'COLLECTION' ? 'Add Collection' : 'New Sales',
                ),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              )
              : null,
    );
  }

  void _showFarmSelectionDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => _SelectionFlow(
            mode: widget.mode,
            onComplete: (farmer, farm, crop) {
              Navigator.pop(context); // close bottom sheet
              if (widget.mode == 'COLLECTION') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => AddCollectionScreen(
                          farmId: farm['id'].toString(),
                          farmName: farm['name'] ?? 'Unknown Farm',
                          farmerName: farmer['name'],
                          cropId: crop?['id']?.toString(),
                          cropName: crop?['name']?.toString(),
                        ),
                  ),
                ).then((_) => _processData());
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => AddStockEntryScreen(
                          farmId: farm['id'].toString(),
                          farmName: farm['name'] ?? 'Unknown Farm',
                          farmerName: farmer['name'],
                          cropName: crop?['name'],
                        ),
                  ),
                ).then((_) => _processData());
              }
            },
          ),
    );
  }

  Widget _buildEmptyState() {
    String message = 'No sales records found';
    if (widget.mode == 'COLLECTION') message = 'No collections found';
    if (widget.mode == 'OUTSTANDING') message = 'No outstanding balances';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.receipt_long_rounded,
            size: 64,
            color: AppColors.textGray,
          ),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: AppColors.textGray)),
        ],
      ),
    );
  }

  Widget _buildFarmCard(Map<String, dynamic> data) {
    double displayValue = 0;
    String label = '';
    Color valueColor = AppColors.primary;

    if (widget.mode == 'SALES') {
      displayValue = data['total_revenue'];
      label = 'Revenue';
    } else if (widget.mode == 'COLLECTION') {
      displayValue = data['total_collection'];
      label = 'Collected';
      valueColor = Colors.teal;
    } else if (widget.mode == 'OUTSTANDING') {
      displayValue = data['total_revenue'] - data['total_collection'];
      label = 'Outstanding';
      valueColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        elevation: 2,
        shadowColor: AppColors.shadow.withOpacity(0.1),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: valueColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      widget.mode == 'COLLECTION'
                          ? Icons.payments_rounded
                          : Icons.agriculture_rounded,
                      color: valueColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${data['farmer_name']} • ${data['farm_name']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '${data['crop_name'] ?? 'No Crop'} • ${data['location']}',
                          style: const TextStyle(
                            color: AppColors.textGray,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (widget.mode == 'SALES' ||
                                widget.mode == 'OUTSTANDING')
                              _buildMiniBadge(
                                Icons.inventory_2_outlined,
                                '${data['total_items'].toInt()} Items',
                                Colors.blueGrey,
                              ),
                            if (data['total_returned'] > 0 &&
                                widget.mode == 'SALES')
                              _buildMiniBadge(
                                Icons.replay_circle_filled_rounded,
                                '${data['total_returned'].toInt()} Returned',
                                Colors.redAccent,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        currencyFormat.format(displayValue),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: valueColor,
                        ),
                      ),
                      Text(
                        label,
                        style: const TextStyle(
                          color: AppColors.textGray,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Builder(
              builder: (context) {
                final rawMap = data['balances'];
                if (rawMap == null || rawMap is! Map) {
                  return const SizedBox.shrink();
                }
                final bMap = rawMap;
                if (bMap.isEmpty) return const SizedBox.shrink();

                final items = bMap.values.toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(height: 1, indent: 20, endIndent: 20),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            items.map((it) {
                              if (it is! Map) return const SizedBox.shrink();
                              final qty =
                                  double.tryParse(
                                    it['qty']?.toString() ?? '0',
                                  ) ??
                                  0.0;
                              if (qty.abs() < 0.01)
                                return const SizedBox.shrink();

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.primary.withOpacity(0.15),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.inventory_2_rounded,
                                      size: 12,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${it['item']} (${it['unit']}) : ',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textBlack,
                                      ),
                                    ),
                                    Text(
                                      '${qty.toInt()}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                      ),
                    ),
                  ],
                );
              },
            ),
            Builder(
              builder: (context) {
                final rawLogs = data['logs'];
                final logs = (rawLogs is List) ? rawLogs : [];
                if (logs.isEmpty) return const SizedBox.shrink();

                return Column(
                  children: [
                    const Divider(height: 1, indent: 20, endIndent: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 20,
                      ),
                      child: Column(
                        children:
                            logs
                                .map(
                                  (l) => _buildInnerLogItem(
                                    l as Map<String, dynamic>,
                                  ),
                                )
                                .toList(),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInnerLogItem(Map<String, dynamic> log) {
    final date = _formatDate(log['created_at']);
    final bool isTx = log['_source'] == 'transaction';

    if (isTx) {
      final type = log['transaction_type']?.toString().toUpperCase() ?? 'N/A';
      final bool isAdd = type == 'RECEIVED';
      final color =
          isAdd
              ? Colors.green
              : (type == 'RETURN' ? Colors.blue : Colors.orange);
      final icon =
          isAdd
              ? Icons.download_rounded
              : (type == 'RETURN'
                  ? Icons.settings_backup_restore_rounded
                  : Icons.upload_rounded);

      final qty = double.tryParse(log['quantity']?.toString() ?? '0') ?? 0.0;
      String unit = (log['unit']?.toString() ?? '').split(' {₹')[0].trim();
      final name = log['item_name'] ?? 'N/A';

      String typeLabel = 'SALES $type';
      if (type == 'RECEIVED') typeLabel = 'SALES RECEIVED';
      if (type == 'DELIVERED') typeLabel = 'SALES DELIVERED';
      if (type == 'RETURN') typeLabel = 'SALES RETURN';

      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.textBlack,
                    ),
                  ),
                  Text(
                    typeLabel,
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isAdd ? '+' : '-'}${qty.toInt()} x $unit',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: color,
                  ),
                ),
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textGray,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      final amt = double.tryParse(log['amount']?.toString() ?? '0') ?? 0.0;
      final color = Colors.teal;

      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.teal,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Collection',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.textBlack,
                    ),
                  ),
                  Text(
                    'PAYMENT RECEIVED',
                    style: TextStyle(
                      color: Colors.teal,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '+₹${amt.toInt()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.teal,
                  ),
                ),
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textGray,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
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

class _SelectionFlow extends StatefulWidget {
  final String mode;
  final Function(
    Map<String, dynamic> farmer,
    Map<String, dynamic> farm,
    Map<String, dynamic>? crop,
  )
  onComplete;

  const _SelectionFlow({required this.mode, required this.onComplete});

  @override
  State<_SelectionFlow> createState() => _SelectionFlowState();
}

class _SelectionFlowState extends State<_SelectionFlow> {
  String _step = 'FARMER'; // FARMER, FARM, CROP
  List<Map<String, dynamic>> _farmers = [];
  List<Map<String, dynamic>> _farms = [];
  List<Map<String, dynamic>> _crops = [];

  Map<String, dynamic>? _selectedFarmer;
  Map<String, dynamic>? _selectedFarm;
  bool _isLoading = true;
  TextEditingController? _cachedSearchController;
  TextEditingController get _searchController =>
      _cachedSearchController ??= TextEditingController();

  @override
  void dispose() {
    _cachedSearchController?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadFarmers();
  }

  Future<void> _loadFarmers() async {
    final farmers = await SupabaseService.getFarmers();
    if (mounted) {
      setState(() {
        _farmers = farmers;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadFarms(dynamic farmerId) async {
    setState(() => _isLoading = true);
    final farms = await SupabaseService.getFarmsByFarmer(farmerId);
    if (mounted) {
      setState(() {
        _searchController.clear();
        _farms = farms;
        _step = 'FARM';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCrops(dynamic farmId) async {
    setState(() => _isLoading = true);
    final crops = await SupabaseService.getCrops(farmId);
    if (mounted) {
      setState(() {
        _searchController.clear();
        _crops = crops;
        _step = 'CROP';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String title = 'Select Farmer';
    if (_step == 'FARM') title = 'Select Farm';
    if (_step == 'CROP') title = 'Select Crop';

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                if (_step != 'FARMER')
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                    ),
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                        if (_step == 'CROP') {
                          _step = 'FARM';
                        } else if (_step == 'FARM')
                          _step = 'FARMER';
                      });
                    },
                  ),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textBlack,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.primary,
                    ),
                    suffixIcon:
                        _searchController.text.isNotEmpty
                            ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                            : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildList() {
    final query = _searchController.text.toLowerCase();

    if (_step == 'FARMER') {
      final filtered =
          query.isEmpty
              ? _farmers
              : _farmers.where((f) {
                final n = (f['name'] ?? '').toString().toLowerCase();
                final p = (f['phone'] ?? '').toString().toLowerCase();
                return n.contains(query) || p.contains(query);
              }).toList();

      return ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final f = filtered[index];
          return _selectionTile(
            title: f['name'] ?? 'Unknown',
            subtitle: f['phone'] ?? 'No Phone',
            icon: Icons.person_rounded,
            onTap: () {
              setState(() {
                _selectedFarmer = f;
              });
              _loadFarms(f['id']);
            },
          );
        },
      );
    } else if (_step == 'FARM') {
      final filtered =
          query.isEmpty
              ? _farms
              : _farms.where((f) {
                final n = (f['name'] ?? '').toString().toLowerCase();
                final l = (f['location'] ?? '').toString().toLowerCase();
                return n.contains(query) || l.contains(query);
              }).toList();

      return ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final farm = filtered[index];
          return _selectionTile(
            title: farm['name'] ?? 'Unknown Farm',
            subtitle: farm['place'] ?? farm['location'] ?? 'No Location',
            icon: Icons.agriculture_rounded,
            onTap: () {
              setState(() {
                _selectedFarm = farm;
              });
              _loadCrops(farm['id']);
            },
          );
        },
      );
    } else {
      final filtered =
          query.isEmpty
              ? _crops
              : _crops.where((c) {
                final n = (c['name'] ?? '').toString().toLowerCase();
                return n.contains(query);
              }).toList();

      return ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final crop = filtered[index];
          return _selectionTile(
            title: crop['name'] ?? 'Unknown Crop',
            subtitle: '${crop['area'] ?? '-'} ${crop['area_unit'] ?? ''}',
            icon: Icons.eco_rounded,
            onTap:
                () => widget.onComplete(_selectedFarmer!, _selectedFarm!, crop),
          );
        },
      );
    }
  }

  Widget _selectionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: AppColors.textGray, fontSize: 13),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
