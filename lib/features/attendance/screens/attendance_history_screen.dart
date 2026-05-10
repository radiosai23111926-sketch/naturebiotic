import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:nature_biotic/services/local_database_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AttendanceHistoryScreen extends StatefulWidget {
  final String? userId; // Null means current user
  const AttendanceHistoryScreen({super.key, this.userId});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _attendanceLogs = [];
  DateTime _selectedDate = DateTime.now();
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final remoteLogs = await SupabaseService.getAttendanceLogs(userId: widget.userId);
      List<Map<String, dynamic>> localLogs = [];
      
      if (widget.userId == null && !kIsWeb) {
        localLogs = await LocalDatabaseService.getAllAttendanceLogs();
      }
      
      if (mounted) {
        setState(() {
          // Merge and De-duplicate by ID
          final Map<String, Map<String, dynamic>> combinedMap = {};
          
          // Local logs (might be newer or pending sync)
          for (var log in localLogs) {
            if (log['id'] != null) {
              combinedMap[log['id'].toString()] = log;
            }
          }
          
          // Remote logs (overwrite if same ID, or add if new)
          for (var log in remoteLogs) {
            if (log['id'] != null) {
              combinedMap[log['id'].toString()] = log;
            }
          }
          
          _attendanceLogs = combinedMap.values.toList();
          
          // Sort by check-in time descending
          _attendanceLogs.sort((a, b) {
            final t1 = DateTime.parse(a['check_in_time']);
            final t2 = DateTime.parse(b['check_in_time']);
            return t2.compareTo(t1);
          });
        });

        final profile = await SupabaseService.getProfile();
        if (mounted) {
          setState(() {
            _userRole = profile?['role'];
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading history: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.userId == null ? 'My Logs' : 'Attendance History'),
        actions: [
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: _buildAttendanceList(),
              ),
            ),
    );
  }

  Widget _buildAttendanceList() {
    // 1. Filter logs for the selected month
    final filteredLogs = _attendanceLogs.where((log) {
      final date = DateTime.parse(log['check_in_time']);
      return date.month == _selectedDate.month && date.year == _selectedDate.year;
    }).toList();

    final stats = _calculateStats();
    
    if (filteredLogs.isEmpty) {
      return Column(
        children: [
          _buildStatsHeader(stats),
          const Expanded(child: Center(child: Text('No attendance records found for this month'))),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: filteredLogs.length + 1, // +1 for the header
      itemBuilder: (context, index) {
        if (index == 0) return _buildStatsHeader(stats);
        
        final log = filteredLogs[index - 1];
        final checkIn = DateTime.parse(log['check_in_time']);
        final checkOut = log['check_out_time'] != null ? DateTime.parse(log['check_out_time']) : null;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: AppColors.shadow.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
            ],
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.all(16),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat('MMM dd, yyyy').format(checkIn), style: const TextStyle(fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          _statusBadge(checkOut != null),
                          if (_userRole == 'admin') ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                              onPressed: () => _deleteLog(log),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _timeInfo('In', DateFormat('hh:mm a').format(checkIn)),
                      if (checkOut != null) ...[
                        const SizedBox(width: 40),
                        _timeInfo('Out', DateFormat('hh:mm a').format(checkOut)),
                      ],
                    ],
                  ),
                ],
              ),
              children: [
                const Divider(height: 1, indent: 16, endIndent: 16),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Photos & Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          if (log['check_in_photo'] != null)
                            Expanded(child: _photoColumn('Check In', log['check_in_photo'])),
                          if (log['check_out_photo'] != null) ...[
                            const SizedBox(width: 12),
                            Expanded(child: _photoColumn('Check Out', log['check_out_photo'])),
                          ],
                        ],
                      ),
                      if (log['check_in_location_lat'] != null) ...[
                        const SizedBox(height: 16),
                        _locationInfo(
                          'Check In Location', 
                          log['check_in_location_lat'], 
                          log['check_in_location_lng']
                        ),
                      ],
                      if (log['check_out_location_lat'] != null) ...[
                        const SizedBox(height: 12),
                        _locationInfo(
                          'Check Out Location', 
                          log['check_out_location_lat'], 
                          log['check_out_location_lng']
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Map<String, int> _calculateStats() {
    final now = DateTime.now();
    final targetMonth = _selectedDate.month;
    final targetYear = _selectedDate.year;
    
    // 1. Calculate Present Days (Unique dates in selected month)
    final Set<String> presentDates = {};
    for (var log in _attendanceLogs) {
      final date = DateTime.parse(log['check_in_time']);
      if (date.month == targetMonth && date.year == targetYear) {
        presentDates.add(DateFormat('yyyy-MM-dd').format(date));
      }
    }
    
    // 2. Calculate Working Days passed (Mon-Sat)
    int workingDaysPassed = 0;
    
    // Determine how many days to check in the month
    int daysToCount;
    if (targetYear == now.year && targetMonth == now.month) {
      daysToCount = now.day;
    } else {
      // Total days in that month
      daysToCount = DateTime(targetYear, targetMonth + 1, 0).day;
    }

    for (int i = 1; i <= daysToCount; i++) {
      final day = DateTime(targetYear, targetMonth, i);
      if (day.weekday != DateTime.sunday) {
        workingDaysPassed++;
      }
    }
    
    // 3. Absent Days
    int absentCount = workingDaysPassed - presentDates.length;
    if (absentCount < 0) absentCount = 0; // Safety
    
    return {
      'present': presentDates.length,
      'absent': absentCount,
    };
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + delta);
    });
  }

  Widget _buildStatsHeader(Map<String, int> stats) {
    final now = DateTime.now();
    final isCurrentMonth = _selectedDate.year == now.year && _selectedDate.month == now.month;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => _changeMonth(-1),
                    icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 28),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    DateFormat('MMMM yyyy').format(_selectedDate),
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: isCurrentMonth ? null : () => _changeMonth(1),
                    icon: Icon(
                      Icons.chevron_right_rounded, 
                      color: isCurrentMonth ? Colors.white38 : Colors.white, 
                      size: 28
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const Icon(Icons.calendar_month_rounded, color: Colors.white70, size: 24),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _statItem('Present', stats['present']!, Icons.check_circle_rounded),
              ),
              Container(width: 1, height: 40, color: Colors.white24),
              Expanded(
                child: _statItem('Absent', stats['absent']!, Icons.cancel_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, int value, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(
              value.toString(),
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
        ),
      ],
    );
  }

  Widget _statusBadge(bool isCompleted) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isCompleted ? 'Shift Completed' : 'Working',
        style: TextStyle(
          fontSize: 10, 
          color: isCompleted ? Colors.green : Colors.orange,
          fontWeight: FontWeight.bold
        ),
      ),
    );
  }

  Widget _photoColumn(String label, String url) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textGray)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            url, 
            height: 120, 
            width: double.infinity, 
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              height: 120,
              color: AppColors.secondary,
              child: const Icon(Icons.broken_image_rounded, color: AppColors.textGray),
            ),
          ),
        ),
      ],
    );
  }

  Widget _locationInfo(String label, double lat, double lng) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on_rounded, size: 16, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textGray)),
                Text('$lat, $lng', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _timeInfo(String label, String time) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textGray, fontSize: 11)),
        Text(time, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Future<void> _deleteLog(Map<String, dynamic> log) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Log'),
        content: const Text('Are you sure you want to delete this attendance record?'),
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
        await SupabaseService.deleteRecord('attendance', log['id']);
        _loadData();
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
