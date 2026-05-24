import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nature_biotic/core/theme.dart';

class VisitCalendarScreen extends StatefulWidget {
  final List<dynamic> reminders;
  final List<dynamic> allFarms;
  final List<dynamic> allCrops;
  final List<dynamic> allFarmers;
  final bool isListView;

  const VisitCalendarScreen({
    super.key,
    required this.reminders,
    required this.allFarms,
    required this.allCrops,
    required this.allFarmers,
    this.isListView = false,
  });

  @override
  State<VisitCalendarScreen> createState() => _VisitCalendarScreenState();
}

class _VisitCalendarScreenState extends State<VisitCalendarScreen> {
  DateTime _selectedDate = DateTime.now();
  late List<DateTime> _dates;
  final ScrollController _dateScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    _generateDates();
    
    // Scroll to today after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToToday();
    });
  }

  void _generateDates() {
    // Generate dates for 3 months (last month, this month, next month)
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - 1, 1);
    final end = DateTime(now.year, now.month + 2, 0);
    
    _dates = [];
    for (int i = 0; i <= end.difference(start).inDays; i++) {
      _dates.add(start.add(Duration(days: i)));
    }
  }

  void _scrollToToday() {
    final todayIndex = _dates.indexWhere((d) => 
      d.year == _selectedDate.year && 
      d.month == _selectedDate.month && 
      d.day == _selectedDate.day
    );
    
    if (todayIndex != -1) {
      _dateScrollController.animateTo(
        todayIndex * 70.0 - 20, // 70 is card width + margin
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  List<dynamic> _getVisitsForSelectedDate() {
    return widget.reminders.where((reminder) {
      try {
        final date = DateTime.parse(reminder['follow_up_date']);
        return date.year == _selectedDate.year && 
               date.month == _selectedDate.month && 
               date.day == _selectedDate.day;
      } catch (_) {
        return false;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final visits = widget.isListView ? widget.reminders : _getVisitsForSelectedDate();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.isListView ? 'Upcoming Visits' : 'Visit Schedule'),
        actions: [
          if (!widget.isListView)
            IconButton(
              onPressed: () {
                setState(() => _selectedDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day));
                _scrollToToday();
              },
              icon: const Icon(Icons.today_rounded, color: AppColors.primary),
            ),
        ],
      ),
      body: Column(
        children: [
          if (!widget.isListView) ...[
            _buildMonthHeader(),
            _buildDateScroller(),
          ],
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
                child: visits.isEmpty 
                  ? _buildEmptyState()
                  : _buildVisitsList(visits),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Text(
            DateFormat('MMMM yyyy').format(_selectedDate),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textBlack),
          ),
        ],
      ),
    );
  }

  Widget _buildDateScroller() {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        controller: _dateScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const BouncingScrollPhysics(),
        itemCount: _dates.length,
        itemBuilder: (context, index) {
          final date = _dates[index];
          final isSelected = date.year == _selectedDate.year && 
                            date.month == _selectedDate.month && 
                            date.day == _selectedDate.day;
          final isToday = date.year == DateTime.now().year && 
                         date.month == DateTime.now().month && 
                         date.day == DateTime.now().day;

          return GestureDetector(
            onTap: () => setState(() => _selectedDate = date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 60,
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                ],
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.grey.withOpacity(0.1),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('EEE').format(date),
                    style: TextStyle(
                      color: isSelected ? Colors.white70 : AppColors.textGray,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date.day.toString(),
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textBlack,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isToday && !isSelected)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
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
              color: AppColors.primary.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.event_available_rounded, size: 64, color: AppColors.primary.withOpacity(0.2)),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Visits Scheduled',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textBlack),
          ),
          const SizedBox(height: 8),
          Text(
            'Enjoy your day or schedule a new visit.',
            style: TextStyle(color: AppColors.textGray.withOpacity(0.8), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitsList(List<dynamic> visits) {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      physics: const BouncingScrollPhysics(),
      itemCount: visits.length,
      itemBuilder: (context, index) {
        final reminder = visits[index];
        
        String displayName = 'Unknown';
        String subName = 'General Checkup';
        String ownerName = 'N/A';
        
        final bool isManagerReminder = reminder['reminder_type'] != null;
        
        if (isManagerReminder) {
          displayName = reminder['title'] ?? 'Unknown';
          subName = reminder['subtitle'] ?? '';
          final type = reminder['reminder_type'];
          final data = reminder['data'] ?? <String, dynamic>{};
          
          if (type == 'farmer') {
            ownerName = data['name'] ?? 'N/A';
          } else if (type == 'farm') {
            final farmer = widget.allFarmers.firstWhere(
              (f) => f['id'] == data['farmer_id'],
              orElse: () => <String, dynamic>{},
            );
            ownerName = farmer['name'] ?? 'N/A';
          } else if (type == 'crop') {
            final farm = widget.allFarms.firstWhere(
              (f) => f['id'] == data['farm_id'],
              orElse: () => <String, dynamic>{},
            );
            final farmer = widget.allFarmers.firstWhere(
              (f) => f['id'] == farm['farmer_id'],
              orElse: () => <String, dynamic>{},
            );
            ownerName = farmer['name'] ?? 'N/A';
          } else if (type == 'report') {
            final farm = widget.allFarms.firstWhere(
              (f) => f['id'] == data['farm_id'],
              orElse: () => <String, dynamic>{},
            );
            final farmer = widget.allFarmers.firstWhere(
              (f) => f['id'] == farm['farmer_id'],
              orElse: () => <String, dynamic>{},
            );
            ownerName = farmer['name'] ?? 'N/A';
          }
        } else {
          // Executive Path
          final farm = widget.allFarms.firstWhere(
            (f) => f['id'] == reminder['farm_id'],
            orElse: () => <String, dynamic>{},
          );
          final crop = widget.allCrops.firstWhere(
            (c) => c['id'] == reminder['crop_id'],
            orElse: () => <String, dynamic>{},
          );
          final farmer = widget.allFarmers.firstWhere(
            (f) => f['id'] == farm['farmer_id'],
            orElse: () => <String, dynamic>{},
          );
          
          displayName = farm['name'] ?? 'Unknown Farm';
          subName = crop['name'] ?? 'General Checkup';
          ownerName = farmer['name'] ?? 'N/A';
        }
        
        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)], // Vibrant Green
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2E7D32).withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned(
                right: -20,
                bottom: -20,
                child: Icon(
                  Icons.agriculture_rounded,
                  size: 150,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.agriculture_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white, letterSpacing: -0.2),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subName,
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: Colors.white),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(height: 1, color: Colors.white.withValues(alpha: 0.2)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.person_outline_rounded, size: 14, color: Colors.white.withValues(alpha: 0.8)),
                            const SizedBox(width: 6),
                            Text(
                              'Owner: $ownerName',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            widget.isListView 
                              ? DateFormat('dd MMM').format(DateTime.parse(reminder['follow_up_date']))
                              : 'Scheduled',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
      },
    );
  }
}
