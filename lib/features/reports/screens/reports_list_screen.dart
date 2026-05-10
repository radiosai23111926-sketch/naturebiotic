import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/features/reports/screens/create_report_screen.dart';
import 'package:nature_biotic/features/reports/screens/report_generator_screen.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:nature_biotic/services/local_database_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';

class ReportsListScreen extends StatefulWidget {
  const ReportsListScreen({super.key});

  @override
  State<ReportsListScreen> createState() => _ReportsListScreenState();
}

class _ReportsListScreenState extends State<ReportsListScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _reports = [];
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    try {
      final remoteReports = await SupabaseService.getReports();
      List<Map<String, dynamic>> allReports = [];

      if (!kIsWeb) {
        final localReports = await LocalDatabaseService.getData(
          'reports',
          columns: [
            'id',
            'farm_id',
            'crop_id',
            'problem',
            'previous_inputs',
            'recommendations',
            'estimated_cost',
            'signature_url',
            'created_by',
            'created_at',
          ],
        );
        final localFarms = await LocalDatabaseService.getData('farms');
        final localCrops = await LocalDatabaseService.getData('crops');
        final localFarmers = await LocalDatabaseService.getData('farmers');

        // Create mapping for fast lookup
        final farmMap = {for (var f in localFarms) f['id'].toString(): f};
        final cropMap = {for (var c in localCrops) c['id'].toString(): c};
        final farmerMap = {for (var f in localFarmers) f['id'].toString(): f};

        // Transform local reports to match Supabase structure
        final transformedLocal =
            localReports.map((report) {
              final farmId = report['farm_id']?.toString();
              final cropId = report['crop_id']?.toString();
              final farm = farmMap[farmId] ?? {};
              final farmerId = farm['farmer_id']?.toString();
              final farmer = farmerMap[farmerId] ?? {};

              return {
                ...report,
                'is_local': true,
                'farms': {
                  'name': farm['name'],
                  'farmers': {'name': farmer['name']},
                },
                'crops': {'name': cropMap[cropId]?['name']},
              };
            }).toList();

        // Merge and De-duplicate using 'id'
        final Map<String, Map<String, dynamic>> combined = {};
        for (var r in remoteReports) {
          combined[r['id'].toString()] = r;
        }
        for (var r in transformedLocal) {
          combined[r['id'].toString()] = r;
        }

        allReports = combined.values.toList();
      } else {
        allReports = remoteReports;
      }

      // Sort by date descending
      allReports.sort(
        (a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''),
      );

      if (mounted) {
        final profile = await SupabaseService.getProfile();
        setState(() {
          _reports = allReports;
          _userRole = profile?['role'];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading reports: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr.toString());
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Analysis Reports'),
        actions: [
          IconButton(
            onPressed: _loadReports,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _reports.isEmpty
              ? _buildEmptyState()
              : _buildReportsList(),
      floatingActionButton:
          _reports.isNotEmpty && _userRole != 'manager'
              ? FloatingActionButton(
                heroTag: 'reports_fab',
                onPressed:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CreateReportScreen(),
                      ),
                    ).then((_) => _loadReports()),
                child: const Icon(Icons.add_rounded),
              )
              : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.description_outlined,
              size: 64,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Reports Generated Yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start a new analysis for your farms',
            style: TextStyle(color: AppColors.textGray),
          ),
          if (_userRole != 'manager')
            const SizedBox(height: 32),
          if (_userRole != 'manager')
            ElevatedButton.icon(
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateReportScreen(),
                    ),
                  ).then((_) => _loadReports()),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Generate New Report'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReportsList() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _reports.length,
          itemBuilder: (context, index) {
            final report = _reports[index];
            final farmName = report['farms']?['name'] ?? 'Unknown Farm';
            final cropName = report['crops']?['name'] ?? 'Unknown Crop';
            final farmerName =
                report['farms']?['farmers']?['name'] ?? 'Valued Farmer';
            final date = _formatDate(report['created_at']);

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: const CircleAvatar(
                  backgroundColor: AppColors.secondary,
                  child: Icon(
                    Icons.description_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                title: Text(
                  farmerName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$farmName • $cropName',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                    ),
                    Text(
                      date,
                      style: const TextStyle(fontSize: 11, color: AppColors.textGray),
                    ),
                    if (report['is_verified'] != true) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.orange,
                                width: 0.5,
                              ),
                            ),
                            child: const Text(
                              'PENDING',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.orange,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                    ],
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_userRole == 'admin' || (_userRole != 'manager' && report['is_verified'] != true))
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CreateReportScreen(existingReport: report),
                            ),
                          ).then((_) => _loadReports());
                        },
                      ),
                    if (_userRole == 'admin')
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                        onPressed: () => _handleDeleteReport(report),
                      ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.primary,
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => ReportGeneratorScreen(
                            report: report,
                            farmName: farmName,
                            cropName: cropName,
                            farmerName: farmerName,
                          ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _handleDeleteReport(Map<String, dynamic> report) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Report'),
        content: const Text('Are you sure you want to delete this analysis report?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await SupabaseService.deleteRecord('reports', report['id']);
        _loadReports();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Report deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}
