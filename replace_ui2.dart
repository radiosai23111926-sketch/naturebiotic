import 'dart:io';

void main() {
  final file = File('d:/Personal/naturebiotic/lib/features/dashboard/screens/farm_sales_list_screen.dart');
  String content = file.readAsStringSync();

  final farmCardStart = content.indexOf('  Widget _buildFarmCard(Map<String, dynamic> data) {');
  final farmCardEnd = content.indexOf('  Widget _buildMiniBadge(IconData icon, String label, Color color) {');

  final flatCardStart = content.indexOf('  Widget _buildFlatCollectionCard(Map<String, dynamic> log, Map<String, dynamic> farmData) {');
  final flatCardEnd = content.indexOf('  Future<void> _printFilteredReceipts(');

  final newFarmCard = r'''  Widget _buildFarmCard(Map<String, dynamic> data) {
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
                                      Text(
                                        data['crop_name']?.toString() ?? 'No Crop',
                                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
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
                                        Text(
                                          '${data['total_items'].toInt()} Items',
                                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
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
''';

  final newFlatCard = r'''  Widget _buildFlatCollectionCard(Map<String, dynamic> log, Map<String, dynamic> farmData) {
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
                                Text(
                                  farmData['crop_name']?.toString() ?? 'No Crop',
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
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
                                Text(
                                  log['receipt_no']?.toString() ?? 'No Receipt',
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
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
          ),
        ],
      ),
    );
  }
''';

  if (farmCardStart != -1 && farmCardEnd != -1) {
    content = content.replaceRange(farmCardStart, farmCardEnd, newFarmCard + '\n');
  }

  // Find flat collection card in updated content
  final flatCardStartNew = content.indexOf('  Widget _buildFlatCollectionCard(Map<String, dynamic> log, Map<String, dynamic> farmData) {');
  final flatCardEndNew = content.indexOf('  Future<void> _printFilteredReceipts(', flatCardStartNew);

  if (flatCardStartNew != -1 && flatCardEndNew != -1) {
    content = content.replaceRange(flatCardStartNew, flatCardEndNew, newFlatCard + '\n');
  }

  // Also replace `_buildInnerLogItem` to use withValues and white text since the background is now colored
  final logItemStart = content.indexOf('  Widget _buildInnerLogItem(');
  final logItemEnd = content.indexOf('  Widget _buildEmptyState() {', logItemStart) != -1 
      ? content.indexOf('  Widget _buildEmptyState() {', logItemStart) 
      : content.indexOf('  Widget _buildFlatCollectionCard', logItemStart);

  file.writeAsStringSync(content);
}
