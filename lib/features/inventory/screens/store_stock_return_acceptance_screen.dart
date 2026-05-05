import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:intl/intl.dart';
import 'package:nature_biotic/core/widgets/animations.dart';
import 'package:nature_biotic/features/inventory/screens/stock_transaction_form.dart';

class StoreStockReturnAcceptanceScreen extends StatefulWidget {
  const StoreStockReturnAcceptanceScreen({super.key});

  @override
  State<StoreStockReturnAcceptanceScreen> createState() => _StoreStockReturnAcceptanceScreenState();
}

class _StoreStockReturnAcceptanceScreenState extends State<StoreStockReturnAcceptanceScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _pendingReturns = [];
  List<Map<String, dynamic>> _returnHistory = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final pending = await SupabaseService.getPendingStoreTransactions();
      final all = await SupabaseService.getStoreTransactions();
      
      if (mounted) {
        setState(() {
          // Filter for returns and requests
          _pendingReturns = pending.where((tx) => tx['transaction_type'] == 'RETURN' || tx['transaction_type'] == 'REQUEST').toList();
          _returnHistory = all.where((tx) => 
            (tx['transaction_type'] == 'RETURN' || tx['transaction_type'] == 'REQUEST') && 
            (tx['status'] == 'ACCEPTED' || tx['status'] == 'REJECTED' || tx['status'] == 'DENIED')
          ).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAction(String id, String status) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    try {
      await SupabaseService.updateStoreTransactionStatus(id, status);
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Task ${status.toLowerCase()} successfully')),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openDeliveryForm(Map<String, dynamic> tx) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StockTransactionForm(
          transactionType: 'DELIVERY',
          initialData: tx,
        ),
      ),
    ).then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pending Tasks'),
        actions: [
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                _buildSectionHeader('Pending Tasks', _pendingReturns.length),
                if (_pendingReturns.isEmpty)
                  _buildEmptyState('No pending requests or returns')
                else
                  _buildPendingList(),
                
                _buildSectionHeader('Task History', _returnHistory.length),
                if (_returnHistory.isEmpty)
                  _buildEmptyState('No history found')
                else
                  _buildHistoryList(),
                
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textBlack),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                count.toString(),
                style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return SliverToBoxAdapter(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(Icons.inbox_outlined, size: 48, color: AppColors.textGray.withOpacity(0.3)),
              const SizedBox(height: 16),
              Text(message, style: TextStyle(color: AppColors.textGray.withOpacity(0.5))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingList() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final tx = _pendingReturns[index];
          final date = DateTime.tryParse(tx['created_at']?.toString() ?? '') ?? DateTime.now();
          final dateStr = DateFormat('dd MMM, hh:mm a').format(date);
          final executiveName = tx['profiles']?['full_name'] ?? 'Unknown Executive';
          final isRequest = tx['transaction_type'] == 'REQUEST';

          return EntranceAnimation(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isRequest ? "PRODUCT REQUEST FROM" : "RETURN FROM",
                            style: TextStyle(
                              color: AppColors.textGray.withOpacity(0.6),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            executiveName,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Text(dateStr, style: const TextStyle(fontSize: 11, color: AppColors.textGray)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    tx['item_name'] ?? 'Unknown Item',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Quantity: ${tx['quantity']} ${tx['unit']}',
                    style: const TextStyle(color: AppColors.textBlack, fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  if (isRequest)
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => _handleAction(tx['id'], 'REJECTED'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Deny Request', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _openDeliveryForm(tx),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Process Delivery', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => _handleAction(tx['id'], 'REJECTED'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Deny Return', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _handleAction(tx['id'], 'ACCEPTED'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Accept Return', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          );
        }, childCount: _pendingReturns.length),
      ),
    );
  }

  Widget _buildHistoryList() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final tx = _returnHistory[index];
          final date = DateTime.tryParse(tx['created_at']?.toString() ?? '') ?? DateTime.now();
          final dateStr = DateFormat('dd MMM yyyy').format(date);
          final status = tx['status']?.toString().toUpperCase() ?? 'UNKNOWN';
          final isAccepted = status == 'ACCEPTED';
          final isRequest = tx['transaction_type'] == 'REQUEST';
          final executiveName = tx['profiles']?['full_name'] ?? 'Unknown';

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black.withOpacity(0.03)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isAccepted ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isAccepted ? Icons.check_circle_outline_rounded : Icons.cancel_outlined,
                    color: isAccepted ? Colors.green : Colors.red,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx['item_name'] ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        'From: $executiveName • $dateStr',
                        style: const TextStyle(color: AppColors.textGray, fontSize: 11),
                      ),
                      Text(
                        isRequest ? 'Product Request' : 'Stock Return',
                        style: TextStyle(color: isRequest ? Colors.blue : Colors.purple, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${tx['quantity']} ${tx['unit']}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      status,
                      style: TextStyle(
                        color: isAccepted ? Colors.green : Colors.red,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }, childCount: _returnHistory.length),
      ),
    );
  }
}
