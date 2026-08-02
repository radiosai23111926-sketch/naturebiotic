import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:nature_biotic/services/pdf_service.dart';
import 'package:nature_biotic/features/reports/screens/report_generator_screen.dart';
import 'package:nature_biotic/core/widgets/animations.dart';

class AdminWorkReportScreen extends StatefulWidget {
  final Map<String, dynamic>? initialEmployee;

  const AdminWorkReportScreen({super.key, this.initialEmployee});

  @override
  State<AdminWorkReportScreen> createState() => _AdminWorkReportScreenState();
}

class _AdminWorkReportScreenState extends State<AdminWorkReportScreen> {
  bool _isLoadingEmployees = true;
  bool _isLoadingReport = false;
  List<Map<String, dynamic>> _employees = [];
  Map<String, dynamic>? _selectedEmployee;

  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );

  // Filters for activity types
  final Map<String, bool> _activeFilters = {
    'Attendance': true,
    'Farmers Registered': true,
    'Farms Assigned': true,
    'Crop Reports': true,
    'Call Logs': true,
  };

  // Raw data from database
  Map<String, List<Map<String, dynamic>>> _reportData = {
    'attendance': [],
    'farmers': [],
    'farms': [],
    'reports': [],
    'calls': [],
  };

  // Processed activities for timeline
  List<Map<String, dynamic>> _allActivities = [];
  List<Map<String, dynamic>> _filteredActivities = [];

  // Summary counts
  int _attendanceCount = 0;
  int _farmersCount = 0;
  int _farmsCount = 0;
  int _reportsCount = 0;
  int _callsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoadingEmployees = true);
    try {
      final team = await SupabaseService.getTeamMembers();
      setState(() {
        _employees = team;
        _isLoadingEmployees = false;
        
        // Handle initial employee if passed
        if (widget.initialEmployee != null) {
          _selectedEmployee = _employees.firstWhere(
            (e) => e['id'] == widget.initialEmployee!['id'],
            orElse: () => widget.initialEmployee!,
          );
        } else if (_employees.isNotEmpty) {
          _selectedEmployee = _employees.first;
        }
      });

      if (_selectedEmployee != null) {
        _loadReportData();
      }
    } catch (e) {
      setState(() => _isLoadingEmployees = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading employees: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _loadReportData() async {
    if (_selectedEmployee == null) return;
    setState(() => _isLoadingReport = true);

    try {
      final data = await SupabaseService.getEmployeeWorkReportData(
        employeeId: _selectedEmployee!['id'],
        startDate: _dateRange.start,
        endDate: _dateRange.end,
      );

      setState(() {
        _reportData = data;
        _processActivities();
        _isLoadingReport = false;
      });
    } catch (e) {
      setState(() => _isLoadingReport = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading report: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _processActivities() {
    final List<Map<String, dynamic>> temp = [];

    // Process Attendance
    final attendanceList = _reportData['attendance'] ?? [];
    _attendanceCount = attendanceList.length;
    for (var a in attendanceList) {
      final checkInStr = a['check_in_time'] != null
          ? DateFormat('hh:mm a').format(DateTime.parse(a['check_in_time']))
          : null;
      final checkOutStr = a['check_out_time'] != null
          ? DateFormat('hh:mm a').format(DateTime.parse(a['check_out_time']))
          : null;

      final dateParsed = DateTime.parse(a['created_at'] ?? a['check_in_time'] ?? DateTime.now().toIso8601String());

      if (checkInStr != null) {
        temp.add({
          'type': 'Attendance Check-In',
          'category': 'Attendance',
          'dateTime': dateParsed,
          'time': DateFormat('dd MMM yyyy, hh:mm a').format(dateParsed),
          'description': 'Checked in at $checkInStr. Location: ${a['check_in_location'] ?? 'N/A'}',
          'icon': Icons.login_rounded,
          'color': Colors.green,
          'rawData': a,
        });
      }

      if (checkOutStr != null) {
        // Offset slightly to show checkout after checkin in descending list
        final checkOutDate = dateParsed.add(const Duration(seconds: 1));
        temp.add({
          'type': 'Attendance Check-Out',
          'category': 'Attendance',
          'dateTime': checkOutDate,
          'time': DateFormat('dd MMM yyyy, hh:mm a').format(checkOutDate),
          'description': 'Checked out at $checkOutStr. Location: ${a['check_out_location'] ?? 'N/A'}',
          'icon': Icons.logout_rounded,
          'color': Colors.redAccent,
          'rawData': a,
        });
      }
    }

    // Process Farmers
    final farmersList = _reportData['farmers'] ?? [];
    _farmersCount = farmersList.length;
    for (var f in farmersList) {
      final dateParsed = DateTime.parse(f['created_at'] ?? DateTime.now().toIso8601String());
      temp.add({
        'type': 'Farmer Registration',
        'category': 'Farmers Registered',
        'dateTime': dateParsed,
        'time': DateFormat('dd MMM yyyy, hh:mm a').format(dateParsed),
        'description': 'Registered new farmer: ${f['name'] ?? 'N/A'} (Mobile: ${f['mobile'] ?? 'N/A'}, Village: ${f['village'] ?? 'N/A'}, Supply Place: ${f['place_of_supply'] ?? 'N/A'})',
        'icon': Icons.person_add_rounded,
        'color': Colors.blue,
        'rawData': f,
      });
    }

    // Process Farms
    final farmsList = _reportData['farms'] ?? [];
    _farmsCount = farmsList.length;
    for (var f in farmsList) {
      final dateParsed = DateTime.parse(f['created_at'] ?? DateTime.now().toIso8601String());
      final farmerName = f['farmers']?['name'] ?? 'N/A';
      temp.add({
        'type': 'Farm Assignment/Creation',
        'category': 'Farms Assigned',
        'dateTime': dateParsed,
        'time': DateFormat('dd MMM yyyy, hh:mm a').format(dateParsed),
        'description': 'Assigned to Farm: ${f['name'] ?? 'N/A'} (Owner: $farmerName, Place: ${f['place'] ?? 'N/A'}, Area: ${f['area'] ?? 'N/A'} acres)',
        'icon': Icons.agriculture_rounded,
        'color': Colors.brown,
        'rawData': f,
      });
    }

    // Process Crop Reports
    final reportsList = _reportData['reports'] ?? [];
    _reportsCount = reportsList.length;
    for (var r in reportsList) {
      final dateParsed = DateTime.parse(r['created_at'] ?? DateTime.now().toIso8601String());
      final farmName = r['farms']?['name'] ?? 'N/A';
      final farmerName = r['farms']?['farmers']?['name'] ?? 'N/A';
      final cropName = r['crops']?['name'] ?? 'N/A';
      temp.add({
        'type': 'Crop Analysis Report',
        'category': 'Crop Reports',
        'dateTime': dateParsed,
        'time': DateFormat('dd MMM yyyy, hh:mm a').format(dateParsed),
        'description': 'Generated crop analysis for $farmerName\'s $farmName (Crop: $cropName, Problem: ${r['problem'] ?? 'N/A'}, Est. Cost: ₹${r['estimated_cost'] ?? '0'})',
        'icon': Icons.description_rounded,
        'color': AppColors.primary,
        'rawData': r,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReportGeneratorScreen(
                report: r,
                farmName: farmName,
                cropName: cropName,
                farmerName: farmerName,
              ),
            ),
          );
        },
      });
    }

    // Process Call Logs
    final callsList = _reportData['calls'] ?? [];
    _callsCount = callsList.length;
    for (var c in callsList) {
      final dateParsed = DateTime.parse(c['created_at'] ?? DateTime.now().toIso8601String());
      final duration = c['duration_seconds'] != null
          ? '${(c['duration_seconds'] / 60).floor()}m ${c['duration_seconds'] % 60}s'
          : 'N/A';
      final farmerName = c['farmers']?['name'] ?? 'N/A';
      temp.add({
        'type': 'Call Log',
        'category': 'Call Logs',
        'dateTime': dateParsed,
        'time': DateFormat('dd MMM yyyy, hh:mm a').format(dateParsed),
        'description': 'Called farmer $farmerName (Phone: ${c['phone_number'] ?? 'N/A'}, Duration: $duration, Summary: ${c['summary'] ?? 'No summary'})',
        'icon': Icons.call_rounded,
        'color': Colors.teal,
        'rawData': c,
      });
    }

    // Sort descending chronologically
    temp.sort((a, b) => (b['dateTime'] as DateTime).compareTo(a['dateTime'] as DateTime));
    _allActivities = temp;
    _filterTimeline();
  }

  void _filterTimeline() {
    setState(() {
      _filteredActivities = _allActivities.where((act) {
        final cat = act['category'] as String;
        return _activeFilters[cat] == true;
      }).toList();
    });
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _dateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textBlack,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _dateRange = picked);
      _loadReportData();
    }
  }

  void _exportReport() async {
    if (_selectedEmployee == null) return;
    
    // Prepare stats
    final stats = {
      'attendance': _attendanceCount,
      'farmers': _farmersCount,
      'farms': _farmsCount,
      'reports': _reportsCount,
      'calls': _callsCount,
    };

    // Prepare pdf activities
    final pdfActivities = _filteredActivities.map((act) => {
      'type': act['type'],
      'time': act['time'],
      'description': act['description'],
    }).toList();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generating PDF Report...')),
    );

    try {
      await PdfService.generateAndPrintWorkReport(
        employee: _selectedEmployee!,
        dateRange: _dateRange,
        stats: stats,
        activities: pdfActivities,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export PDF: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isWide = MediaQuery.sizeOf(context).width > 1100;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Employee Work Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadReportData,
            tooltip: 'Refresh Data',
          ),
          if (_selectedEmployee != null && !_isLoadingReport)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.primary),
              onPressed: _exportReport,
              tooltip: 'Export PDF',
            ),
        ],
      ),
      body: _isLoadingEmployees
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Column(
                    children: [
                      _buildFilterPanel(isWide),
                      const SizedBox(height: 20),
                      if (_selectedEmployee == null)
                        const Expanded(
                          child: Center(child: Text('No employees found to generate report.')),
                        )
                      else if (_isLoadingReport)
                        const Expanded(
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else ...[
                        _buildSummaryCards(isWide),
                        const SizedBox(height: 24),
                        Expanded(
                          child: _filteredActivities.isEmpty
                              ? _buildEmptyState()
                              : _buildTimeline(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildFilterPanel(bool isWide) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: AppColors.primary.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: isWide ? 2 : 1,
                child: DropdownButtonFormField<Map<String, dynamic>>(
                  value: _selectedEmployee,
                  decoration: const InputDecoration(
                    labelText: 'Select Employee',
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  items: _employees.map((emp) {
                    final name = emp['full_name'] ?? 'N/A';
                    final role = (emp['role'] ?? 'executive').toString().toUpperCase();
                    return DropdownMenuItem(
                      value: emp,
                      child: Text('$name ($role)'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedEmployee = val;
                    });
                    _loadReportData();
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: _selectDateRange,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primary.withOpacity(0.1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.date_range_rounded, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '${DateFormat('dd MMM').format(_dateRange.start)} - ${DateFormat('dd MMM').format(_dateRange.end)}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Activity Category Filters:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textGray),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _activeFilters.keys.map((filterName) {
                final isSelected = _activeFilters[filterName] == true;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(filterName),
                    selected: isSelected,
                    selectedColor: AppColors.primary.withOpacity(0.15),
                    checkmarkColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.primary : AppColors.textGray,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: AppColors.background,
                    side: BorderSide(
                      color: isSelected ? AppColors.primary : AppColors.textGray.withOpacity(0.15),
                    ),
                    onSelected: (val) {
                      setState(() {
                        _activeFilters[filterName] = val;
                      });
                      _filterTimeline();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(bool isWide) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = isWide ? 5 : 2;
        return GridView.count(
          shrinkWrap: true,
          crossAxisCount: count,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: isWide ? 1.8 : 2.2,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildStatCard('Attendance Logs', '$_attendanceCount check-ins', Icons.calendar_month_rounded, Colors.green),
            _buildStatCard('Farmers Registered', '$_farmersCount farmers', Icons.person_add_rounded, Colors.blue),
            _buildStatCard('Farms Assigned', '$_farmsCount farms', Icons.agriculture_rounded, Colors.brown),
            _buildStatCard('Crop Health Reports', '$_reportsCount reports', Icons.description_rounded, AppColors.primary),
            _buildStatCard('Call Logs Logged', '$_callsCount phone calls', Icons.call_rounded, Colors.teal),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.black.withOpacity(0.03)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textGray),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.textBlack),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    return ListView.builder(
      itemCount: _filteredActivities.length,
      padding: const EdgeInsets.only(bottom: 24),
      itemBuilder: (context, index) {
        final act = _filteredActivities[index];
        final type = act['type'] as String;
        final time = act['time'] as String;
        final desc = act['description'] as String;
        final icon = act['icon'] as IconData;
        final color = act['color'] as Color;
        final onTap = act['onTap'] as VoidCallback?;

        return EntranceAnimation(
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Timeline indicator
                Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 16),
                    ),
                    Expanded(
                      child: index == _filteredActivities.length - 1
                          ? const SizedBox(height: 16)
                          : Container(
                              width: 2,
                              color: Colors.black.withOpacity(0.06),
                            ),
                    ),
                  ],
                ),
                // Timeline card content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16.0, left: 8.0),
                    child: Card(
                      child: InkWell(
                        onTap: onTap,
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    type,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: color,
                                    ),
                                  ),
                                  Text(
                                    time,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textGray,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (act['category'] == 'Crop Reports')
                                _buildCropReportDetails(act['rawData'])
                              else
                                Text(
                                  desc,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textBlack,
                                    height: 1.4,
                                  ),
                                ),
                              if (onTap != null) ...[
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      'View Details',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: color,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(Icons.chevron_right_rounded, color: color, size: 16),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Map<String, dynamic> _parseReportDetails(Map<String, dynamic> report) {
    final String rawProblem = report['problem'] ?? '';
    final String rawCost = report['estimated_cost'] ?? '';

    // Clean raw markers from raw problem
    final problemCleaned = rawProblem.replaceAll(RegExp(r'--- Crop:[^-\n]+---'), '').trim();
    final List<String> problems = [];
    if (problemCleaned.isNotEmpty) {
      for (var line in problemCleaned.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        for (var p in trimmed.split(',')) {
          if (p.trim().isNotEmpty) {
            problems.add(p.trim());
          }
        }
      }
    }

    // Clean raw markers from raw cost
    final costCleaned = rawCost.replaceAll(RegExp(r'--- Crop:[^-\n]+---'), '').trim();
    final List<Map<String, String>> items = [];
    String grandTotal = '0';
    
    if (costCleaned.isNotEmpty) {
      for (var line in costCleaned.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        if (trimmed.toLowerCase().contains('grand total:')) {
          final match = RegExp(r'Grand Total:\s*₹?\s*([^\s]+)').firstMatch(trimmed);
          if (match != null) {
            grandTotal = match.group(1) ?? '0';
          } else {
            grandTotal = trimmed.replaceAll(RegExp(r'grand total:\s*', caseSensitive: false), '');
          }
          continue;
        }
        items.add({'text': trimmed});
      }
    }

    return {
      'problems': problems,
      'items': items,
      'grandTotal': grandTotal,
      'rawProblem': rawProblem,
      'rawCost': rawCost,
    };
  }

  Widget _buildCropReportDetails(Map<String, dynamic> report) {
    final farmerName = report['farms']?['farmers']?['name'] ?? 'N/A';
    final farmName = report['farms']?['name'] ?? 'N/A';
    final cropName = report['crops']?['name'] ?? 'N/A';

    final parsed = _parseReportDetails(report);
    final List<String> problems = List<String>.from(parsed['problems'] ?? []);
    final List<Map<String, String>> items = List<Map<String, String>>.from(parsed['items'] ?? []);
    final String grandTotal = parsed['grandTotal'] ?? '0';
    final String rawProblem = parsed['rawProblem'] ?? '';
    final String rawCost = parsed['rawCost'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.eco_rounded, size: 12, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    cropName,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'at $farmerName\'s $farmName',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textGray,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (problems.isNotEmpty) ...[
          const Text(
            'IDENTIFIED PROBLEMS:',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: AppColors.textGray,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          ...problems.map((prob) => Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Row(
                  children: [
                    const Icon(Icons.bug_report_rounded, color: Colors.orange, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        prob,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 12),
        ] else if (rawProblem.isNotEmpty) ...[
          const Text(
            'PROBLEMS IDENTIFIED:',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: AppColors.textGray,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            rawProblem,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
        ],

        if (items.isNotEmpty) ...[
          const Text(
            'RECOMMENDED INPUTS:',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: AppColors.textGray,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item['text'] ?? '',
                        style: const TextStyle(fontSize: 12, color: AppColors.textBlack),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 10),
          Divider(color: Colors.black.withOpacity(0.06), height: 1),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Estimated Cost:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textGray),
              ),
              Text(
                '₹$grandTotal',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ] else if (rawCost.isNotEmpty) ...[
          const Text(
            'ESTIMATED COST:',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: AppColors.textGray,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            rawCost,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.assignment_late_outlined, size: 48, color: AppColors.primary),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Activities Recorded',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try widening the date range or adjusting toggles.',
            style: TextStyle(color: AppColors.textGray, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
