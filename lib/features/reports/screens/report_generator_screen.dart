import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/pdf_service.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:nature_biotic/features/reports/screens/create_report_screen.dart';

class ReportGeneratorScreen extends StatefulWidget {
  final Map<String, dynamic>? report;
  final String? farmName;
  final String? cropName;
  final String? farmerName;

  const ReportGeneratorScreen({
    super.key,
    this.report,
    this.farmName,
    this.cropName,
    this.farmerName,
  });

  @override
  State<ReportGeneratorScreen> createState() => _ReportGeneratorScreenState();
}

class _ReportGeneratorScreenState extends State<ReportGeneratorScreen> {
  bool _isLoadingHistory = false;
  List<Map<String, dynamic>> _history = [];
  String? _userRole;
  bool _isVerified = false;

  @override
  void initState() {
    super.initState();
    _isVerified = widget.report?['is_verified'] == true;
    _loadUserRole();
    _loadHistory();
  }

  Future<void> _loadUserRole() async {
    final profile = await SupabaseService.getProfile();
    if (mounted) {
      setState(() {
        _userRole = profile?['role'];
      });
    }
  }

  Future<void> _loadHistory() async {
    final farmId = widget.report?['farm_id'];
    if (farmId == null) return;

    setState(() => _isLoadingHistory = true);
    try {
      final allReports = await SupabaseService.getReportsForFarm(
        farmId.toString(),
      );

      // Filter history to show only reports from the same farm,
      // excluding the current one and any future ones (if viewing an old report)
      final currentCreatedAt = widget.report?['created_at'];
      final currentDate =
          currentCreatedAt != null
              ? DateTime.parse(currentCreatedAt.toString())
              : DateTime.now();

      final currentId = widget.report?['id'];

      setState(() {
        _history =
            allReports.where((r) {
              if (currentId != null && r['id'] == currentId) return false;
              final rDate = DateTime.parse(r['created_at'].toString());
              return rDate.isBefore(currentDate);
            }).toList();
      });
    } catch (e) {
      debugPrint('Error loading report history: $e');
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return 'Today';
    try {
      final date = DateTime.parse(dateStr.toString());
      return '${date.day} ${_getMonthName(date.month)} ${date.year}';
    } catch (e) {
      return 'Today';
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    if (report == null) {
      return const Scaffold(body: Center(child: Text('No report data.')));
    }

    final currentHistory = report['previous_inputs'] ?? '';

    // Aggregate all history entries into a formatted string for the PDF export button logic
    String combinedHistory = currentHistory;
    if (_history.isNotEmpty) {
      combinedHistory += '\n\nHistorical Records:';
      for (var h in _history) {
        final hDate = _formatDate(h['created_at']);
        final hInputs = h['previous_inputs'] ?? 'No data';
        combinedHistory += '\n--- $hDate ---\n$hInputs';
      }
    }

    return Scaffold(
      backgroundColor: const Color(
        0xFFF5F5F5,
      ), // Slightly grayish to make the "paper" pop
      appBar: AppBar(title: const Text('Visit Report')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // The "Paper" Report
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ), // Sharp but soft edges like paper
                  child: Container(
                    padding: const EdgeInsets.all(
                      16.0,
                    ), // Further reduced for mobile
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBrandedHeader(report['created_at']),
                        const SizedBox(height: 24),
                        _buildInfoSection(
                          widget.farmerName ?? 'N/A',
                          widget.farmName ?? 'N/A',
                          widget.cropName ?? 'N/A',
                        ),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Problem Analysis'),
                        _buildProblemSection(report['problem'] ?? ''),

                        if (currentHistory.isNotEmpty ||
                            _history.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          _buildSectionTitle('Previous Inputs History'),
                          _buildHistorySection(currentHistory),
                        ],

                        const SizedBox(height: 24),
                        _buildSectionTitle('Recommended Products & Treatments'),
                        _buildRecommendationsTable(
                          report['recommendations'] ?? '',
                        ),

                        const SizedBox(height: 24),
                        _buildSectionTitle(
                          'Product Requirements & Estimations',
                        ),
                        _buildCostTable(report['estimated_cost'] ?? ''),

                        const SizedBox(height: 48),
                        _buildFooter(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                if (_userRole == 'manager' && !_isVerified) ...[
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        await SupabaseService.verifyItem(
                          'reports',
                          widget.report?['id'],
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Report Verified Successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          setState(() => _isVerified = true);
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Verification failed: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.verified_user_rounded),
                    label: const Text('Verify This Analysis'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 54),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Action Buttons
                if (_userRole == 'admin' || (_userRole != 'manager' && !_isVerified)) ...[
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreateReportScreen(existingReport: report),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Edit This Analysis'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      minimumSize: const Size(double.infinity, 54),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                ElevatedButton.icon(
                  onPressed: () async {
                    // Construct a modified report map that includes the combined history for the PDF
                    final reportForPdf = Map<String, dynamic>.from(report);
                    reportForPdf['previous_inputs'] = combinedHistory;

                    await PdfService.generateAndShare(
                      report: reportForPdf,
                      farmName: widget.farmName ?? 'Unknown Farm',
                      cropName: widget.cropName ?? 'Unknown Crop',
                      farmerName: widget.farmerName ?? 'Valued Farmer',
                    );
                  },
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: const Text('Share PDF Report'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    minimumSize: const Size(double.infinity, 54),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed:
                      () =>
                          Navigator.popUntil(context, (route) => route.isFirst),
                  icon: const Icon(Icons.home_rounded),
                  label: const Text('Back to Dashboard'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 54),
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandedHeader(dynamic createdAt) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 400;

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'NATURE BIOTIC',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Agricultural Analysis & Recommendation Report',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Date: ${_formatDate(createdAt)}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'NATURE BIOTIC',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Agricultural Analysis & Recommendation Report',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Date: ${_formatDate(createdAt)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoSection(String farmer, String farm, String crop) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: _infoItem('Farmer Name', farmer)),
          const SizedBox(width: 8),
          Expanded(child: _infoItem('Farm Name', farm)),
          const SizedBox(width: 8),
          Expanded(child: _infoItem('Crop Name', crop)),
        ],
      ),
    );
  }

  Widget _infoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: Colors.grey[600],
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFE8F5E9),
      ), // Light Green 100
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1B5E20),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildProblemSection(String problem) {
    if (problem.isEmpty) return const Text('No problems identified.');

    final List<Widget> cropSections = [];
    final rawChunks = problem.split('--- Crop: ');

    for (var chunk in rawChunks) {
      if (chunk.trim().isEmpty) continue;

      final parts = chunk.split(' ---\n');
      String cropName = 'Report';
      String problemContent = chunk;

      if (parts.length >= 2) {
        cropName = parts[0].trim();
        problemContent = parts[1].trim();
      }

      final List<Widget> problemWidgets = [];
      final problemItems = problemContent.split(', ');

      for (var item in problemItems) {
        if (item.trim().isEmpty) continue;
        problemWidgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _parseTextWithImages('• ${item.trim()}', fontSize: 14),
          ),
        );
      }

      cropSections.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (parts.length >= 2)
              Padding(
                padding: const EdgeInsets.only(bottom: 12, top: 4),
                child: Text(
                  'Crop: $cropName',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF1B5E20),
                  ),
                ),
              ),
            Wrap(spacing: 20, runSpacing: 10, children: problemWidgets),
            const SizedBox(height: 24),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: cropSections,
    );
  }

  Widget _parseTextWithImages(String text, {double fontSize = 13}) {
    if (text.isEmpty) return const SizedBox.shrink();

    final regex = RegExp(r'\{img:\s*(.*?)\}');
    final List<Widget> widgets = [];
    int lastMatchEnd = 0;
    final matches = regex.allMatches(text);

    if (matches.isEmpty) {
      return Text(text, style: TextStyle(fontSize: fontSize, height: 1.5));
    }

    for (final match in matches) {
      final beforeText = text.substring(lastMatchEnd, match.start).trim();
      if (beforeText.isNotEmpty) {
        widgets.add(Text(beforeText, style: TextStyle(fontSize: fontSize, height: 1.5)));
      }

      final url = match.group(1) ?? '';
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              url,
              height: 200,
              width: 300,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.grey),
            ),
          ),
        ),
      );
      lastMatchEnd = match.end;
    }

    final afterText = text.substring(lastMatchEnd).trim();
    if (afterText.isNotEmpty) {
      widgets.add(Text(afterText, style: TextStyle(fontSize: fontSize, height: 1.5)));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }

  Widget _buildRecommendationsTable(String recommendations) {
    final lines =
        recommendations.split('\n').where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) return const Text('No recommendations provided.');

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: MediaQuery.of(context).size.width - 64,
        ),
        child: Table(
          border: TableBorder.all(color: Colors.grey[300]!),
          columnWidths: const {
            0: FlexColumnWidth(2.5),
            1: FlexColumnWidth(2),
            2: FlexColumnWidth(1),
            3: FlexColumnWidth(1),
          },
          children: [
            // Header
            TableRow(
              decoration: const BoxDecoration(color: Color(0xFF2E7D32)),
              children:
                  ['Product', 'Application', 'Dose', 'Filler']
                      .map(
                        (h) => Padding(
                          padding: const EdgeInsets.all(10),
                          child: Text(
                            h,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      )
                      .toList(),
            ),
            // Rows
            ...lines.map((line) {
              final parts = line.split(' - ');
              if (parts.length < 2) {
                return TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(line),
                    ),
                    const SizedBox(),
                    const SizedBox(),
                    const SizedBox(),
                  ],
                );
              }

              final prodPart = parts[0];
              final detailsPart = parts[1];

              final prodName =
                  prodPart.contains('(')
                      ? prodPart.split('(')[0].trim()
                      : prodPart;
              final app =
                  prodPart.contains('(')
                      ? prodPart.split('(')[1].replaceAll(')', '').trim()
                      : '';

              final detailParts = detailsPart.split(', ');
              final dose = detailParts[0].replaceAll('Dose: ', '').trim();
              final filler =
                  detailParts.length > 1
                      ? detailParts[1].replaceAll('Filler: ', '').trim()
                      : '';

              return TableRow(
                children:
                    [prodName, app, dose, filler]
                        .map(
                          (t) => Padding(
                            padding: const EdgeInsets.all(10),
                            child: Text(
                              t,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        )
                        .toList(),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCostTable(String costs) {
    final lines = costs.split('\n').where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) return const Text('No estimation provided.');

    String grandTotal = '0';
    String nextVisit = 'N/A';
    List<List<String>> tableData = [];

    for (var line in lines) {
      if (line.startsWith('Grand Total:')) {
        grandTotal = line.split(': ')[1];
        continue;
      }
      if (line.startsWith('Next Visit:')) {
        nextVisit = line.split(': ')[1];
        continue;
      }

      final parts = line.split(' - ');
      if (parts.length < 2) continue;

      final prodPart = parts[0];
      final detailsPart = parts[1];

      final prodName =
          prodPart.contains('(Pkg:')
              ? prodPart.split('(Pkg:')[0].trim()
              : prodPart;
      final pkg =
          prodPart.contains('(Pkg:')
              ? prodPart.split('(Pkg:')[1].replaceAll(')', '').trim()
              : '';

      final detailParts = detailsPart.split(', ');
      final qty =
          detailParts.isNotEmpty
              ? detailParts[0].replaceAll('Qty: ', '').trim()
              : '';
      final mrp =
          detailParts.length > 1
              ? detailParts[1].replaceAll('MRP: ', '').trim()
              : '';
      final offer =
          detailParts.length > 2
              ? detailParts[2].replaceAll('Offer: ', '').trim()
              : '';
      final total =
          detailParts.length > 3
              ? detailParts[3].replaceAll('Total: ', '').trim()
              : '';

      tableData.add([prodName, pkg, qty, mrp, offer, total]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            border: TableBorder.all(color: Colors.grey[300]!),
            defaultColumnWidth: const IntrinsicColumnWidth(),
            columnWidths: const {
              0: FixedColumnWidth(100),
              1: FixedColumnWidth(40),
              2: FixedColumnWidth(30),
            },
            children: [
              // Header
              TableRow(
                decoration: const BoxDecoration(color: Color(0xFF2E7D32)),
                children:
                    ['Product', 'Size', 'Qty', 'MRP', 'Price', 'Value']
                        .map(
                          (h) => Padding(
                            padding: const EdgeInsets.all(6),
                            child: Text(
                              h,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        )
                        .toList(),
              ),
              // Rows
              ...tableData.map(
                (row) => TableRow(
                  children:
                      row
                          .map(
                            (t) => Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(
                                t,
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                          )
                          .toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Next Visit Date: $nextVisit',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ),
            Text(
              'GRAND TOTAL: $grandTotal',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B5E20),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHistorySection(String currentHistory) {
    final List<Widget> currentVisitWidgets = [];

    if (currentHistory.isEmpty) {
      currentVisitWidgets.add(const Text('No data provided.', style: TextStyle(fontSize: 13)));
    } else {
      final cropChunks = currentHistory.split('--- Crop: ');
      for (var chunk in cropChunks) {
        if (chunk.trim().isEmpty) continue;
        final parts = chunk.split(' ---\n');
        if (parts.length >= 2) {
          final cropName = parts[0].trim();
          final content = parts[1].trim();
          currentVisitWidgets.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Crop: $cropName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
                  const SizedBox(height: 4),
                  _parseTextWithImages(content, fontSize: 12),
                ],
              ),
            ),
          );
        } else {
          currentVisitWidgets.add(_parseTextWithImages(chunk, fontSize: 12));
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history_rounded, color: AppColors.primary, size: 24),
              SizedBox(width: 12),
              Text(
                'Current Visit Observations',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textBlack,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...currentVisitWidgets,
          if (_isLoadingHistory)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(minHeight: 2),
            )
          else if (_history.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(),
            ),
            const Text(
              'Historical Logs',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            ..._history.map(
              (h) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(h['created_at']),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: AppColors.textGray,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _parseTextWithImages(h['previous_inputs'] ?? 'No data', fontSize: 12),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        const Divider(thickness: 1),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Expanded(
              child: Text(
                'Thank you for choosing Nature Biotic for a sustainable future.',
                style: TextStyle(
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
