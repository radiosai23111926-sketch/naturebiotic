import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';

class AdminEditRequestsScreen extends StatefulWidget {
  const AdminEditRequestsScreen({super.key});

  @override
  State<AdminEditRequestsScreen> createState() => _AdminEditRequestsScreenState();
}

class _AdminEditRequestsScreenState extends State<AdminEditRequestsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final reqs = await SupabaseService.getPendingEditRequests();
      if (mounted) {
        setState(() {
          _requests = reqs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('Error loading edit requests: $e');
    }
  }

  Future<void> _handleProcess(Map<String, dynamic> request, String decision) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(decision == 'approved' ? 'Approve Change?' : 'Reject Request?'),
        content: Text(
          decision == 'approved'
              ? 'The correct info will automatically update in the database immediately.'
              : 'This request will be marked as rejected without any changes.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: decision == 'approved' ? Colors.green : Colors.red,
            ),
            child: Text(decision == 'approved' ? 'Approve & Update' : 'Reject'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await SupabaseService.processEditRequest(
        requestId: request['id'],
        status: decision,
        entityType: request['entity_type'],
        entityId: request['entity_id'],
        fieldName: request['field_name'],
        newValue: request['new_value'],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(decision == 'approved' ? 'Request Approved & Synced' : 'Request Rejected'),
            backgroundColor: decision == 'approved' ? Colors.green : Colors.orange,
          ),
        );
        _loadRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Operation failed: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width > 900;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Edit Info Requests',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadRequests,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
              ? _buildEmptyState()
              : Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isWide ? 1000 : double.infinity),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _requests.length,
                      itemBuilder: (context, index) {
                        return _buildRequestCard(_requests[index]);
                      },
                    ),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline_rounded, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No Pending Requests',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'All corrections have been fully reviewed.',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> req) {
    final formattedDate = DateFormat('MMM dd, yyyy - hh:mm a').format(
      DateTime.parse(req['created_at']).toLocal(),
    );

    final requester = req['profiles']?['full_name'] ?? 'Unknown User';
    final entityLabel = req['entity_type'] == 'farmers' ? 'Farmer' : 'Farm';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))
        ],
        border: Border.all(color: Colors.black.withOpacity(0.02)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    req['entity_type'] == 'farmers' ? Icons.person_rounded : Icons.agriculture_rounded,
                    color: AppColors.primary,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$entityLabel Correction',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      Text(
                        'Requested by $requester • $formattedDate',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content (The Diff)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.label_important_rounded, color: Colors.orangeAccent, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Field: ${req['field_label'] ?? req['field_name']}',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppColors.textBlack),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Old Value
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.red.shade100),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CURRENT VALUE',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Colors.red.shade700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              (req['old_value'] == null || req['old_value'].toString().isEmpty)
                                  ? '[Empty]'
                                  : req['old_value'].toString(),
                              style: const TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: Icon(Icons.arrow_forward_rounded, color: Colors.grey),
                    ),
                    const SizedBox(width: 12),
                    // New Value
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PROPOSED NEW VALUE',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Colors.green.shade700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              req['new_value'].toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Colors.green,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Divider & Actions
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _handleProcess(req, 'rejected'),
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Reject'),
                  style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _handleProcess(req, 'approved'),
                  icon: const Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
                  label: const Text('Approve & Update', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
