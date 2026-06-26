import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:intl/intl.dart';

class DataEntrySelector extends StatefulWidget {
  final Function(Map<String, dynamic>? staffProfile) onStaffChanged;
  final Function(DateTime dateTime) onDateChanged;
  final String? initialStaffId;
  final DateTime? initialDate;
  final bool showStaffSelector;

  const DataEntrySelector({
    super.key,
    required this.onStaffChanged,
    required this.onDateChanged,
    this.initialStaffId,
    this.initialDate,
    this.showStaffSelector = true,
  });

  @override
  State<DataEntrySelector> createState() => _DataEntrySelectorState();
}

class _DataEntrySelectorState extends State<DataEntrySelector> {
  bool _isDataEntry = false;
  String? _selectedStaffId;
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _staffProfiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedStaffId = widget.initialStaffId;
    if (widget.initialDate != null) {
      _selectedDate = widget.initialDate!;
    }
    _checkRoleAndLoadStaff();
  }

  Future<void> _checkRoleAndLoadStaff() async {
    try {
      final profile = await SupabaseService.getProfile();
      if (profile?['role'] == 'data_entry') {
        setState(() => _isDataEntry = true);
        if (widget.showStaffSelector) {
          final staff = await SupabaseService.getStaffProfiles();
          setState(() {
            _staffProfiles = staff;
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDateTime(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(minutes: 5)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textBlack,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate),
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
        widget.onDateChanged(_selectedDate);
      }
    }
  }

  @override
  void didUpdateWidget(covariant DataEntrySelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialStaffId != oldWidget.initialStaffId) {
      setState(() {
        _selectedStaffId = widget.initialStaffId;
      });
    }
    if (widget.initialDate != oldWidget.initialDate) {
      setState(() {
        _selectedDate = widget.initialDate ?? DateTime.now();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDataEntry) return const SizedBox.shrink();
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withOpacity(0.15), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Data Entry Mode',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (widget.showStaffSelector) ...[
            DropdownButtonFormField<String>(
              value: _selectedStaffId,
              decoration: const InputDecoration(
                labelText: 'On Behalf Of (Staff Member) *',
                fillColor: Colors.white,
                filled: true,
                prefixIcon: Icon(Icons.person_rounded, color: AppColors.primary),
              ),
              items: _staffProfiles.map((staff) {
                final roleName = staff['role']?.toString().toUpperCase() ?? 'STAFF';
                return DropdownMenuItem<String>(
                  value: staff['id']?.toString(),
                  child: Text('${staff['full_name'] ?? 'Unknown'} ($roleName)'),
                );
              }).toList(),
              validator: (v) => v == null ? 'Please select a staff member' : null,
              onChanged: (val) {
                setState(() => _selectedStaffId = val);
                final staff = _staffProfiles.firstWhere(
                  (s) => s['id']?.toString() == val,
                  orElse: () => <String, dynamic>{},
                );
                widget.onStaffChanged(staff.isEmpty ? null : staff);
              },
            ),
            const SizedBox(height: 16),
          ],
          InkWell(
            onTap: () => _selectDateTime(context),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_rounded, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Entry Date & Time',
                          style: TextStyle(fontSize: 11, color: AppColors.textGray),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('dd MMMM yyyy, hh:mm a').format(_selectedDate),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textBlack,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.edit_calendar_rounded, color: AppColors.primary, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
