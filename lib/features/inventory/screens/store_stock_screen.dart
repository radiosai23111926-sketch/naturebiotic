import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/core/widgets/animations.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:nature_biotic/features/inventory/screens/stock_transaction_form.dart';
import 'package:nature_biotic/features/inventory/screens/executive_stock_acceptance_screen.dart';
import 'package:nature_biotic/features/inventory/screens/executive_stock_detail_screen.dart';
import 'package:nature_biotic/features/inventory/screens/store_stock_return_acceptance_screen.dart';

class StoreStockScreen extends StatefulWidget {
  const StoreStockScreen({super.key});

  @override
  State<StoreStockScreen> createState() => _StoreStockScreenState();
}

class _StoreStockScreenState extends State<StoreStockScreen> {
  bool _isLoading = true;
  int _pendingCount = 0;
  int _rejectedCount = 0;
  List<Map<String, dynamic>> _rejectedTransactions = [];
  Map<String, double> _stockInHand = {};
  Map<String, Map<String, double>> _detailedStock = {};
  Map<String, Map<String, double>> _pendingDetailedStock = {};
  String _userRole = 'executive';
  String _userName = 'User';
  List<Map<String, dynamic>> _usageHistory = [];
  List<Map<String, dynamic>> _allTransactions = [];
  List<Map<String, dynamic>> _staffMembers = [];
  Map<String, double> _staffStockTotals = {};
  List<Map<String, dynamic>> _productOptions = [];

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    try {
      final initResults = await Future.wait([
        SupabaseService.getProfile(),
        SupabaseService.getHierarchicalDropdownOptions('product_name'),
      ]);
      final profile = initResults[0] as Map<String, dynamic>?;
      _productOptions = initResults[1] as List<Map<String, dynamic>>;
      _userRole = profile?['role'] ?? 'executive';
      _userName = profile?['full_name'] ?? 'User';

      if (_userRole == 'executive' || _userRole == 'telecaller') {
        final results = await Future.wait([
          SupabaseService.getExecutiveStock(),
          SupabaseService.getDetailedExecutiveStock(),
          SupabaseService.getExecutiveStockUsage(),
          SupabaseService.getPendingStoreTransactions(),
          SupabaseService.getExecutiveTransactions(SupabaseService.client.auth.currentUser!.id),
          SupabaseService.getPendingDetailedStock(),
        ]);

        final stock = results[0] as Map<String, double>;
        final detailed = results[1] as Map<String, Map<String, double>>;
        final usage = results[2] as List<Map<String, dynamic>>;
        final pending = results[3] as List<Map<String, dynamic>>;
        final transactions = results[4] as List<Map<String, dynamic>>;
        final pendingDetailed = results[5] as Map<String, Map<String, double>>;

        if (mounted) {
          setState(() {
            _stockInHand = stock;
            _detailedStock = detailed;
            _pendingDetailedStock = pendingDetailed;
            _usageHistory = usage;
            _allTransactions = transactions;
            _pendingCount = pending.length;
            _isLoading = false;
          });
        }
      } else {
        final results = await Future.wait([
          SupabaseService.getPendingStoreTransactions(),
          SupabaseService.getRejectedStoreTransactions(),
          SupabaseService.getUnifiedStoreStock(),
          SupabaseService.getDetailedStoreStock(),
          SupabaseService.getStoreTransactions(),
          SupabaseService.getAllStockTransactions(),
        ]);

        final pending = results[0] as List<Map<String, dynamic>>;
        final rejected = results[1] as List<Map<String, dynamic>>;
        final stock = results[2] as Map<String, double>;
        final detailed = results[3] as Map<String, Map<String, double>>;
        final storeTxs = results[4] as List<Map<String, dynamic>>;
        final fieldTxs = results[5] as List<Map<String, dynamic>>;

        // Tag them to distinguish in UI
        final List<Map<String, dynamic>> combinedTxs = [];
        for (var tx in storeTxs) {
          combinedTxs.add({...tx, '_source': 'store'});
        }
        for (var tx in fieldTxs) {
          combinedTxs.add({...tx, '_source': 'field'});
        }

        // Sort by date descending
        combinedTxs.sort((a, b) {
          final dateA = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          final dateB = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          return dateB.compareTo(dateA);
        });

        List<Map<String, dynamic>> staff = [];
        Map<String, double> staffStockTotals = {};

        if (_userRole == 'admin' || _userRole == 'store') {
          staff = await SupabaseService.getAllStaff();
          // Pre-calculate stock totals for each staff member concurrently using Future.wait
          final staffFutures = staff.map((member) async {
            final staffStock = await SupabaseService.getExecutiveStock(
              userId: member['id'],
            );
            double total = 0;
            staffStock.forEach((key, value) => total += value);
            return MapEntry(member['id'].toString(), total);
          });
          final staffResults = await Future.wait(staffFutures);
          for (var entry in staffResults) {
            staffStockTotals[entry.key] = entry.value;
          }
        }

        if (mounted) {
          setState(() {
            _pendingCount = pending.length;
            _rejectedCount = rejected.length;
            _rejectedTransactions = rejected;
            _stockInHand = stock;
            _detailedStock = detailed;
            _allTransactions = combinedTxs;
            _staffMembers = staff;
            _staffStockTotals = staffStockTotals;
            _isLoading = false;
          });
        }
      }
      
      // Safety fallback to ensure loading stops
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && _isLoading) {
          setState(() => _isLoading = false);
        }
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  List<MapEntry<String, double>> _getLowStockItems() {
    return _stockInHand.entries.where((e) => (e.value ?? 0.0) < 10).toList();
  }

