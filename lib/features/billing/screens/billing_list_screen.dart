import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'bill_details_screen.dart';

class BillingListScreen extends StatefulWidget {
  const BillingListScreen({super.key});

  @override
  State<BillingListScreen> createState() => _BillingListScreenState();
}

class _BillingListScreenState extends State<BillingListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _allBills = [];
  bool _isLoading = true;
  String _userRole = 'executive';
  
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        SupabaseService.getBills(),
        SupabaseService.getProfile().catchError((_) => null),
      ]);
      _allBills = List<Map<String, dynamic>>.from(results[0] as List);
      final profile = results[1] as Map<String, dynamic>?;
      _userRole = (profile?['role']?.toString() ?? 'executive').toLowerCase();
    } catch (e) {
      debugPrint('Error loading bills: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmDeleteBill(Map<String, dynamic> bill) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Bill?'),
        content: Text('Are you sure you want to delete bill "${bill['challan_no']}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await SupabaseService.deleteBill(bill['id'].toString());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bill deleted successfully!'), backgroundColor: AppColors.primary),
          );
        }
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting bill: $e'), backgroundColor: Colors.red),
          );
        }
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> _filterBills(List<String> statuses) {
    return _allBills.where((bill) {
      final s = bill['status']?.toString().toUpperCase() ?? '';
      if (!statuses.contains(s)) return false;
      
      if (_searchQuery.isEmpty) return true;
      
      final challanNo = (bill['challan_no']?.toString() ?? '').toLowerCase();
      final customerName = (bill['customer_name']?.toString() ?? '').toLowerCase();
      final customerGstin = (bill['customer_gstin']?.toString() ?? '').toLowerCase();
      
      String farmName = '';
      String farmerName = '';
      if (bill['farms'] != null) {
        farmName = (bill['farms']['name']?.toString() ?? '').toLowerCase();
        if (bill['farms']['farmers'] != null) {
          farmerName = (bill['farms']['farmers']['name']?.toString() ?? '').toLowerCase();
        }
      }
      
      return challanNo.contains(_searchQuery) ||
             customerName.contains(_searchQuery) ||
             customerGstin.contains(_searchQuery) ||
             farmName.contains(_searchQuery) ||
             farmerName.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final pendingBilling = _filterBills(['PENDING_BILLING', 'REJECTED']);
    final pendingApproval = _filterBills(['PENDING_APPROVAL']);
    final readyToBill = _filterBills(['APPROVED']);
    final billed = _filterBills(['BILLED']);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: GoogleFonts.outfit(fontSize: 16, color: AppColors.textBlack),
                decoration: InputDecoration(
                  hintText: 'Search by challan, farmer, or farm...',
                  hintStyle: GoogleFonts.outfit(fontSize: 16, color: AppColors.textGray.withOpacity(0.6)),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.trim().toLowerCase();
                  });
                },
              )
            : const Text('Billing Management'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchController.clear();
                  _searchQuery = '';
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadData,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textGray,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: [
            Tab(text: 'Pending Billing (${pendingBilling.length})'),
            Tab(text: 'Approval Pending (${pendingApproval.length})'),
            Tab(text: 'Ready to Bill (${readyToBill.length})'),
            Tab(text: 'Billed (${billed.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildBillList(pendingBilling),
                _buildBillList(pendingApproval),
                _buildBillList(readyToBill),
                _buildBillList(billed),
              ],
            ),
    );
  }

  Widget _buildBillList(List<Map<String, dynamic>> bills) {
    if (bills.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_rounded, size: 64, color: AppColors.textGray.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              'No bills found in this category',
              style: GoogleFonts.outfit(fontSize: 16, color: AppColors.textGray, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bills.length,
      itemBuilder: (context, index) {
        final bill = bills[index];
        return _buildBillCard(bill);
      },
    );
  }

  Widget _buildBillCard(Map<String, dynamic> bill) {
    // Resolve Farm & Farmer Name
    String farmName = 'Unknown Farm';
    String farmerName = 'Unknown Farmer';
    if (bill['farms'] != null) {
      farmName = bill['farms']['name'] ?? 'Unknown Farm';
      if (bill['farms']['farmers'] != null) {
        farmerName = bill['farms']['farmers']['name'] ?? 'Unknown Farmer';
      }
    }

    final dateStr = bill['challan_date'] ?? bill['created_at'] ?? 'N/A';
    String formattedDate = dateStr;
    try {
      final parsed = DateTime.parse(dateStr);
      formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(parsed);
    } catch (_) {}

    final itemsList = bill['items'] is List 
        ? (bill['items'] as List) 
        : [];
    final itemsCount = itemsList.length;

    final grandTotal = double.tryParse(bill['grand_total']?.toString() ?? '0') ?? 0.0;
    final status = bill['status']?.toString().toUpperCase() ?? 'PENDING_BILLING';

    Color statusColor = Colors.orange;
    String statusLabel = 'Pending Billing';
    if (status == 'REJECTED') {
      statusColor = Colors.red;
      statusLabel = 'Rejected';
    } else if (status == 'PENDING_APPROVAL') {
      statusColor = Colors.amber.shade800;
      statusLabel = 'Approval Pending';
    } else if (status == 'APPROVED') {
      statusColor = Colors.blue;
      statusLabel = 'Ready to Bill';
    } else if (status == 'BILLED') {
      statusColor = Colors.green;
      statusLabel = 'Billed';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          final updated = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BillDetailsScreen(bill: bill),
            ),
          );
          if (updated == true) {
            _loadData();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      farmName,
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          statusLabel,
                          style: GoogleFonts.outfit(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (_userRole == 'data_entry') ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          onPressed: () => _confirmDeleteBill(bill),
                          tooltip: 'Delete Bill',
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Farmer: $farmerName',
                style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textGray),
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Challan: ${bill['challan_no'] ?? 'N/A'}',
                        style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textGray),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formattedDate,
                        style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textGray),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Total ($itemsCount items)',
                        style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textGray),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${grandTotal.toStringAsFixed(2)}',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
