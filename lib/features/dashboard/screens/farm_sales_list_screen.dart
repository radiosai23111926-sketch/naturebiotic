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

  @override
  void initState() {
    super.initState();
    _processData();
  }

  void _processData() {
    final Map<String, Map<String, dynamic>> grouped = {};

    for (var tx in widget.initialTransactions) {
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
        };
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
        };
      }

      final amt = double.tryParse(col['amount']?.toString() ?? '0') ?? 0.0;
      grouped[farmId]!['total_collection'] += amt;
    }

    setState(() {
      _farmSales = grouped;
      _isLoading = false;
    });

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
          _farmSales[id]!['location'] = farm['location'] ?? 'No Location';
          _farmSales[id]!['crop_name'] = farm['crops']?['name'] ?? 'No Crop';
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

    String title = 'Sales by Farm';
    if (widget.mode == 'COLLECTION') title = 'Collections by Farm';
    if (widget.mode == 'OUTSTANDING') title = 'Outstanding by Farm';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(title)),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: () async => _processData(),
                child:
                    list.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: list.length,
                          itemBuilder:
                              (context, index) => _buildFarmCard(list[index]),
                        ),
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
        child: InkWell(
          onTap: () {
            if (widget.mode == 'COLLECTION') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => CollectionHistoryScreen(
                        farmId: data['farm_id'],
                        farmName: data['farm_name'],
                        farmerName: data['farmer_name'],
                      ),
                ),
              ).then((_) => _processData());
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => StockManagementScreen(
                        farmId: data['farm_id'],
                        farmName: data['farm_name'],
                        farmerName: data['farmer_name'],
                        cropName: data['crop_name'],
                      ),
                ),
              ).then((_) => _processData());
            }
          },
          borderRadius: BorderRadius.circular(24),
          child: Padding(
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
                          _buildMiniBadge(
                            Icons.description_outlined,
                            'View Details',
                            valueColor,
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
                        if (_step == 'CROP')
                          _step = 'FARM';
                        else if (_step == 'FARM')
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
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_step == 'FARMER') {
      return ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _farmers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final f = _farmers[index];
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
      return ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _farms.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final farm = _farms[index];
          return _selectionTile(
            title: farm['name'] ?? 'Unknown Farm',
            subtitle: farm['location'] ?? 'No Location',
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
      return ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _crops.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final crop = _crops[index];
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
