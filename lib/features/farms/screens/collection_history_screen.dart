import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:nature_biotic/services/local_database_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'add_collection_screen.dart';

class CollectionHistoryScreen extends StatefulWidget {
  final String farmId;
  final String farmName;
  final String? farmerName;

  const CollectionHistoryScreen({
    super.key,
    required this.farmId,
    required this.farmName,
    this.farmerName,
  });

  @override
  State<CollectionHistoryScreen> createState() => _CollectionHistoryScreenState();
}

class _CollectionHistoryScreenState extends State<CollectionHistoryScreen> {
  List<Map<String, dynamic>> _collections = [];
  bool _isLoading = true;
  double _totalCollected = 0.0;

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    setState(() => _isLoading = true);
    try {
      final all = await SupabaseService.getFarmCollections(widget.farmId);
      
      final total = all.fold(
        0.0,
        (sum, c) => sum + (double.tryParse(c['amount'].toString()) ?? 0.0),
      );
      
      if (mounted) {
        setState(() {
          _collections = all;
          _totalCollected = total;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error in _loadCollections: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr.toString());
      return DateFormat('dd MMM yyyy  •  hh:mm a').format(date);
    } catch (_) {
      return dateStr.toString();
    }
  }

  String _formatAmount(dynamic amount) {
    final val = double.tryParse(amount.toString()) ?? 0.0;
    final formatted = NumberFormat('#,##,##0.00', 'en_IN').format(val);
    return '₹$formatted';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Collections'),
        actions: [
          IconButton(
            onPressed: _loadCollections,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCollections,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Total summary card
                      _buildSummaryCard(),
                      const SizedBox(height: 28),

                      if (_collections.isEmpty)
                        _buildEmptyState()
                      else ...[
                        Text(
                          'Transaction History',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textBlack.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...List.generate(
                          _collections.length,
                          (i) => _buildCollectionCard(_collections[i]),
                        ),
                      ],

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'collection_fab',
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddCollectionScreen(
                farmId: widget.farmId,
                farmName: widget.farmName,
                farmerName: widget.farmerName,
              ),
            ),
          );
          if (result == true) _loadCollections();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Collection'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Collected',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatAmount(_totalCollected),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_collections.length} transaction${_collections.length == 1 ? '' : 's'} • ${widget.farmName}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionCard(Map<String, dynamic> collection) {
    final amount = double.tryParse(collection['amount'].toString()) ?? 0.0;
    final notes = collection['notes']?.toString();
    final farmerName = collection['farmer_name']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.green.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.payments_rounded,
              color: Colors.green,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (farmerName != null && farmerName.isNotEmpty)
                  Text(
                    farmerName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.textBlack,
                    ),
                  ),
                if (notes != null && notes.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    notes,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textGray,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  _formatDate(collection['created_at']),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textGray.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _formatAmount(amount),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.3),
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 56,
            color: AppColors.primary,
          ),
          SizedBox(height: 16),
          Text(
            'No Collections Yet',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: AppColors.textBlack,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Tap the + button to record an amount collected from this farm.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textGray, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
