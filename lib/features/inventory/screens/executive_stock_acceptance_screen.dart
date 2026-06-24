import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:intl/intl.dart';

class ExecutiveStockAcceptanceScreen extends StatefulWidget {
  const ExecutiveStockAcceptanceScreen({super.key});

  @override
  State<ExecutiveStockAcceptanceScreen> createState() => _ExecutiveStockAcceptanceScreenState();
}

class _ExecutiveStockAcceptanceScreenState extends State<ExecutiveStockAcceptanceScreen> {
  bool _isLoading = true;
  bool _isProcessing = false;
  List<Map<String, dynamic>> _pendingTransactions = [];
  List<Map<String, dynamic>> _productOptions = [];
  String? _currentUserId;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  Future<void> _loadPending() async {
    setState(() => _isLoading = true);
    try {
      final pending = await SupabaseService.getPendingStoreTransactions();
      final profile = await SupabaseService.getProfile();
      final products = await SupabaseService.getHierarchicalDropdownOptions('product_name');
      if (mounted) {
        setState(() {
          _pendingTransactions = pending;
          _productOptions = products;
          _currentUserId = SupabaseService.client.auth.currentUser?.id;
          _userRole = profile?['role'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAcceptance(String id, bool accept) async {
    final status = accept ? 'ACCEPTED' : 'REJECTED';
    
    setState(() => _isProcessing = true);
 
    try {
      await SupabaseService.updateStoreTransactionStatus(id, status);
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stock ${status.toLowerCase()} successfully')),
        );
        _loadPending();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
 
  Future<void> _handleDelete(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Delivery?'),
        content: const Text('Are you sure you want to delete this pending delivery? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
 
    if (confirm != true) return;
 
    setState(() => _isProcessing = true);
 
    try {
      await SupabaseService.deleteStoreTransaction(id);
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery deleted successfully')),
        );
        _loadPending();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pending Handovers'),
        actions: [
          IconButton(onPressed: _loadPending, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: Stack(
        children: [
          _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _pendingTransactions.isEmpty 
                  ? _buildEmptyState()
                  : _buildPendingList(),
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_turned_in_rounded, size: 64, color: AppColors.textGray.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text('All caught up!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const Text('No pending stock approvals found.', style: TextStyle(color: AppColors.textGray)),
        ],
      ),
    );
  }

  Widget _buildPendingList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingTransactions.length,
      itemBuilder: (context, index) {
        final tx = _pendingTransactions[index];
        final isDelivery = tx['transaction_type'] == 'DELIVERY';
        final date = DateTime.tryParse(tx['created_at']?.toString() ?? '') ?? DateTime.now();
        final dateStr = DateFormat('dd MMM, hh:mm a').format(date);

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: isDelivery ? Colors.orange.withOpacity(0.2) : Colors.purple.withOpacity(0.2)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _typeBadge(isDelivery ? 'STORE DELIVERY' : 'RETURN TO STORE', isDelivery ? Colors.orange : Colors.purple),
                    Text(dateStr, style: const TextStyle(fontSize: 11, color: AppColors.textGray)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
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
                        backgroundColor: AppColors.secondary.withOpacity(0.5),
                        backgroundImage: hasImg ? NetworkImage(imgUrl) : null,
                        child: hasImg
                            ? null
                            : const Icon(
                                Icons.inventory_2_rounded,
                                color: AppColors.primary,
                                size: 20,
                              ),
                      );
                    })(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx['item_name'] ?? 'Unknown Item',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          Text(
                            'Quantity: ${tx['quantity']} x ${tx['unit']}',
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                // Logic for Admin/Store viewing DELIVERIES (Handover Pending)
                if ((_userRole == 'admin' || _userRole == 'store') && isDelivery) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.hourglass_empty_rounded, size: 16, color: Colors.orange.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Handover Pending',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      // Admins can delete any pending delivery, Store can delete their own
                      if (_userRole == 'admin' || (_userRole == 'store' && tx['created_by'] == _currentUserId))
                        TextButton.icon(
                          onPressed: () => _handleDelete(tx['id']),
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                          label: const Text('Delete Delivery', style: TextStyle(color: Colors.red, fontSize: 13)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            backgroundColor: Colors.red.withOpacity(0.05),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                    ],
                  ),
                ] else ...[
                  // Standard Accept/Reject for receivers
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => _handleAcceptance(tx['id'], false),
                          child: const Text('Reject', style: TextStyle(color: Colors.red)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _handleAcceptance(tx['id'], true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                          ),
                          child: const Text('Accept Stock'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _typeBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
