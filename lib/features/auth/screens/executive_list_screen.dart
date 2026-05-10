import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:nature_biotic/features/auth/screens/executive_assignment_screen.dart';
import 'package:nature_biotic/features/attendance/screens/attendance_history_screen.dart';
import 'package:nature_biotic/core/widgets/animations.dart';

class ExecutiveListScreen extends StatefulWidget {
  const ExecutiveListScreen({super.key});

  @override
  State<ExecutiveListScreen> createState() => _ExecutiveListScreenState();
}

class _ExecutiveListScreenState extends State<ExecutiveListScreen> {
  List<Map<String, dynamic>> _teamMembers = [];
  Map<String, double> _salesStats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTeamMembers();
  }

  Future<void> _loadTeamMembers() async {
    try {
      final data = await SupabaseService.getTeamMembers();
      final stats = await SupabaseService.getTeamSalesStats();
      if (mounted) {
        setState(() {
          _teamMembers = data;
          _salesStats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Team Management'),
        actions: [
          IconButton(
            onPressed: _loadTeamMembers,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _teamMembers.isEmpty
              ? const Center(child: Text('No team members found.'))
              : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(24.0),
                    itemCount: _teamMembers.length,
                    itemBuilder: (context, index) {
                      final member = _teamMembers[index];
                      final role = member['role'] ?? 'unknown';
                      final target = (member['sales_target'] ?? 0.0).toDouble();
                      final achieved = _salesStats[member['id']] ?? 0.0;
                      final pending = (target - achieved).clamp(0.0, double.infinity);
                      final progress = target > 0 ? (achieved / target).clamp(0.0, 1.0) : 0.0;
                      final isExecutive = role == 'executive' || role == 'telecaller';

                      return EntranceAnimation(
                        child: InkWell(
                          onTap: () => _showOptions(member),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                              border: Border.all(color: AppColors.primary.withOpacity(0.05)),
                            ),
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Row(
                                    children: [
                                      Hero(
                                        tag: 'avatar_${member['id']}',
                                        child: CircleAvatar(
                                          radius: 28,
                                          backgroundColor: AppColors.secondary,
                                          backgroundImage: member['avatar_url'] != null
                                              ? NetworkImage(member['avatar_url'])
                                              : null,
                                          child: member['avatar_url'] == null
                                              ? Text(
                                                  member['full_name']?[0] ?? 'U',
                                                  style: const TextStyle(
                                                    color: AppColors.primary,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 20,
                                                  ),
                                                )
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              member['full_name'] ?? 'N/A',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 18,
                                                color: AppColors.textBlack,
                                                letterSpacing: -0.5,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Text(
                                                      '@${member['username'] ?? 'unknown'}',
                                                      style: TextStyle(
                                                        color: AppColors.textGray.withOpacity(0.6),
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                      decoration: BoxDecoration(
                                                        color: Colors.blueGrey.withOpacity(0.08),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        'ID: ${(member['staff_number'] ?? '-').toString().padLeft(4, '0')}',
                                                        style: const TextStyle(
                                                          color: Colors.blueGrey,
                                                          fontSize: 9,
                                                          fontWeight: FontWeight.w900,
                                                          letterSpacing: 0.5,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.primary.withOpacity(0.08),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        role.toUpperCase(),
                                                        style: const TextStyle(
                                                          color: AppColors.primary,
                                                          fontSize: 9,
                                                          fontWeight: FontWeight.w900,
                                                          letterSpacing: 0.5,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        color: AppColors.textGray,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                                if (isExecutive) ...[
                                  Container(
                                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                                    child: Column(
                                      children: [
                                        const Divider(height: 1),
                                        const SizedBox(height: 16),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            _targetMiniStat('Target', '₹${target.toStringAsFixed(0)}'),
                                            _targetMiniStat('Achieved', '₹${achieved.toStringAsFixed(0)}', color: Colors.green),
                                            _targetMiniStat('Pending', '₹${pending.toStringAsFixed(0)}', color: Colors.orange),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Stack(
                                          children: [
                                            Container(
                                              height: 6,
                                              width: double.infinity,
                                              decoration: BoxDecoration(
                                                color: AppColors.background,
                                                borderRadius: BorderRadius.circular(3),
                                              ),
                                            ),
                                            FractionallySizedBox(
                                              widthFactor: progress,
                                              child: Container(
                                                height: 6,
                                                decoration: BoxDecoration(
                                                  gradient: const LinearGradient(
                                                    colors: [AppColors.primary, AppColors.accent],
                                                  ),
                                                  borderRadius: BorderRadius.circular(3),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: AppColors.primary.withOpacity(0.3),
                                                      blurRadius: 4,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            Text(
                                              '${(progress * 100).toStringAsFixed(1)}% Completed',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w900,
                                                color: AppColors.primary.withOpacity(0.7),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
    );
  }

  void _showOptions(Map<String, dynamic> member) {
    final bool isExecutive = member['role'] == 'executive' || member['role'] == 'telecaller' || member['role'] == 'manager';
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              left: 24,
              right: 24,
              top: 24,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: ListView(
              shrinkWrap: true,
              physics:
                  const NeverScrollableScrollPhysics(), // Only scroll if needed via bottom sheet behavior
              children: [
                Text(
                  member['full_name'] ?? 'Member Options',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '@${member['username']}',
                        style: const TextStyle(
                          color: AppColors.textGray,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'ID: ${(member['staff_number'] ?? '-').toString().padLeft(4, '0')}',
                          style: const TextStyle(
                            color: Colors.blueGrey,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          (member['role'] ?? 'unknown').toString().toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 32),
                if (isExecutive) ...[
                  _optionItem(
                    Icons.agriculture_rounded,
                    'Assign Farms',
                    'Manage farms assigned to this executive',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  ExecutiveAssignmentScreen(executive: member),
                        ),
                      ).then((_) => _loadTeamMembers());
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                _optionItem(
                  Icons.history_rounded,
                  'Attendance & Leaves',
                  'View check-in logs and leave history',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => AttendanceHistoryScreen(
                              userId: member['id'],
                            ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                if (isExecutive) ...[
                  _optionItem(
                    Icons.track_changes_rounded,
                    'Set Sales Target',
                    'Monthly target: ₹${member['sales_target'] ?? 0}',
                    onTap: () {
                      Navigator.pop(context);
                      _showTargetDialog(member);
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                _optionItem(
                  Icons.phonelink_erase_rounded,
                  'Reset Device Pairing',
                  'Allow login from a new phone',
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: const Text('Reset Device?'),
                            content: const Text(
                              'This will allow the user to link their account to a new phone. Are you sure?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text(
                                  'Reset',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                    );

                    if (confirm == true) {
                      await SupabaseService.resetUserDevice(member['id']);
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Device pairing reset successfully'),
                          ),
                        );
                      }
                    }
                  },
                ),
                const SizedBox(height: 16),
                _optionItem(
                  Icons.person_remove_rounded,
                  'Delete Account',
                  'Permanently remove this user account',
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Account?'),
                        content: const Text('This will permanently delete this user account. This action cannot be undone.'),
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
                      try {
                        await SupabaseService.deleteRecord('profiles', member['id']);
                        _loadTeamMembers();
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Account deleted successfully')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    }
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
    );
  }

  Widget _optionItem(
    IconData icon,
    String title,
    String subtitle, {
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.secondary.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textGray,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  void _showTargetDialog(Map<String, dynamic> executive) {
    final controller = TextEditingController(
      text: (executive['sales_target'] ?? '').toString(),
    );
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Set Target for ${executive['full_name']}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Enter the monthly sales target for this executive.',
                  style: TextStyle(fontSize: 13, color: AppColors.textGray),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Sales Target (₹)',
                    hintText: 'e.g. 10000',
                  ),
                  autofocus: true,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final target = double.tryParse(controller.text) ?? 0.0;
                  Navigator.pop(context);

                  try {
                    await SupabaseService.updateSalesTarget(
                      executive['id'],
                      target,
                    );
                    _loadTeamMembers(); // Refresh list to show new target
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Sales target updated successfully'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error updating target: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  Widget _targetMiniStat(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            color: AppColors.textGray.withOpacity(0.4),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: color ?? AppColors.textBlack,
          ),
        ),
      ],
    );
  }
}
