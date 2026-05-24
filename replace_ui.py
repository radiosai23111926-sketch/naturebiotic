import re
import os

filepath = 'd:/Personal/naturebiotic/lib/features/dashboard/screens/farm_sales_list_screen.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# Add dart:ui import
if "import 'dart:ui';" not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'dart:ui';\nimport 'package:flutter/material.dart';")

# Replace _buildFarmCard
farm_card_start = content.find('  Widget _buildFarmCard(Map<String, dynamic> data) {')
farm_card_end = content.find('  Widget _buildMiniBadge(IconData icon, String label, Color color) {')

# Replace _buildFlatCollectionCard
flat_card_start = content.find('  Widget _buildFlatCollectionCard(Map<String, dynamic> log, Map<String, dynamic> farmData) {')
flat_card_end = content.find('  Widget _buildSummarySection() {')

new_farm_card = """  Widget _buildFarmCard(Map<String, dynamic> data) {
    double displayValue = 0;
    String label = '';
    Color valueColor = AppColors.primary;
    Color blobColor1 = Colors.greenAccent;
    Color blobColor2 = Colors.teal;

    if (widget.mode == 'SALES') {
      displayValue = data['total_revenue'];
      label = 'Revenue';
      blobColor1 = const Color(0xFF00E676);
      blobColor2 = const Color(0xFF1DE9B6);
    } else if (widget.mode == 'COLLECTION') {
      displayValue = data['total_collection'];
      label = 'Collected';
      valueColor = Colors.teal;
      blobColor1 = const Color(0xFF00B0FF);
      blobColor2 = const Color(0xFF00E5FF);
    } else if (widget.mode == 'OUTSTANDING') {
      displayValue = data['total_revenue'] - data['total_collection'];
      label = 'Outstanding';
      valueColor = Colors.orange;
      blobColor1 = const Color(0xFFFF9100);
      blobColor2 = const Color(0xFFFF3D00);
    }

    final farmId = data['farm_id']?.toString() ?? '';
    final isExpanded = _expandedFarmIds.contains(farmId);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF121212), // Deep dark base
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Vibrant Mesh Gradient Blobs
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    blobColor1.withOpacity(0.6),
                    blobColor1.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    blobColor2.withOpacity(0.5),
                    blobColor2.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          // Glassmorphism blur layer
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          // Foreground Content
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Glowing left edge
                Container(
                  width: 6,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [blobColor1, blobColor2],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: blobColor1.withOpacity(0.5),
                        blurRadius: 10,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
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
                              // Floating Icon
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E1E),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: blobColor1.withOpacity(0.3),
                                      blurRadius: 15,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  widget.mode == 'COLLECTION'
                                      ? Icons.payments_rounded
                                      : Icons.agriculture_rounded,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['farmer_name']?.toString() ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                        color: Colors.white,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      data['farm_name']?.toString() ?? '',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.location_on_rounded,
                                          size: 13,
                                          color: Colors.white.withOpacity(0.5),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            data['location']?.toString() ?? 'N/A',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.5),
                                              fontSize: 12,
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
                                        _buildMiniBadge(
                                          Icons.grass_rounded,
                                          data['crop_name']?.toString() ?? 'No Crop',
                                          blobColor1,
                                        ),
                                        if (widget.mode == 'SALES' || widget.mode == 'OUTSTANDING')
                                          _buildMiniBadge(
                                            Icons.inventory_2_outlined,
                                            '${data['total_items'].toInt()} Items',
                                            Colors.white70,
                                          ),
                                        if (data['total_returned'] > 0 && widget.mode == 'SALES')
                                          _buildMiniBadge(
                                            Icons.replay_circle_filled_rounded,
                                            '${data['total_returned'].toInt()} Returned',
                                            const Color(0xFFFF5252),
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
                                  // Neon glowing amount button
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: blobColor1.withOpacity(0.5),
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: blobColor1.withOpacity(0.3),
                                          blurRadius: 10,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          currencyFormat.format(displayValue),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          isExpanded
                                              ? Icons.keyboard_arrow_up_rounded
                                              : Icons.keyboard_arrow_down_rounded,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    label.toUpperCase(),
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.6),
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  if (widget.mode == 'SALES' || widget.mode == 'OUTSTANDING') ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1E1E1E),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.2),
                                          width: 1,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: blobColor1.withOpacity(0.2),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                      child: IconButton(
                                        padding: const EdgeInsets.all(8),
                                        constraints: const BoxConstraints(),
                                        icon: Icon(
                                          Icons.file_download_outlined,
                                          color: blobColor1,
                                          size: 18,
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
                        // Balances
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
                                Divider(height: 1, indent: 20, endIndent: 20, color: Colors.white.withOpacity(0.1)),
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
                                          color: Colors.black.withOpacity(0.3),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.inventory_2_rounded, size: 12, color: blobColor1),
                                            const SizedBox(width: 6),
                                            Text(
                                              f"{it['item']} ({it['unit']}) : ",
                                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.8)),
                                            ),
                                            Text(
                                              f"{qty.toInt()}",
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
                        // Logs
                        Builder(
                          builder: (context) {
                            final rawLogs = data['logs'];
                            final logs = (rawLogs is List) ? rawLogs : [];
                            if (logs.isEmpty) return const SizedBox.shrink();
                            return Column(
                              children: [
                                Divider(height: 1, indent: 20, endIndent: 20, color: Colors.white.withOpacity(0.1)),
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
"""

