import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';

class ExecutiveAssignmentScreen extends StatefulWidget {
  final Map<String, dynamic> executive;

  const ExecutiveAssignmentScreen({super.key, required this.executive});

  @override
  State<ExecutiveAssignmentScreen> createState() =>
      _ExecutiveAssignmentScreenState();
}

class _ExecutiveAssignmentScreenState extends State<ExecutiveAssignmentScreen> {
  List<Map<String, dynamic>> _farms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFarms();
  }

  Future<void> _loadFarms() async {
    try {
      final data = await SupabaseService.getFarms();
      if (mounted) {
        setState(() {
          _farms = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleAssignment(Map<String, dynamic> farm) async {
    final isAssignedToThisExecutive =
        farm['assigned_to'] == widget.executive['id'];
    final newAssignedTo =
        isAssignedToThisExecutive ? null : widget.executive['id'];

    try {
      await SupabaseService.assignFarm(farm['id'], newAssignedTo);
      // Refresh local state
      await _loadFarms();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isAssignedToThisExecutive
                  ? 'Farm unassigned from ${widget.executive['full_name']}'
                  : 'Farm assigned to ${widget.executive['full_name']}',
            ),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating assignment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Assign Farms'),
            Text(
              'To: ${widget.executive['full_name']}',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _farms.isEmpty
              ? const Center(child: Text('No farms registered yet.'))
              : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(24.0),
                    itemCount: _farms.length,
                    itemBuilder: (context, index) {
                      final farm = _farms[index];
                      final isAssignedToThisExecutive =
                          farm['assigned_to'] == widget.executive['id'];
                      final isAssignedToOther =
                          farm['assigned_to'] != null &&
                          !isAssignedToThisExecutive;
                      final assignedName =
                          farm['assigned_executive']?['full_name'];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color:
                              isAssignedToThisExecutive
                                  ? AppColors.secondary
                                  : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color:
                                isAssignedToThisExecutive
                                    ? AppColors.primary
                                    : AppColors.secondary,
                            width: isAssignedToThisExecutive ? 2 : 1,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color:
                                  isAssignedToThisExecutive
                                      ? Colors.white
                                      : AppColors.secondary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.agriculture_rounded,
                              color:
                                  isAssignedToThisExecutive
                                      ? AppColors.primary
                                      : AppColors.textGray,
                            ),
                          ),
                          title: Text(
                            farm['name'] ?? farm['place'] ?? 'N/A',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            isAssignedToThisExecutive
                                ? 'Assigned to this Executive'
                                : isAssignedToOther
                                ? 'Assigned to: $assignedName'
                                : 'Unassigned',
                            style: TextStyle(
                              color:
                                  isAssignedToThisExecutive
                                      ? AppColors.primary
                                      : AppColors.textGray,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Switch(
                            value: isAssignedToThisExecutive,
                            activeColor: AppColors.primary,
                            onChanged: (value) => _toggleAssignment(farm),
                          ),
                          onTap: () => _toggleAssignment(farm),
                        ),
                      );
                    },
                  ),
                ),
              ),
    );
  }
}
