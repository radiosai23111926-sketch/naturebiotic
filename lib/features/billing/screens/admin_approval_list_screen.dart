import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';

class AdminApprovalListScreen extends StatefulWidget {
  const AdminApprovalListScreen({super.key});

  @override
  State<AdminApprovalListScreen> createState() => _AdminApprovalListScreenState();
}

class _AdminApprovalListScreenState extends State<AdminApprovalListScreen> {
  List<Map<String, dynamic>> _pendingBills = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPendingBills();
  }

  Future<void> _loadPendingBills() async {
    setState(() => _isLoading = true);
    try {
      final bills = await SupabaseService.getBills();
      setState(() {
        _pendingBills = bills.where((b) => b['status'] == 'PENDING_APPROVAL').toList();
      });
    } catch (e) {
      debugPrint('Error loading pending approvals: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleDecision(Map<String, dynamic> bill, bool approve) async {
    final notesController = TextEditingController();
    final actionLabel = approve ? 'Approve' : 'Reject';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$actionLabel Discount Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to $actionLabel this request?'),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Notes / Feedback (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
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
            style: ElevatedButton.styleFrom(
              backgroundColor: approve ? Colors.green : Colors.red,
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        final decision = approve ? 'APPROVED' : 'REJECTED';
        await SupabaseService.updateBill(bill['id'], {
          'status': decision,
          'admin_notes': notesController.text.trim(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Request ${approve ? "approved" : "rejected"} successfully'),
              backgroundColor: approve ? Colors.green : Colors.red,
            ),
          );
        }
        _loadPendingBills();
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pending Discount Approvals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadPendingBills,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pendingBills.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline_rounded, size: 64, color: Colors.green.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      Text(
                        'All requests cleared!',
                        style: GoogleFonts.outfit(fontSize: 16, color: AppColors.textGray, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _pendingBills.length,
                  itemBuilder: (context, index) {
                    final bill = _pendingBills[index];
                    return _buildApprovalCard(bill);
                  },
                ),
    );
  }

  Widget _buildApprovalCard(Map<String, dynamic> bill) {
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

    final discType = bill['discount_type']?.toString() ?? 'none';
    final discVal = double.tryParse(bill['discount_value']?.toString() ?? '0') ?? 0.0;
    final totalDisc = double.tryParse(bill['total_discount']?.toString() ?? '0') ?? 0.0;
    final grandTotal = double.tryParse(bill['grand_total']?.toString() ?? '0') ?? 0.0;

    // Calculate subtotal
    final itemsList = bill['items'] is List ? (bill['items'] as List) : [];
    double subtotal = 0.0;
    for (var item in itemsList) {
      final qty = double.tryParse((item['qty'] ?? item['quantity'])?.toString() ?? '0') ?? 0.0;
      final rate = double.tryParse(item['offer_price']?.toString() ?? '0') ?? 0.0;
      subtotal += qty * rate;
    }

    String discountDesc = 'No Discount';
    if (discType == 'percentage') {
      discountDesc = '${discVal}% (₹${totalDisc.toStringAsFixed(2)})';
    } else if (discType == 'flat') {
      discountDesc = 'Flat ₹${discVal.toStringAsFixed(2)}';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                Text(
                  formattedDate,
                  style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textGray),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Farmer: $farmerName | Challan: ${bill['challan_no'] ?? 'N/A'}',
              style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textGray),
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Original Subtotal:', style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textGray)),
                    Text('₹${subtotal.toStringAsFixed(2)}', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('Requested Discount:', style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textGray)),
                    Text(discountDesc, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('New Grand Total:', style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textGray)),
                    Text('₹${grandTotal.toStringAsFixed(2)}', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _handleDecision(bill, false),
                  icon: const Icon(Icons.close_rounded, color: Colors.red, size: 18),
                  label: const Text('Reject', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _handleDecision(bill, true),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
