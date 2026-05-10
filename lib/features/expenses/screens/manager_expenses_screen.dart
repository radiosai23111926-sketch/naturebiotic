import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:intl/intl.dart';
import 'package:nature_biotic/features/expenses/screens/expense_detail_screen.dart';
import 'package:nature_biotic/services/pdf_service.dart';

class ManagerExpenseControl extends StatefulWidget {
  const ManagerExpenseControl({super.key});

  @override
  State<ManagerExpenseControl> createState() => _ManagerExpenseControlState();
}

class _ManagerExpenseControlState extends State<ManagerExpenseControl> {
  List<Map<String, dynamic>> _executives = [];
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        SupabaseService.getExecutives(),
        SupabaseService.getExpenseHistory(
          startDate: _startDate,
          endDate: _endDate,
        ),
      ]).timeout(const Duration(seconds: 15));
      if (mounted) {
        setState(() {
          _executives = results[0];
          _history = results[1];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Load failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showDateRangePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
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

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final bool isWide = width > 900;

    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final pendingReturns =
        _history.where((e) => e['return_status'] == 'PENDING').toList();
    final activeTrips = _history.where((e) => e['status'] == 'ACTIVE').toList();

    return Material(
      color: const Color(0xFFF8F9FA),
      child:
          isWide
              ? _buildWideAdminLayout(pendingReturns, activeTrips)
              : _buildMobileLayout(pendingReturns, activeTrips),
    );
  }

  Widget _buildWideAdminLayout(
    List<Map<String, dynamic>> pending,
    List<Map<String, dynamic>> active,
  ) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: ListView(
        children: [
          _buildWideHeader(),
          _buildFilterBar(),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  'Expense Audit Log (Date-wise)',
                  Icons.history_rounded,
                ),
                const SizedBox(height: 24),
                _buildWideHistoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideHeader() {
    double totalAllotted = 0;
    double totalSpent = 0;

    for (var h in _history) {
      final allottedVal = h['amount_allotted'];
      totalAllotted +=
          (allottedVal is num)
              ? allottedVal.toDouble()
              : (double.tryParse(allottedVal?.toString() ?? '0') ?? 0.0);

      final items = List<dynamic>.from(h['expense_items'] ?? []);
      for (var item in items) {
        final amountVal = item['amount'];
        totalSpent +=
            (amountVal is num)
                ? amountVal.toDouble()
                : (double.tryParse(amountVal?.toString() ?? '0') ?? 0.0);
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(40, 60, 40, 40),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF004D40), Color(0xFF00796B)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Financial Oversight',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 16,
                    ),
                  ),
                  const Text(
                    'Expense Management',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    onPressed:
                        () => PdfService.generateExpenseReport(
                          history: _history,
                          dateRange: DateTimeRange(
                            start: _startDate,
                            end: _endDate,
                          ),
                        ),
                    icon: const Icon(
                      Icons.picture_as_pdf_rounded,
                      color: Colors.white,
                    ),
                    tooltip: 'Download Report',
                  ),
                  IconButton(
                    onPressed: _loadData,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: Colors.white,
                    ),
                    iconSize: 32,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 40),
          // 4 Cards in one line
          Row(
            children: [
              Expanded(
                child: _statCard(
                  'Total Allotted',
                  '₹${totalAllotted.toStringAsFixed(0)}',
                  Icons.account_balance_wallet_rounded,
                  Colors.white,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _statCard(
                  'Total Spent',
                  '₹${totalSpent.toStringAsFixed(0)}',
                  Icons.shopping_bag_rounded,
                  Colors.orangeAccent,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _statCard(
                  'Pending Returns',
                  '${_history.where((e) => e['return_status'] == 'PENDING').length}',
                  Icons.assignment_return_rounded,
                  Colors.amberAccent,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _statCard(
                  'Active Trips',
                  '${_history.where((e) => e['status'] == 'ACTIVE').length}',
                  Icons.local_shipping_rounded,
                  Colors.lightBlueAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      child: Row(
        children: [
          const Icon(Icons.filter_list_rounded, color: AppColors.primary),
          const SizedBox(width: 12),
          const Text(
            'Filter by Date/Period: ',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(width: 16),
          _dateFilterButton(),
        ],
      ),
    );
  }

  Widget _dateFilterButton() {
    return InkWell(
      onTap: _showDateRangePicker,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.date_range_rounded,
              size: 18,
              color: AppColors.primary,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'FROM',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary.withOpacity(0.5),
                  ),
                ),
                Text(
                  DateFormat('dd MMM yyyy').format(_startDate),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            Container(
              height: 24,
              width: 1,
              color: AppColors.primary.withOpacity(0.2),
              margin: const EdgeInsets.symmetric(horizontal: 16),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'TO',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary.withOpacity(0.5),
                  ),
                ),
                Text(
                  DateFormat('dd MMM yyyy').format(_endDate),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWideHistoryTab() {
    if (_history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            children: [
              Icon(
                Icons.payments_outlined,
                size: 64,
                color: AppColors.textGray.withOpacity(0.2),
              ),
              const SizedBox(height: 16),
              const Text(
                'No expense history found for this period.',
                style: TextStyle(color: AppColors.textGray),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Custom Table Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: const [
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Date',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Executive',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Allotted',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Spent',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Balance',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Returned',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Status',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Action',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Table Rows
            ..._history.map((expense) {
              String date = 'N/A';
              if (expense['created_at'] != null) {
                try {
                  date = DateFormat(
                    'dd MMM yyyy',
                  ).format(DateTime.parse(expense['created_at']));
                } catch (_) {}
              }
              final name = expense['profiles']?['full_name'] ?? 'Unknown';

              final allottedVal = expense['amount_allotted'];
              final double allotted =
                  (allottedVal is num)
                      ? allottedVal.toDouble()
                      : (double.tryParse(allottedVal?.toString() ?? '0') ??
                          0.0);

              final items = List<dynamic>.from(expense['expense_items'] ?? []);
              double spent = 0;
              for (var item in items) {
                final amt = item['amount'];
                spent +=
                    (amt is num)
                        ? amt.toDouble()
                        : (double.tryParse(amt?.toString() ?? '0') ?? 0.0);
              }

              final double balance = allotted - spent;
              final double returnAmount =
                  (expense['return_amount'] is num)
                      ? (expense['return_amount'] as num).toDouble()
                      : (double.tryParse(
                            expense['return_amount']?.toString() ?? '0',
                          ) ??
                          0.0);
              final isClaim = returnAmount < 0;

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade100),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(date, style: const TextStyle(fontSize: 13)),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '₹${allotted.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '₹${spent.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        isClaim
                            ? 'CLAIM: ₹${returnAmount.abs().toStringAsFixed(2)}'
                            : '₹${balance.toStringAsFixed(2)}',
                        style: TextStyle(
                          color:
                              balance < 0
                                  ? Colors.orange.shade800
                                  : AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        expense['return_amount'] != null
                            ? (isClaim
                                ? 'C: ₹${returnAmount.abs()}'
                                : 'R: ₹$returnAmount')
                            : '-',
                        style: TextStyle(
                          color:
                              isClaim ? Colors.orange.shade700 : Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: _statusChip(
                        expense['status'],
                        expense['return_status'],
                        returnAmount,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) =>
                                          ExpenseDetailScreen(expense: expense),
                                ),
                              ).then((value) {
                                if (value == true) _loadData();
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary.withOpacity(
                                0.1,
                              ),
                              foregroundColor: AppColors.primary,
                              minimumSize: const Size(0, 36),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Details',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                          if (expense['return_status'] == 'PENDING') ...[
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed:
                                  () => _approveReturn(expense['id'], isClaim),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    isClaim ? Colors.orange : Colors.green,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 36),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                isClaim ? 'Approve' : 'Accept',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout(
    List<Map<String, dynamic>> pending,
    List<Map<String, dynamic>> active,
  ) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expense Oversight')),
      body: _buildHistoryTab(),
    );
  }

  Widget _buildHistoryTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final e = _history[index];
        String date = 'N/A';
        if (e['created_at'] != null) {
          try {
            date = DateFormat(
              'dd MMM yyyy',
            ).format(DateTime.parse(e['created_at']));
          } catch (_) {}
        }

        final returnAmount =
            double.tryParse(e['return_amount']?.toString() ?? '0') ?? 0.0;

        return Card(
          child: ListTile(
            onTap:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ExpenseDetailScreen(expense: e),
                  ),
                ).then((value) {
                  if (value == true) _loadData();
                }),
            title: Text(e['profiles']?['full_name'] ?? 'Unknown'),
            subtitle: Text('₹${e['amount_allotted'] ?? 0} • $date'),
            trailing: _statusChip(
              e['status'],
              e['return_status'],
              returnAmount,
            ),
          ),
        );
      },
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _statusChip(
    String? status,
    String? returnStatus, [
    double returnAmount = 0,
  ]) {
    String displayStatus = status ?? 'UNKNOWN';
    Color color = displayStatus == 'ACTIVE' ? Colors.green : Colors.blue;

    if (returnStatus == 'PENDING') {
      if (returnAmount < 0) {
        displayStatus = 'CLAIM PENDING';
        color = Colors.deepOrange;
      } else {
        displayStatus = 'RETURN PENDING';
        color = Colors.orange;
      }
    } else if (returnStatus == 'APPROVED') {
      displayStatus = 'CLOSED';
      color = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        displayStatus,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _approveReturn(String id, [bool isClaim = false]) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(isClaim ? 'Approve Claim' : 'Confirm Return'),
            content: Text(
              isClaim
                  ? 'Are you sure you want to approve this claim? This will settle the amount spent by the executive from their pocket.'
                  : 'Are you sure you want to accept this returned amount and close the trip?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isClaim ? Colors.orange : Colors.green,
                ),
                child: const Text('Confirm'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await SupabaseService.approveReturn(id);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Return approved successfully')),
          );
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}
