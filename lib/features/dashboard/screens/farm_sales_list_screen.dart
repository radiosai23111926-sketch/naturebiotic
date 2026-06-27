import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:nature_biotic/features/farms/screens/stock_management_screen.dart';
import 'package:nature_biotic/features/farms/screens/add_collection_screen.dart';
import 'package:nature_biotic/features/farms/screens/collection_history_screen.dart';
import 'package:nature_biotic/features/farms/screens/add_stock_entry_screen.dart';
import 'package:intl/intl.dart';
import 'package:nature_biotic/services/pdf_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class FarmSalesListScreen extends StatefulWidget {
  final List<Map<String, dynamic>> initialTransactions;
  final List<Map<String, dynamic>> initialCollections;
  final List<Map<String, dynamic>>? initialBills;
  final List<Map<String, dynamic>> allProducts;
  final List<Map<String, dynamic>> allFarms;
  final String mode; // 'SALES', 'COLLECTION', 'OUTSTANDING'

  const FarmSalesListScreen({
    super.key,
    required this.initialTransactions,
    this.initialCollections = const [],
    this.initialBills,
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
  Set<String> _expandedFarmIds = {};
  bool _isLoading = true;
  TextEditingController? _cachedSearchController;
  TextEditingController get _searchController =>
      _cachedSearchController ??= TextEditingController();
  
  late List<Map<String, dynamic>> _currentTransactions;
  late List<Map<String, dynamic>> _currentCollections;
  late List<Map<String, dynamic>> _currentBills;

  @override
  void dispose() {
    _cachedSearchController?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _currentTransactions = List.from(widget.initialTransactions);
    _currentCollections = List.from(widget.initialCollections);
    _currentBills = List.from(widget.initialBills ?? []);
    _processData();
  }

  Future<void> _processData() async {
    final profile = await SupabaseService.getProfile();
    final role = profile?['role']?.toString().toLowerCase();
    final userId = SupabaseService.client.auth.currentUser?.id;

    // Fetch fresh bills from Supabase/SQLite so that new stock entries and their bills/discounts are dynamically loaded
    try {
      final freshBills = await SupabaseService.getBills();
      _currentBills = List<Map<String, dynamic>>.from(freshBills);
    } catch (e) {
      debugPrint('Error fetching fresh bills in FarmSalesListScreen: $e');
    }

    final Map<String, Map<String, dynamic>> grouped = {};

    // 0. Process Bills for Revenue
    for (var bill in _currentBills) {
      if ((role == 'executive' || role == 'telecaller') && userId != null) {
        final billExecId = bill['executive_id']?.toString().toLowerCase();
        final currentId = userId.toLowerCase();
        if (billExecId != currentId) {
          continue;
        }
      }

      final farmId = bill['farm_id']?.toString();
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

      final grandTotal = double.tryParse(bill['grand_total']?.toString() ?? '0') ?? 0.0;
      grouped[farmId]!['total_revenue'] += grandTotal;
    }

    for (var tx in _currentTransactions) {
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

      if (widget.mode == 'SALES' || widget.mode == 'OUTSTANDING') {
        final itemName = tx['item_name']?.toString().trim().toLowerCase();
        final rawUnit = tx['unit']?.toString().trim().toLowerCase() ?? '';
        final unit = rawUnit.split(' {₹')[0].trim();

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

        grouped[farmId]!['logs'].add({
          ...tx,
          '_source': 'transaction',
          '_price': price,
        });
      }

      // Calculate physical items and return values (not received sales revenue since it's now computed from bills)
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
    for (var col in _currentCollections) {
      if ((role == 'executive' || role == 'telecaller') && userId != null) {
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

          // Handle nested farmer data (can be Map or List)
          final farmerData = farm['farmers'];
          if (farmerData is Map) {
            _farmSales[id]!['farmer_name'] =
                farmerData['name'] ?? 'No Farmer';
          } else if (farmerData is List && farmerData.isNotEmpty) {
            _farmSales[id]!['farmer_name'] =
                farmerData[0]['name'] ?? 'No Farmer';
          } else {
            _farmSales[id]!['farmer_name'] = 'No Farmer';
          }

          _farmSales[id]!['location'] =
              farm['place'] ?? farm['location'] ?? 'No Location';

          // Store farmer contact info for PDF generation
          if (farmerData is Map) {
            _farmSales[id]!['farmer_mobile'] = farmerData['mobile'];
            _farmSales[id]!['farmer_address'] = farmerData['address'];
          } else if (farmerData is List && farmerData.isNotEmpty) {
            _farmSales[id]!['farmer_mobile'] = farmerData[0]['mobile'];
            _farmSales[id]!['farmer_address'] = farmerData[0]['address'];
          }

          // Handle multi-crop relationships correctly
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
          .select('*, farmers(name, mobile, address), crops(name)')
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

    List<Map<String, dynamic>> flatCollections = [];
    if (widget.mode == 'COLLECTION') {
      for (var farm in list) {
        final logs = (farm['logs'] as List?) ?? [];
        for (var log in logs) {
          if (log is Map<String, dynamic> && log['_source'] == 'collection') {
            flatCollections.add({'log': log, 'farmData': farm});
          }
        }
      }
      flatCollections.sort((a, b) {
        final aStr = a['log']['created_at']?.toString() ?? '';
        final bStr = b['log']['created_at']?.toString() ?? '';
        return bStr.compareTo(aStr);
      });

      // Apply Name Search (already handled in list generation but ensuring flatCollections is filtered)
      if (_searchController.text.isNotEmpty) {
        final q = _searchController.text.toLowerCase();
        flatCollections = flatCollections.where((c) {
          final farm = (c['farmData']['name'] ?? '').toString().toLowerCase();
          final farmer = (c['farmData']['farmer_name'] ?? '').toString().toLowerCase();
          return farm.contains(q) || farmer.contains(q);
        }).toList();
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (widget.mode == 'COLLECTION' && flatCollections.isNotEmpty)
            TextButton.icon(
              onPressed: () => _printFilteredReceipts(flatCollections),
              icon: const Icon(Icons.print_rounded, size: 18),
              label: const Text('Print Receipts', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
        ],
      ),
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
                          (widget.mode == 'COLLECTION' ? flatCollections.isEmpty : list.isEmpty)
                              ? _buildEmptyState()
                              : ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                itemCount: widget.mode == 'COLLECTION' ? flatCollections.length : list.length,
                                itemBuilder: (context, index) {
                                  if (widget.mode == 'COLLECTION') {
                                    return _buildFlatCollectionCard(
                                      flatCollections[index]['log'] as Map<String, dynamic>,
                                      flatCollections[index]['farmData'] as Map<String, dynamic>,
                                    );
                                  }
                                  return _buildFarmCard(list[index]);
                                },
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
                final farmId = farm['id'].toString();
                final farmSalesData = _farmSales[farmId] ?? {};
                final accAmount =
                    double.tryParse(
                      farmSalesData['total_revenue']?.toString() ?? '0',
                    ) ??
                    0.0;
                final totalCollection =
                    double.tryParse(
                      farmSalesData['total_collection']?.toString() ?? '0',
                    ) ??
                    0.0;
                final balanceDue = accAmount - totalCollection;

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => AddCollectionScreen(
                          farmId: farmId,
                          farmName: farm['name'] ?? 'Unknown Farm',
                          farmerName: farmer['name'],
                          cropId: crop?['id']?.toString(),
                          cropName: crop?['name']?.toString(),
                          accAmount: accAmount,
                          balanceDue: balanceDue,
                        ),
                  ),
                ).then((result) {
                  if (result != null && result is Map<String, dynamic>) {
                    _currentCollections.add(result);
                    _processData();
                  }
                });
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
                ).then((result) {
                  if (result != null && result is List) {
                    for (var item in result) {
                      if (item is Map<String, dynamic>) {
                        _currentTransactions.add(item);
                      }
                    }
                    _processData();
                  }
                });
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

  Future<void> _downloadConsolidatedChallan(Map<String, dynamic> farmData) async {
    final List<Map<String, dynamic>> logs = List<Map<String, dynamic>>.from(
      farmData['logs'] ?? [],
    );

    // Filter only SALES RECEIVED (positive items)
    final salesLogs =
        logs
            .where(
              (log) =>
                  log['_source'] == 'transaction' &&
                  log['transaction_type']?.toString().toUpperCase() ==
                      'RECEIVED',
            )
            .toList();

    if (salesLogs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No sales records to download.')),
        );
      }
      return;
    }

    final challanItems =
        salesLogs.map((log) {
          final qty =
              double.tryParse(log['quantity']?.toString() ?? '0') ?? 0.0;
          final price =
              double.tryParse(log['_price']?.toString() ?? '0') ?? 0.0;
          return {
            'name': log['item_name'] ?? 'N/A',
            'quantity': qty,
            'price': price,
            'unit': (log['unit']?.toString() ?? '').split(' {₹')[0].trim(),
          };
        }).toList();

    // Generate DC Number
    final prefs = await SharedPreferences.getInstance();
    
    // Get Executive ID part (fallback to 0000 if not found)
    final profile = await SupabaseService.getProfile();
    String execPart = '0000';
    if (profile != null) {
      final staffNo = profile['staff_number']?.toString();
      if (staffNo != null && staffNo.isNotEmpty) {
        execPart = staffNo.padLeft(4, '0');
        if (execPart.length > 4) {
          execPart = execPart.substring(execPart.length - 4);
        }
      } else {
        final username = profile['username']?.toString() ?? '';
        // Extract digits from username (e.g. exec0002 -> 0002)
        final digits = username.replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.isNotEmpty) {
          execPart = digits.padLeft(4, '0');
          if (execPart.length > 4) {
            execPart = execPart.substring(execPart.length - 4);
          }
        } else {
          // Fallback to first 4 chars of user ID if no digits
          final id = profile['id']?.toString() ?? '';
          if (id.length >= 4) {
            execPart = id.substring(0, 4).toUpperCase();
          }
        }
      }
    }

    // Get Receipt Number (Sequential)
    // Tie it to the farm and latest timestamp to keep it consistent on redownloads
    final farmId = farmData['farm_id']?.toString() ?? 'unknown';
    final latestTs = salesLogs.isNotEmpty ? salesLogs.first['created_at']?.toString() ?? '' : '';
    final dcKey = 'dc_number_${farmId}_$latestTs';
    
    int receiptNo = prefs.getInt(dcKey) ?? 0;
    if (receiptNo == 0) {
      // Generate new sequential number
      int globalCounter = prefs.getInt('global_dc_counter') ?? 1;
      receiptNo = globalCounter;
      await prefs.setInt('global_dc_counter', globalCounter + 1);
      await prefs.setInt(dcKey, receiptNo);
    }
    
    final receiptPart = receiptNo.toString().padLeft(4, '0');
    
    // Financial Year
    final now = DateTime.now();
    int startYear = now.month < 4 ? now.year - 1 : now.year;
    final fy = '$startYear-${startYear + 1}';
    
    final customDcNumber = 'SAI$execPart$receiptPart/$fy';

    try {
      await PdfService.generateStockChallan(
        items: challanItems,
        farmName: farmData['farm_name'] ?? 'N/A',
        farmerName: farmData['farmer_name'] ?? 'N/A',
        cropName: farmData['crop_name'] ?? 'N/A',
        transactionType: 'SALES',
        date: DateTime.now(), // Use current date for the consolidated statement
        farmerAddress: farmData['farmer_address'],
        farmerContact: farmData['farmer_mobile'],
        dcNumber: customDcNumber,
        placeOfSupply: farmData['location']?.toString(),
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

  Future<void> _downloadPaymentReceipt(Map<String, dynamic> log, Map<String, dynamic> farmData) async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating Receipt...'), duration: Duration(seconds: 1)),
      );
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final profile = await SupabaseService.getProfile();
      
      String execPart = '0000';
      if (profile != null) {
        final staffNo = profile['staff_number']?.toString();
        if (staffNo != null && staffNo.isNotEmpty) {
          execPart = staffNo.padLeft(4, '0');
          if (execPart.length > 4) {
            execPart = execPart.substring(execPart.length - 4);
          }
        } else {
          final username = profile['username']?.toString() ?? '';
          final digits = username.replaceAll(RegExp(r'[^0-9]'), '');
          if (digits.isNotEmpty) {
            execPart = digits.padLeft(4, '0');
            if (execPart.length > 4) {
              execPart = execPart.substring(execPart.length - 4);
            }
          } else {
            final id = profile['id']?.toString() ?? '';
            if (id.length >= 4) {
              execPart = id.substring(0, 4).toUpperCase();
            }
          }
        }
      }

      String? customReceiptNumber = log['receipt_no']?.toString();
      
      if (customReceiptNumber == null || customReceiptNumber.isEmpty) {
        final logId = log['id']?.toString() ?? log['created_at'].toString();
        final receiptKey = 'receipt_number_$logId';
        
        int receiptNo = prefs.getInt(receiptKey) ?? 0;
        if (receiptNo == 0) {
          int globalCounter = prefs.getInt('global_receipt_counter') ?? 1;
          receiptNo = globalCounter;
          await prefs.setInt('global_receipt_counter', globalCounter + 1);
          await prefs.setInt(receiptKey, receiptNo);
        }
        
        final receiptPart = receiptNo.toString().padLeft(4, '0');
        final now = DateTime.now();
        int startYear = now.month < 4 ? now.year - 1 : now.year;
        final fy = '$startYear-${startYear + 1}';
        customReceiptNumber = 'SAI$execPart$receiptPart/$fy';
      }

      final amt = double.tryParse(log['amount']?.toString() ?? '0') ?? 0.0;
      
      double accAmount = 0.0;
      final totalRevenue = double.tryParse(farmData['total_revenue']?.toString() ?? '0') ?? 0.0;
      accAmount = totalRevenue; 
      
      final totalCollection = double.tryParse(farmData['total_collection']?.toString() ?? '0') ?? 0.0;
      final balanceDue = accAmount - totalCollection;

      final dateStr = log['created_at']?.toString() ?? DateTime.now().toIso8601String();
      final date = DateTime.tryParse(dateStr) ?? DateTime.now();

      await PdfService.generatePaymentReceipt(
        receiptNo: customReceiptNumber,
        date: date,
        customerName: farmData['farmer_name'] ?? 'N/A',
        contactNo: farmData['farmer_mobile'] ?? 'N/A',
        customerAddress: farmData['farmer_address'] ?? 'N/A',
        amount: amt,
        purpose: '${farmData['farm_name'] ?? 'N/A'} - ${farmData['crop_name'] ?? 'N/A'}',
        accAmount: accAmount,
        balanceDue: balanceDue < 0 ? 0 : balanceDue,
        paymentMethod: log['payment_method']?.toString() ?? 'Cash',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating receipt: $e')),
        );
      }
    }
  }

  Widget _buildFarmCard(Map<String, dynamic> data) {
    double displayValue = 0;
    String label = '';
    Color gradientStart = const Color(0xFF4CAF50); // Green
    Color gradientEnd = const Color(0xFF2E7D32);
    IconData mainIcon = Icons.agriculture_rounded;

    if (widget.mode == 'SALES') {
      displayValue = data['total_revenue'];
      label = 'Revenue';
      gradientStart = const Color(0xFF66BB6A);
      gradientEnd = const Color(0xFF2E7D32);
      mainIcon = Icons.agriculture_rounded;
    } else if (widget.mode == 'COLLECTION') {
      displayValue = data['total_collection'];
      label = 'Collected';
      gradientStart = const Color(0xFF26C6DA);
      gradientEnd = const Color(0xFF00838F);
      mainIcon = Icons.payments_rounded;
    } else if (widget.mode == 'OUTSTANDING') {
      displayValue = data['total_revenue'] - data['total_collection'];
      label = 'Outstanding';
      gradientStart = const Color(0xFFFFA726);
      gradientEnd = const Color(0xFFE65100);
      mainIcon = Icons.account_balance_wallet_rounded;
    }

    final farmId = data['farm_id']?.toString() ?? '';
    final isExpanded = _expandedFarmIds.contains(farmId);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [gradientStart, gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: gradientEnd.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Large Transparent Watermark Icon
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              mainIcon,
              size: 150,
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          // Foreground Content
          Column(
            children: [
              InkWell(
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedFarmIds.remove(farmId);
                    } else {
                      _expandedFarmIds.add(farmId);
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top-Left Icon Box
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          mainIcon,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Main Text Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['farmer_name']?.toString() ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                color: Colors.white,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              data['farm_name']?.toString() ?? '',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_rounded,
                                  size: 14,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    data['location']?.toString() ?? 'N/A',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.7),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.grass_rounded, size: 14, color: Colors.white.withValues(alpha: 0.9)),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          data['crop_name']?.toString() ?? 'No Crop',
                                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (widget.mode == 'SALES' || widget.mode == 'OUTSTANDING')
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.inventory_2_outlined, size: 14, color: Colors.white.withValues(alpha: 0.9)),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            '${data['total_items'].toInt()} Items',
                                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Amount and Actions
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  currencyFormat.format(displayValue),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  isExpanded
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            label.toUpperCase(),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                          if (widget.mode == 'SALES' || widget.mode == 'OUTSTANDING') ...[
                            const SizedBox(height: 16),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.3),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                padding: const EdgeInsets.all(10),
                                constraints: const BoxConstraints(),
                                icon: const Icon(
                                  Icons.file_download_outlined,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                tooltip: 'Download Sales Challan',
                                onPressed: () {
                                  _downloadConsolidatedChallan(data);
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (isExpanded) ...[
                // Balances Section
                Builder(
                  builder: (context) {
                    final rawMap = data['balances'];
                    if (rawMap == null || rawMap is! Map) return const SizedBox.shrink();
                    final bMap = rawMap;
                    if (bMap.isEmpty) return const SizedBox.shrink();
                    final items = bMap.values.toList();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Divider(height: 1, indent: 20, endIndent: 20, color: Colors.white.withValues(alpha: 0.2)),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: items.map((it) {
                              if (it is! Map) return const SizedBox.shrink();
                              final qty = double.tryParse(it['qty']?.toString() ?? '0') ?? 0.0;
                              if (qty.abs() < 0.01) return const SizedBox.shrink();
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.inventory_2_rounded, size: 12, color: Colors.white),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${it['item']} (${it['unit']}) : ',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.9)),
                                    ),
                                    Text(
                                      '${qty.toInt()}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
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
                // Logs Section
                Builder(
                  builder: (context) {
                    final rawLogs = data['logs'];
                    final logs = (rawLogs is List) ? rawLogs : [];
                    if (logs.isEmpty) return const SizedBox.shrink();
                    return Column(
                      children: [
                        Divider(height: 1, indent: 20, endIndent: 20, color: Colors.white.withValues(alpha: 0.2)),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                          child: Column(
                            children: logs.map((l) => _buildInnerLogItem(l as Map<String, dynamic>, data)).toList(),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ],
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

  Widget _buildInnerLogItem(
    Map<String, dynamic> log,
    Map<String, dynamic> farmData,
  ) {
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

  Widget _buildFlatCollectionCard(Map<String, dynamic> log, Map<String, dynamic> farmData) {
    final amt = double.tryParse(log['amount']?.toString() ?? '0') ?? 0.0;
    final date = _formatDate(log['created_at']);
    
    // Teal Gradient for Collection
    Color gradientStart = const Color(0xFF26C6DA);
    Color gradientEnd = const Color(0xFF00838F);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [gradientStart, gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: gradientEnd.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Large Transparent Watermark Icon
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              Icons.payments_rounded,
              size: 150,
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top-Left Icon Box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.payments_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        farmData['farmer_name']?.toString() ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        farmData['farm_name']?.toString() ?? '',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              farmData['location']?.toString() ?? 'N/A',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.grass_rounded, size: 14, color: Colors.white.withValues(alpha: 0.9)),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    farmData['crop_name']?.toString() ?? 'No Crop',
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.receipt_long_rounded, size: 14, color: Colors.white.withValues(alpha: 0.9)),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    log['receipt_no']?.toString() ?? 'No Receipt',
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '+${currencyFormat.format(amt)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'COLLECTED',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      date,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            padding: const EdgeInsets.all(10),
                            constraints: const BoxConstraints(),
                            icon: const Icon(
                              Icons.image_search_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            tooltip: 'View Payment Proof',
                            onPressed: () async {
                              final proofUrl = log['proof_url'];
                              if (proofUrl != null && proofUrl.toString().isNotEmpty) {
                                final uri = Uri.parse(proofUrl.toString());
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri);
                                }
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('No payment proof uploaded for this collection.'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            padding: const EdgeInsets.all(10),
                            constraints: const BoxConstraints(),
                            icon: const Icon(
                              Icons.print_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                            tooltip: 'Print Receipt',
                            onPressed: () {
                              _downloadPaymentReceipt(log, farmData);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _printFilteredReceipts(List<Map<String, dynamic>> flatList) async {
    // 1. Get all unique receipt numbers and sort them
    final List<String> receiptNumbers =
        flatList
            .map((e) => e['log']['receipt_no']?.toString() ?? '')
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList();

    // Sort logically (if possible) or alphabetically
    receiptNumbers.sort();

    String? fromReceipt;
    String? toReceipt;
    List<String>? selectedRange;

    if (receiptNumbers.isNotEmpty) {
      fromReceipt = receiptNumbers.first;
      toReceipt = receiptNumbers.last;

      final result = await showDialog<bool>(
        context: context,
        builder:
            (context) => StatefulBuilder(
              builder:
                  (context, setDialogState) => AlertDialog(
                    title: const Text('Print Range Selection'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          value: fromReceipt,
                          decoration: const InputDecoration(labelText: 'From Receipt No.'),
                          items:
                              receiptNumbers.map((r) {
                                return DropdownMenuItem(value: r, child: Text(r));
                              }).toList(),
                          onChanged: (v) {
                            if (v != null) setDialogState(() => fromReceipt = v);
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: toReceipt,
                          decoration: const InputDecoration(labelText: 'To Receipt No.'),
                          items:
                              receiptNumbers.map((r) {
                                return DropdownMenuItem(value: r, child: Text(r));
                              }).toList(),
                          onChanged: (v) {
                            if (v != null) setDialogState(() => toReceipt = v);
                          },
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Print'),
                      ),
                    ],
                  ),
            ),
      );

      if (result != true) return;

      // Filter flatList by the selected range
      final fromIdx = receiptNumbers.indexOf(fromReceipt!);
      final toIdx = receiptNumbers.indexOf(toReceipt!);
      final startIdx = fromIdx < toIdx ? fromIdx : toIdx;
      final endIdx = fromIdx < toIdx ? toIdx : fromIdx;
      selectedRange = receiptNumbers.sublist(startIdx, endIdx + 1);
    }

    final List<Map<String, dynamic>> receiptsData = [];

    for (var item in flatList) {
      final log = item['log'] as Map<String, dynamic>;
      final recNo = log['receipt_no']?.toString() ?? 'N/A';

      if (selectedRange != null && !selectedRange.contains(recNo)) continue;

      final farmData = item['farmData'] as Map<String, dynamic>;
      final amt = double.tryParse(log['amount']?.toString() ?? '0') ?? 0.0;
      final createdAt = log['created_at'] != null
          ? DateTime.tryParse(log['created_at'].toString()) ?? DateTime.now()
          : DateTime.now();

      receiptsData.add({
        'receiptNo': recNo,
        'date': createdAt,
        'customerName': farmData['farmer_name'] ?? 'N/A',
        'contactNo': farmData['farmer_mobile'] ?? 'N/A',
        'customerAddress': farmData['location'] ?? 'N/A',
        'amount': amt,
        'purpose': log['notes'] ?? 'Farm Collection',
        'accAmount': farmData['total_revenue'] ?? 0.0,
        'balanceDue': (farmData['total_revenue'] ?? 0.0) - (farmData['total_collection'] ?? 0.0),
        'paymentMethod': log['payment_method'] ?? 'Cash',
      });
    }

    if (receiptsData.isEmpty) return;

    await PdfService.generateBulkReceiptsPdf(receiptsData: receiptsData);
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
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                if (_step != 'FARMER')
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      setState(() {
                        if (_step == 'CROP') {
                          _step = 'FARM';
                        } else if (_step == 'FARM') {
                          _step = 'FARMER';
                        }
                      });
                    },
                  ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
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
                final p = (f['mobile'] ?? '').toString().toLowerCase();
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
            subtitle: f['mobile'] ?? 'No Phone',
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
            subtitle: 'Variety: ${crop['variety'] ?? 'N/A'}',
            icon: Icons.grass_rounded,
            onTap: () {
              widget.onComplete(_selectedFarmer!, _selectedFarm!, crop);
            },
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
