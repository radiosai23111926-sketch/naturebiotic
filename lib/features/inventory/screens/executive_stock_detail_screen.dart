import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/core/widgets/animations.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:intl/intl.dart';

class ExecutiveStockDetailScreen extends StatefulWidget {
  final String executiveId;
  final String executiveName;

  const ExecutiveStockDetailScreen({
    super.key, 
    required this.executiveId, 
    required this.executiveName
  });

  @override
  State<ExecutiveStockDetailScreen> createState() => _ExecutiveStockDetailScreenState();
}

class _ExecutiveStockDetailScreenState extends State<ExecutiveStockDetailScreen> {
  bool _isLoading = true;
  Map<String, Map<String, double>> _stockInHand = {};
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final stock = await SupabaseService.getDetailedExecutiveStock(userId: widget.executiveId);
      final history = await SupabaseService.getExecutiveTransactions(widget.executiveId);
      
      if (mounted) {
        setState(() {
          _stockInHand = stock;
          _history = history;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isWide = MediaQuery.of(context).size.width > 900;
    
    Widget content = CustomScrollView(
      slivers: [
        _buildSummarySection(isWide),
        _buildInventorySection(isWide),
        _buildHistorySection(isWide),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );

    if (isWide) {
      content = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: content,
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('${widget.executiveName}\'s Stock'),
        actions: [
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: content,
            ),
    );
  }

  Widget _buildSummarySection(bool isWide) {
    double totalUnits = 0;
    _stockInHand.forEach((product, variants) {
      variants.forEach((unit, qty) {
        if (qty > 0) totalUnits += qty;
      });
    });

    return SliverToBoxAdapter(
      child: EntranceAnimation(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, Color(0xFF2E7D32)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Total Stock in Hand',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                '$totalUnits Units',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 1,
                color: Colors.white24,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _summaryStat('Unique Items', _stockInHand.length.toString()),
                  _summaryStat('Transactions', _history.length.toString()),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildInventorySection(bool isWide) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              'Item Breakdown',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          if (_stockInHand.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Center(child: Text('No stock items currently held.')),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: _stockInHand.length,
              itemBuilder: (context, index) {
                final productName = _stockInHand.keys.elementAt(index);
                final variants = _stockInHand[productName]!;
                
                double productTotal = 0;
                variants.forEach((_, q) {
                  if (q > 0) productTotal += q;
                });

                return Container(
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
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 20),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                productName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                            Text(
                              productTotal.toStringAsFixed(0),
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Wrap(
                          spacing: 24,
                          runSpacing: 12,
                          children: variants.entries.where((v) => v.value > 0).map((v) {
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
                                  v.value.toStringAsFixed(0),
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
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildHistorySection(bool isWide) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Text(
              'Activity History',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          if (_history.isEmpty)
            const Center(child: Text('No recent activity recorded.'))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: _history.length,
              itemBuilder: (context, index) {
                final tx = _history[index];
                return _buildHistoryCard(tx);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> tx) {
    final type = tx['transaction_type']?.toString().toUpperCase();
    final category = tx['category']; // 'store' or 'field'
    
    Color color = Colors.blue;
    IconData icon = Icons.info_outline_rounded;
    String label = type ?? 'UNKNOWN';

    if (category == 'store') {
      if (type == 'DELIVERY') {
        color = Colors.orange;
        icon = Icons.local_shipping_rounded;
        label = 'RECEIVED FROM STORE';
      } else if (type == 'RETURN') {
        color = Colors.purple;
        icon = Icons.keyboard_return_rounded;
        label = 'RETURNED TO STORE';
      }
    } else {
      // Field usage
      color = Colors.red;
      icon = Icons.outbox_rounded;
      label = 'USED AT FIELD';
      if (tx['farms'] != null) {
        label = 'USED AT ${tx['farms']['name']}';
      }
    }

    final date = DateTime.tryParse(tx['created_at']?.toString() ?? '') ?? DateTime.now();
    final dateStr = DateFormat('dd MMM, hh:mm a').format(date);
    final qty = tx['quantity'];
    final unit = tx['unit'] ?? 'Units';

    return EntranceAnimation(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
                          text: '(${unit.toString().split(' {₹')[0]})',
                          style: TextStyle(
                            color: AppColors.textGray.withOpacity(0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(dateStr, style: const TextStyle(color: AppColors.textGray, fontSize: 10)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (category == 'store' && type == 'DELIVERY' ? Colors.green : Colors.red).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (category == 'store' && type == 'DELIVERY' ? Colors.green : Colors.red).withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Text(
                category == 'store' && type == 'DELIVERY' ? '+$qty' : '-$qty',
                style: TextStyle(
                  color: category == 'store' && type == 'DELIVERY' ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