  void _openTransactionForm(String type) {
    if (type == 'RETURN') {
      if (_userRole == 'executive' || _userRole == 'telecaller' || _userRole == 'data_entry') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StockTransactionForm(transactionType: type),
          ),
        ).then((_) => _refreshData());
      } else {
        // Store Manager and Admin see the Acceptance/Approval list
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const StoreStockReturnAcceptanceScreen(),
          ),
        ).then((_) => _refreshData());
      }
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StockTransactionForm(transactionType: type),
        ),
      ).then((_) => _refreshData());
    }
  }

  void _openAcceptanceScreen() {
    if (_userRole == 'executive' || _userRole == 'telecaller') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ExecutiveStockAcceptanceScreen(),
        ),
      ).then((_) => _refreshData());
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const StoreStockReturnAcceptanceScreen(),
        ),
      ).then((_) => _refreshData());
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final bool isWide = width > 1100;
    final lowStock = _getLowStockItems();

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Wide Layout for Admin/Store
    if (isWide && (_userRole == 'admin' || _userRole == 'store')) {
      return DefaultTabController(
        length: 3,
        child: Scaffold(
          backgroundColor: const Color(0xFFF8F9FA), // Light gray background
          body: Column(
            children: [
              // New Premium Admin Header
              _buildModernAdminHeader(),
              
              // Navigation Bar
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Row(
                  children: [
                    Expanded(
                      child: TabBar(
                        isScrollable: true,
                        labelColor: AppColors.primary,
                        unselectedLabelColor: Colors.grey[400],
                        indicatorColor: AppColors.primary,
                        indicatorWeight: 4,
                        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        tabs: const [
                          Tab(text: 'Store Stock'),
                          Tab(text: 'History'),
                          Tab(text: 'Staff Status'),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _refreshData,
                      icon: const Icon(Icons.refresh_rounded),
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              
              // Tab Content
              Expanded(
                child: TabBarView(
                  children: [
                    _buildWideStoreStockTab(lowStock),
                    _buildHistoryTab(),
                    if (_userRole != 'executive') _buildStaffStockTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Default Layout (Mobile or Executive)
    final bool isStaff = _userRole == 'executive' || _userRole == 'telecaller';
    return DefaultTabController(
      length: isStaff ? 2 : 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: (_userRole == 'executive' || _userRole == 'telecaller') 
            ? AppBar(
                title: const Text('My Inventory'),
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 0,
                actions: [IconButton(onPressed: _refreshData, icon: const Icon(Icons.refresh_rounded))],
              )
            : null,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            if (_userRole != 'executive' && _userRole != 'telecaller') _buildHero(),
            SliverToBoxAdapter(
              child: TabBar(
                isScrollable: false,
                labelColor: AppColors.primary,
                tabs: [
                  const Tab(text: 'Stock'), 
                  const Tab(text: 'History'), 
                  if (!isStaff) const Tab(text: 'Staff')
                ],
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _buildStoreStockTab(lowStock),
              _buildHistoryTab(),
              if (!isStaff) _buildStaffStockTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernAdminHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(40, 70, 40, 40),
      decoration: const BoxDecoration(
        color: Color(0xFF0D330F), // Sleek Solid Deep Green for professional look
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'STORE MANAGEMENT',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 4,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    _userName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Managing inventory for Nature Biotic Store',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 12),
                Text(
                  DateTime.now().toString().split(' ')[0],
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideStoreStockTab(List<MapEntry<String, double>> lowStock) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildStatTile(
                'Total Items',
                _stockInHand.length.toString(),
                Icons.inventory_2_rounded,
                AppColors.primary,
              ),
              const SizedBox(width: 24),
              _buildStatTile(
                'Low Stock',
                lowStock.length.toString(),
                Icons.warning_amber_rounded,
                Colors.orange,
              ),
              const SizedBox(width: 24),
              _buildStatTile(
                'Pending Tasks',
                _pendingCount.toString(),
                Icons.pending_actions_rounded,
                Colors.blue,
              ),
            ],
          ),
          if (_pendingCount > 0) ...[
            const SizedBox(height: 24),
            _buildPendingAlert(),
          ],
          if (_rejectedCount > 0) ...[
            const SizedBox(height: 24),
            _buildRejectedAlert(),
          ],
          const SizedBox(height: 48),
          Text(
            'Quick Actions',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textBlack,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildActionTile(
                'Purchase Stock',
                'Add new inventory to the store',
                Icons.add_shopping_cart_rounded,
                Colors.blue,
                () => _openTransactionForm('PURCHASE'),
              ),
              const SizedBox(width: 24),
              _buildActionTile(
                'Deliver Stock',
                'Assign stock to field executives',
                Icons.local_shipping_rounded,
                Colors.orange,
                () => _openTransactionForm('DELIVERY'),
              ),
              const SizedBox(width: 24),
              _buildActionTile(
                'Return Stock',
                'Process stock returns to store',
                Icons.keyboard_return_rounded,
                Colors.purple,
                () => _openTransactionForm('RETURN'),
              ),
            ],
          ),
          const SizedBox(height: 48),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Store Inventory',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textBlack,
                ),
              ),
              Text(
                'Showing ${_stockInHand.length} items',
                style: const TextStyle(color: AppColors.textGray),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_stockInHand.isEmpty)
            const Center(child: Text('No stock recorded yet.'))
          else
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _stockInHand.length,
                  itemBuilder: (context, index) {
                    final productName = _detailedStock.keys.elementAt(index);
                    final variants = _detailedStock[productName]!;
                    return _buildWideInventoryListItem(productName, variants);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatTile(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: AppColors.textGray.withOpacity(0.6),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                Icon(icon, color: color, size: 16),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.textBlack,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.15), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textBlack,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  color: AppColors.textGray.withOpacity(0.6),
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWideInventoryListItem(String name, Map<String, double> variants) {
    double totalQty = 0;
    variants.forEach((_, q) {
      if (q > 0) totalQty += q;
    });
    
    final isLow = totalQty < 10;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          (() {
            final prod = _productOptions.firstWhere(
              (p) => p['label']?.toString().trim().toLowerCase() == name.trim().toLowerCase(),
              orElse: () => {},
            );
            final imgUrl = prod['image_url']?.toString();
            final hasImg = imgUrl != null && imgUrl.isNotEmpty && imgUrl != 'null';
            return CircleAvatar(
              radius: 24,
              backgroundColor: isLow ? Colors.red.withOpacity(0.05) : AppColors.background,
              backgroundImage: hasImg ? NetworkImage(imgUrl) : null,
              child: hasImg
                  ? null
                  : Icon(
                      isLow ? Icons.error_outline_rounded : Icons.inventory_2_outlined,
                      color: isLow ? Colors.red : AppColors.primary.withOpacity(0.6),
                      size: 24,
                    ),
            );
          })(),
          const SizedBox(width: 24),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: AppColors.textBlack,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isLow ? 'RESTOCK SOON' : 'STABLE STOCK',
                  style: TextStyle(
                    color: isLow ? Colors.red : AppColors.primary.withOpacity(0.6),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 5,
            child: Wrap(
              spacing: 32,
              runSpacing: 12,
              children: variants.entries.map((v) {
                final displayQty = v.value > 0 ? v.value : 0.0;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v.key,
                      style: TextStyle(
                        color: AppColors.textGray.withOpacity(0.6),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      displayQty.toStringAsFixed(0),
                      style: const TextStyle(
                        color: AppColors.textBlack,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(width: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    totalQty.toStringAsFixed(0),
                    style: TextStyle(
                      color: isLow ? Colors.red : AppColors.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 32,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'PCS',
                    style: TextStyle(
                      color: AppColors.textGray.withOpacity(0.3),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                'TOTAL QUANTITY',
                style: TextStyle(
                  color: AppColors.textGray.withOpacity(0.4),
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildStoreStockTab(List<MapEntry<String, double>> lowStock) {
    if (_userRole == 'executive' || _userRole == 'telecaller') {
      return _buildHifiExecutiveStockView(lowStock);
    }
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: CustomScrollView(
        slivers: [
          if (_pendingCount > 0)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: _buildPendingAlert(),
              ),
            ),
          if (_rejectedCount > 0)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: _buildRejectedAlert(),
              ),
            ),
          if (lowStock.isNotEmpty)
            SliverToBoxAdapter(child: _buildLowStockAlerts(lowStock)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quick Actions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _compactActionCard(
                        'Purchase',
                        Icons.add_shopping_cart_rounded,
                        Colors.blue,
                        () => _openTransactionForm('PURCHASE'),
                      ),
                      const SizedBox(width: 16),
                      _compactActionCard(
                        'Delivery',
                        Icons.local_shipping_rounded,
                        Colors.orange,
                        () => _openTransactionForm('DELIVERY'),
                      ),
                      const SizedBox(width: 16),
                      _compactActionCard(
                        'Return',
                        Icons.keyboard_return_rounded,
                        Colors.purple,
                        () => _openTransactionForm('RETURN'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Stock in Store',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${_stockInHand.length ?? 0} Items',
                    style: const TextStyle(
                      color: AppColors.textGray,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildInventoryList(),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildHifiExecutiveStockView(List<MapEntry<String, double>> lowStock) {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: CustomScrollView(
        slivers: [
          // Pending Handover Alert
          if (_pendingCount > 0)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: _buildPendingAlert(),
              ),
            ),

          // Quick Actions Grid
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'STOCK ACTIONS',
                    style: TextStyle(
                      color: AppColors.textGray.withOpacity(0.5),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _hifiActionTile(
                        'Request',
                        'Need product',
                        Icons.add_shopping_cart_rounded,
                        Colors.blue,
                        () => _openTransactionForm('REQUEST'),
                      ),
                      const SizedBox(width: 12),
                      _hifiActionTile(
                        'Accept Stock',
                        'Verify incoming',
                        Icons.verified_user_rounded,
                        Colors.green,
                        _openAcceptanceScreen,
                        badgeCount: _pendingCount,
                      ),
                      const SizedBox(width: 12),
                      _hifiActionTile(
                        'Return Stock',
                        'Send back',
                        Icons.keyboard_return_rounded,
                        Colors.purple,
                        () => _openTransactionForm('RETURN'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Inventory List
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'CURRENT INVENTORY',
                    style: TextStyle(
                      color: AppColors.textGray.withOpacity(0.5),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    '${_stockInHand.length} ITEMS',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          _buildHifiInventoryList(),
          
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _hifiActionTile(String title, String sub, IconData icon, Color color, VoidCallback onTap, {int badgeCount = 0}) {
    return Expanded(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withOpacity(0.08),
                  color.withOpacity(0.02),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: color.withOpacity(0.1)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(icon, color: color, size: 28),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textBlack,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sub,
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textGray.withOpacity(0.6),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (badgeCount > 0)
            Positioned(
              top: -8,
              right: -8,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  badgeCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHifiLowStockSection(List<MapEntry<String, double>> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            'RESTOCK REQUIRED',
            style: TextStyle(
              color: Colors.red.withOpacity(0.7),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Container(
                width: 140,
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.key,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.value.toStringAsFixed(0)} left',
                      style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHifiInventoryList() {
    if (_stockInHand.isEmpty && _pendingDetailedStock.isEmpty) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: Text('No stock items in hand'),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          mainAxisExtent: 220, // Taller cards for more details
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          // Combine keys from both detailed and pending stock
          final allProductNames = {..._detailedStock.keys, ..._pendingDetailedStock.keys}.toList();
          final productName = allProductNames[index];
          
          final variants = _detailedStock[productName] ?? {};
          final pendingVariants = _pendingDetailedStock[productName] ?? {};
          
          double totalQty = 0;
          variants.forEach((_, q) {
            if (q > 0) totalQty += q;
          });

          double totalPending = 0;
          pendingVariants.forEach((_, q) => totalPending += q);
          
          final isLow = totalQty < 10;
          final color = isLow ? Colors.red : AppColors.primary;

          return EntranceAnimation(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: color.withOpacity(0.05)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    // Subtle background icon
                    Positioned(
                      right: -10,
                      bottom: -10,
                      child: Icon(
                        Icons.inventory_2_outlined,
                        size: 80,
                        color: color.withOpacity(0.03),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              (() {
                                final prod = _productOptions.firstWhere(
                                  (p) => p['label']?.toString().trim().toLowerCase() == productName.trim().toLowerCase(),
                                  orElse: () => {},
                                );
                                final imgUrl = prod['image_url']?.toString();
                                final hasImg = imgUrl != null && imgUrl.isNotEmpty && imgUrl != 'null';
                                return CircleAvatar(
                                  radius: 18,
                                  backgroundColor: color.withOpacity(0.1),
                                  backgroundImage: hasImg ? NetworkImage(imgUrl) : null,
                                  child: hasImg
                                      ? null
                                      : Icon(
                                          isLow ? Icons.error_outline_rounded : Icons.inventory_2_outlined,
                                          color: color,
                                          size: 18,
                                        ),
                                );
                              })(),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      productName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                        color: AppColors.textBlack,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isLow ? 'RESTOCK SOON' : 'STABLE STOCK',
                                        style: TextStyle(
                                          color: color,
                                          fontSize: 7,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    totalQty.toStringAsFixed(0),
                                    style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (totalPending > 0) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.orange.withOpacity(0.2)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.pending_actions_rounded, color: Colors.orange, size: 12),
                                    const SizedBox(width: 6),
                                    Text(
                                      '+${totalPending.toStringAsFixed(0)} PENDING',
                                      style: const TextStyle(
                                        color: Colors.orange,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const Spacer(),
                          Text(
                            'BREAKDOWN',
                            style: TextStyle(
                              color: AppColors.textGray.withOpacity(0.4),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: variants.entries.map((v) {
                              final displayQty = v.value > 0 ? v.value : 0.0;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    v.key,
                                    style: TextStyle(
                                      color: AppColors.textGray.withOpacity(0.5),
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    displayQty.toStringAsFixed(0),
                                    style: const TextStyle(
                                      color: AppColors.textBlack,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }, childCount: _detailedStock.length),
      ),
    );
  }

  Widget _buildHistoryTab() {
    final bool isWide = MediaQuery.of(context).size.width > 900;

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isWide ? 1100 : double.infinity),
              child: TabBar(
                labelColor: AppColors.primary,
                unselectedLabelColor: Colors.grey[400],
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                tabs: const [
                  Tab(text: 'Purchases'),
                  Tab(text: 'Deliveries'),
                  Tab(text: 'Returns'),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildFilteredHistoryTab('PURCHASE'),
                _buildFilteredHistoryTab('DELIVERY'),
                _buildFilteredHistoryTab('RETURN'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilteredHistoryTab(String type) {
    final transactions = _allTransactions ?? [];
    final bool isWide = MediaQuery.of(context).size.width > 900;
    
    final filtered = transactions.where((tx) {
      final txType = tx['transaction_type']?.toString().toUpperCase() ?? '';
      return txType == type;
    }).toList();

    Widget content = filtered.isEmpty 
        ? Center(child: Text('No $type history found'))
        : ListView.builder(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 0 : 16,
              vertical: 16
            ),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final tx = filtered[index];
              return _buildTransactionHistoryCard(tx);
            },
          );

    if (isWide) {
      content = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: content,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: content,
    );
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  Widget _buildStaffStockTab() {
    final bool isWide = MediaQuery.of(context).size.width > 900;
    
    Widget content = _staffMembers.isEmpty
        ? const Center(child: Text('No staff members found'))
        : ListView.builder(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 0 : 16,
              vertical: 16
            ),
            itemCount: _staffMembers.length,
            itemBuilder: (context, index) {
              final member = _staffMembers[index];
              final totalStock = _staffStockTotals[member['id']] ?? 0.0;
              final role = member['role']?.toString().toUpperCase() ?? 'STAFF';

              return EntranceAnimation(
                child: Card(
                  margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                      color: Colors.white,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          child: Text(
                            member['full_name']?[0] ?? 'S',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          member['full_name'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(role, style: TextStyle(color: AppColors.primary.withOpacity(0.6), fontSize: 10, fontWeight: FontWeight.bold)),
                            Text('Total Units in Hand: $totalStock'),
                          ],
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.primary,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => ExecutiveStockDetailScreen(
                                    executiveId: member['id'],
                                    executiveName: member['full_name'],
                                  ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              );

    if (isWide) {
      content = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: content,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: content,
    );
  }

  Widget _buildTransactionHistoryCard(Map<String, dynamic> tx) {
    final date =
        DateTime.tryParse(tx['created_at']?.toString() ?? '') ?? DateTime.now();
    final type = tx['transaction_type']?.toString().toUpperCase() ?? '';
    final isField = tx['_source'] == 'field';
    
    // Determine the "Farm" or "Entity" name
    String entityName = 'Internal';
    if (isField) {
      entityName = tx['farms']?['name'] ?? 'Unknown Farm';
    } else {
      if (type == 'PURCHASE') {
        entityName = tx['vendor_name'] ?? 'Vendor';
      } else if (type == 'DELIVERY' || type == 'RETURN') {
        // Handle Direct Sales (where executive_id is null)
        final profileName = tx['profiles']?['full_name'];
        if (profileName != null) {
          entityName = profileName;
        } else if (tx['vendor_name'] != null) {
          entityName = tx['vendor_name']; // For Direct Sales, this is the buyer name
        } else {
          entityName = 'Direct Sale';
        }
      }
    }

    final bool isAddition = type == 'PURCHASE' || (isField && type == 'RETURN') || (!isField && type == 'RETURN');
    // Note: This logic depends on perspective. For Admin, PURCHASE and RETURN are additions to stock.
    // DELIVERY is subtraction.
    
    final Color color = type == 'PURCHASE' ? Colors.blue : (type == 'DELIVERY' ? Colors.orange : Colors.green);
    final IconData icon = type == 'PURCHASE' ? Icons.shopping_bag_rounded : (type == 'DELIVERY' ? Icons.local_shipping_rounded : Icons.keyboard_return_rounded);

    return EntranceAnimation(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            (() {
              final itemName = tx['item_name']?.toString().trim().toLowerCase();
              final prod = _productOptions.firstWhere(
                (p) => p['label']?.toString().trim().toLowerCase() == itemName,
                orElse: () => {},
              );
              final imgUrl = prod['image_url']?.toString();
              final hasImg = imgUrl != null && imgUrl.isNotEmpty && imgUrl != 'null';
              return CircleAvatar(
                radius: 20,
                backgroundColor: color.withOpacity(0.1),
                backgroundImage: hasImg ? NetworkImage(imgUrl) : null,
                child: hasImg
                    ? null
                    : Icon(icon, color: color, size: 20),
              );
            })(),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        color: AppColors.textBlack,
                      ),
                      children: [
                        TextSpan(
                          text: tx['item_name'] ?? 'Unknown',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textBlack,
                          ),
                        ),
                        const TextSpan(text: '  '),
                        TextSpan(
                          text: '(${tx['unit']?.toString().split(' {₹')[0] ?? 'Units'})',
                          style: TextStyle(
                            color: AppColors.textGray.withOpacity(0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isField ? 'FIELD' : 'STORE',
                          style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppColors.textGray),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entityName,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      color: AppColors.textGray,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (tx['status'] != null && tx['status'] != 'ACCEPTED') ...[
                  Text(
                    tx['status'].toString().replaceAll('_ACKNOWLEDGED', ''),
                    style: TextStyle(
                      color: tx['status'].toString().contains('REJECTED') ? Colors.red : Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: ((type == 'DELIVERY' || (isField && type == 'RECEIVED')) ? Colors.orange : Colors.green).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: ((type == 'DELIVERY' || (isField && type == 'RECEIVED')) ? Colors.orange : Colors.green).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${(type == 'DELIVERY' || (isField && type == 'RECEIVED')) ? '-' : '+'}${tx['quantity']}',
                    style: TextStyle(
                      color: (type == 'DELIVERY' || (isField && type == 'RECEIVED')) ? Colors.orange : Colors.green,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
               ],
            ),
            if (tx['status'] == 'REJECTED' || tx['status'] == 'REJECTED_ACKNOWLEDGED') ...[
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StockTransactionForm(
                        transactionType: 'DELIVERY',
                        initialData: tx,
                      ),
                    ),
                  ).then((_) => _refreshData());
                },
                icon: const Icon(Icons.edit_note_rounded, color: Colors.blue),
                tooltip: 'Edit Rejected Delivery',
              ),
            ],
            if (_userRole == 'admin') ...[
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                onSelected: (val) {
                  if (val == 'delete') _deleteTransaction(tx);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
                        SizedBox(width: 12),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                icon: const Icon(Icons.more_vert_rounded, color: AppColors.textGray),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _deleteTransaction(Map<String, dynamic> tx) async {
    final isField = tx['_source'] == 'field';
    final tableName = isField ? 'stock_transactions' : 'store_transactions';
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: const Text('Are you sure you want to delete this transaction? This will permanently affect stock calculations.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await SupabaseService.deleteRecord(tableName, tx['id']);
        _refreshData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transaction deleted successfully'), backgroundColor: AppColors.primary),
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

  Widget _buildHero() {
    return SliverAppBar(
      expandedHeight: 200,
      backgroundColor: AppColors.primary,
      floating: false,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
                AppColors.primary.withOpacity(0.8),
                AppColors.primary.withOpacity(0.6),
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                bottom: -20,
                child: Icon(
                  Icons.inventory_2_rounded,
                  size: 180,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_getGreeting()},',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      (_userName.isEmpty ?? true)
                          ? 'User'
                          : _userName.split(' ')[0],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_userRole != 'executive') ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _heroStat(
                            'Total Stock',
                            (_stockInHand.length ?? 0).toString(),
                          ),
                          const SizedBox(width: 24),
                          _heroStat(
                            'Low Stock',
                            _getLowStockItems().length.toString(),
                          ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _heroStat(
                            'STOCK IN HAND',
                            _stockInHand.length.toString(),
                          ),
                          const SizedBox(width: 32),
                          _heroStat(
                            'UNITS HELD',
                            _stockInHand.values.fold(0.0, (sum, val) => sum + val).toStringAsFixed(0),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
          onPressed: _refreshData,
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
        ),
      ],
    );
  }

  Widget _heroStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildLowStockAlerts(List<MapEntry<String, double>> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: Text(
            'Low Stock Alerts',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Container(
                width: 160,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.key,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.value} units left',
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _compactActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryList() {
    if (_stockInHand.isEmpty) {
      return const SliverFillRemaining(
        child: Center(child: Text('No stock recorded yet.')),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final productName = _detailedStock.keys.elementAt(index);
          final variants = _detailedStock[productName]!;
          
          double totalQty = 0;
          variants.forEach((_, q) {
            if (q > 0) totalQty += q;
          });
          
          final isLow = totalQty < 10;

          return EntranceAnimation(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                ],
                border: Border.all(color: Colors.black.withOpacity(0.03)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isLow ? Colors.red.withOpacity(0.1) : AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isLow ? Icons.warning_amber_rounded : Icons.inventory_2_outlined,
                            color: isLow ? Colors.red : AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                productName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                isLow ? 'LOW STOCK' : 'AVAILABLE STOCK',
                                style: TextStyle(
                                  color: isLow ? Colors.red : AppColors.textGray.withOpacity(0.5),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          totalQty.toStringAsFixed(0),
                          style: TextStyle(
                            color: isLow ? Colors.red : AppColors.primary,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'PCS',
                          style: TextStyle(
                            color: AppColors.textGray.withOpacity(0.3),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 20,
                      runSpacing: 12,
                      children: variants.entries.map((v) {
                        final displayQty = v.value > 0 ? v.value : 0.0;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              v.key,
                              style: TextStyle(
                                color: AppColors.textGray.withOpacity(0.6),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              displayQty.toStringAsFixed(0),
                              style: const TextStyle(
                                color: AppColors.textBlack,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          );
        }, childCount: _detailedStock.length),
      ),
    );
  }

  Widget _buildPendingAlert() {
    return EntranceAnimation(
      child: GestureDetector(
        onTap: _openAcceptanceScreen,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.notification_important_rounded,
                color: Colors.red,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_pendingCount Pending Handovers',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const Text(
                      'You have stock pending handover or waiting for acceptance.',
                      style: TextStyle(fontSize: 12, color: Colors.redAccent),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.red),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRejectedAlert() {
    return Column(
      children: _rejectedTransactions.map((tx) {
        return EntranceAnimation(
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_rounded,
                  color: Colors.deepOrange,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Delivery Rejected',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange,
                        ),
                      ),
                      Text(
                        '${tx['profiles']?['full_name'] ?? 'Executive'} rejected ${tx['quantity']} x ${tx['unit']} of ${tx['item_name']}.',
                        style: const TextStyle(fontSize: 12, color: Colors.deepOrange),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      await SupabaseService.acknowledgeRejectedTransaction(tx['id'].toString());
                      _refreshData();
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text('OK'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StockTransactionForm(
                          transactionType: 'DELIVERY',
                          initialData: tx,
                        ),
                      ),
                    ).then((_) => _refreshData());
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.deepOrange,
                    side: const BorderSide(color: Colors.deepOrange),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text('Edit'),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _actionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return EntranceAnimation(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textGray.withOpacity(0.7),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInventorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Stock in Hand',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Showing verified available items in store.',
                  style: TextStyle(color: AppColors.textGray),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child:
                      (_stockInHand.isEmpty)
                          ? const Center(child: Text('No stock recorded yet.'))
                          : ListView.builder(
                            itemCount: _stockInHand.length,
                            itemBuilder: (context, index) {
                              final key = _stockInHand.keys.elementAt(index);
                              final qty = _stockInHand[key];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    (() {
                                      final prod = _productOptions.firstWhere(
                                        (p) => p['label']?.toString().trim().toLowerCase() == key.trim().toLowerCase(),
                                        orElse: () => {},
                                      );
                                      final imgUrl = prod['image_url']?.toString();
                                      final hasImg = imgUrl != null && imgUrl.isNotEmpty && imgUrl != 'null';
                                      return CircleAvatar(
                                        radius: 16,
                                        backgroundColor: AppColors.secondary.withOpacity(0.5),
                                        backgroundImage: hasImg ? NetworkImage(imgUrl) : null,
                                        child: hasImg
                                            ? null
                                            : const Icon(
                                                Icons.inventory_2_rounded,
                                                color: AppColors.primary,
                                                size: 16,
                                              ),
                                      );
                                    })(),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        key,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '$qty Units',
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildUsageItem(Map<String, dynamic> usage) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.outbox_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  usage['item_name'] ?? 'Unknown Item',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Used at: ${usage['farms']?['name'] ?? 'Unknown Farm'}',
                  style: TextStyle(color: AppColors.textGray, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '-${usage['quantity']}',
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                usage['unit'] ?? 'Units',
                style: const TextStyle(fontSize: 10, color: AppColors.textGray),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