# Small fix on f-strings in python string literal (dart requires $)
new_farm_card = new_farm_card.replace('f"{it', "'${it").replace('}) : ",', '}) : \',').replace('f"{qty', "'${qty").replace('.toInt()}",', '.toInt()}\',')


new_flat_card = """  Widget _buildFlatCollectionCard(Map<String, dynamic> log, Map<String, dynamic> farmData) {
    final amt = double.tryParse(log['amount']?.toString() ?? '0') ?? 0.0;
    final date = _formatDate(log['created_at']);
    
    // Dark premium colors for Collection
    Color blobColor1 = const Color(0xFF00B0FF);
    Color blobColor2 = const Color(0xFF00E5FF);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Vibrant Mesh Gradient Blobs
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    blobColor1.withOpacity(0.6),
                    blobColor1.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    blobColor2.withOpacity(0.5),
                    blobColor2.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          // Glassmorphism blur layer
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Glowing left edge
                Container(
                  width: 6,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [blobColor1, blobColor2],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: blobColor1.withOpacity(0.5),
                        blurRadius: 10,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Floating Icon
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: blobColor1.withOpacity(0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.payments_rounded,
                            color: Colors.white,
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
                                  fontSize: 16,
                                  color: Colors.white,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                farmData['farm_name']?.toString() ?? '',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on_rounded,
                                    size: 13,
                                    color: Colors.white.withOpacity(0.5),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      farmData['location']?.toString() ?? 'N/A',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.5),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildMiniBadge(
                                    Icons.grass_rounded,
                                    farmData['crop_name']?.toString() ?? 'No Crop',
                                    blobColor1,
                                  ),
                                  _buildMiniBadge(
                                    Icons.receipt_long_rounded,
                                    log['receipt_no']?.toString() ?? 'No Receipt',
                                    Colors.white70,
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
                            // Neon glowing amount
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: blobColor1.withOpacity(0.5),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: blobColor1.withOpacity(0.3),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Text(
                                '+${currencyFormat.format(amt)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'COLLECTED',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              date,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white.withOpacity(0.5),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E1E1E),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: blobColor1.withOpacity(0.2),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: IconButton(
                                padding: const EdgeInsets.all(8),
                                constraints: const BoxConstraints(),
                                icon: Icon(
                                  Icons.print_outlined,
                                  color: blobColor1,
                                  size: 18,
                                ),
                                tooltip: 'Print Receipt',
                                onPressed: () {
                                  _printCollectionReceipt(log, farmData);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
"""

if farm_card_start != -1 and farm_card_end != -1:
    content = content[:farm_card_start] + new_farm_card + "\n" + content[farm_card_end:]

# Re-find flat collection card after replacement
flat_card_start = content.find('  Widget _buildFlatCollectionCard(Map<String, dynamic> log, Map<String, dynamic> farmData) {')
next_widget = content.find('  Widget _build', flat_card_start + 50)

if next_widget != -1:
    content = content[:flat_card_start] + new_flat_card + "\n" + content[next_widget:]

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
