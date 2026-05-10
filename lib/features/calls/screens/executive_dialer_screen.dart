import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/core/call_tracker.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

class ExecutiveDialerScreen extends StatefulWidget {
  const ExecutiveDialerScreen({super.key});

  @override
  State<ExecutiveDialerScreen> createState() => _ExecutiveDialerScreenState();
}

class _ExecutiveDialerScreenState extends State<ExecutiveDialerScreen> with WidgetsBindingObserver {
  String _phoneNumber = '';
  String _searchQuery = '';
  List<Map<String, dynamic>> _allContacts = [];
  List<Map<String, dynamic>> _callLogs = [];
  
  bool _isLoading = false;
  bool _isLogsLoading = false;
  DateTime _selectedLogDate = DateTime.now();
  
  // Tracking
  DateTime? _callStartTime;
  String? _dialedNumber;
  String? _selectedFarmerId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    _loadLogs();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _callStartTime != null && _dialedNumber != null) {
      final startTime = _callStartTime!;
      final dialedNumber = _dialedNumber!;
      final farmerId = _selectedFarmerId;
      
      _callStartTime = null;
      _dialedNumber = null;
      _selectedFarmerId = null;

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          CallTracker.processCallResult(
            context, 
            dialedNumber, 
            startTime, 
            farmerId: farmerId
          ).then((_) => _loadLogs()); // Refresh logs after call
        }
      });
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        SupabaseService.getFarmers(),
        SupabaseService.getFarms(),
      ]);
      
      final farmers = List<Map<String, dynamic>>.from(results[0] ?? []);
      final farms = List<Map<String, dynamic>>.from(results[1] ?? []);
      
      final List<Map<String, dynamic>> processedContacts = [];
      
      // Add farmers as main contacts
      for (var farmer in farmers) {
        processedContacts.add({
          'name': farmer['name'] ?? 'Unknown Farmer',
          'phone': farmer['mobile'] ?? farmer['phone'] ?? 'N/A',
          'type': 'Farmer',
          'id': farmer['id']?.toString() ?? '',
          'subtitle': farmer['village'] ?? 'No village mentioned'
        });
      }
      
      // Add additional contacts from farms
      for (var farm in farms) {
        final farmName = farm['name'] ?? 'Unknown Farm';
        final contactsData = farm['contacts'];
        if (contactsData != null) {
          try {
            List<dynamic> contacts = [];
            if (contactsData is String) {
              contacts = jsonDecode(contactsData);
            } else if (contactsData is List) {
              contacts = contactsData;
            }
            
            for (var contact in contacts) {
              processedContacts.add({
                'name': contact['name']?.toString() ?? 'Contact Person',
                'phone': contact['phone']?.toString() ?? 'N/A',
                'type': 'Farm Contact',
                'id': farm['farmer_id']?.toString() ?? '', 
                'subtitle': 'At $farmName'
              });
            }
          } catch (e) {
             debugPrint('Error parsing farm contacts: $e');
          }
        }
      }

      if (mounted) {
        setState(() {
          processedContacts.sort((a, b) => 
            (a['name']?.toString().toLowerCase() ?? '').compareTo(b['name']?.toString().toLowerCase() ?? ''));
          _allContacts = processedContacts;
        });
      }
    } catch (e) {
      debugPrint('Error loading dialer data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadLogs() async {
    if (!mounted) return;
    setState(() => _isLogsLoading = true);
    try {
      final logs = await SupabaseService.getCallLogs(
        startDate: _selectedLogDate,
        endDate: _selectedLogDate,
      );
      if (mounted) {
        setState(() {
          _callLogs = List<Map<String, dynamic>>.from(logs ?? []);
          _isLogsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLogsLoading = false);
    }
  }

  void _onDigitPress(String digit) {
    setState(() {
      _phoneNumber += digit;
    });
  }

  void _onBackspace() {
    if (_phoneNumber.isNotEmpty) {
      setState(() {
        _phoneNumber = _phoneNumber.substring(0, _phoneNumber.length - 1);
      });
    }
  }

  void _initiateCall(String number, {String? farmerId}) {
    if (number.isEmpty) return;
    
    _callStartTime = DateTime.now();
    _dialedNumber = number;
    _selectedFarmerId = farmerId;
    
    CallTracker.makeCall(context, number, farmerId: farmerId);
    setState(() {
      _phoneNumber = ''; // Reset dialer for next number
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Nature Biotic Dialer'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.history_rounded), text: 'Recents'),
              Tab(icon: Icon(Icons.contacts_rounded), text: 'Contacts'),
              Tab(icon: Icon(Icons.dialpad_rounded), text: 'Dialer'),
            ],
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textGray,
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: TabBarView(
              children: [
                _buildRecentsTab(),
                _buildContactsTab(),
                _buildDialerTab(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDialerTab() {
    final contacts = _allContacts ?? []; // Safety
    final filteredSuggestions = contacts
        .where((c) => (c['phone']?.toString().contains(_phoneNumber) ?? false))
        .toList();

    return Column(
      children: [
        // Display Area
        Container(
          padding: const EdgeInsets.all(24),
          alignment: Alignment.center,
          child: Text(
            _phoneNumber.isEmpty ? 'Enter Number' : _phoneNumber,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: _phoneNumber.isEmpty ? Colors.grey[400] : AppColors.primary,
            ),
          ),
        ),
        
        // Contact Suggestions
        if (_phoneNumber.isNotEmpty)
          Expanded(
            child: ListView.builder(
              itemCount: filteredSuggestions.length,
              itemBuilder: (context, index) {
                final c = filteredSuggestions[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: c['type'] == 'Farmer' ? AppColors.secondary.withOpacity(0.2) : Colors.blue.withOpacity(0.1), 
                    child: Icon(
                      c['type'] == 'Farmer' ? Icons.person : Icons.business_center_rounded, 
                      color: c['type'] == 'Farmer' ? AppColors.primary : Colors.blue
                    )
                  ),
                  title: Text(c['name']?.toString() ?? 'Unknown'),
                  subtitle: Text('${c['phone']} • ${c['subtitle']}'),
                  onTap: () => _initiateCall(c['phone']?.toString() ?? '', farmerId: c['id']?.toString()),
                );
              },
            ),
          )
        else
          const Expanded(child: SizedBox()),

        // Dial Pad
        _buildDialPad(),
        
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildContactsTab() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    
    final contacts = _allContacts ?? [];
    final filteredContacts = contacts.where((c) {
      final query = _searchQuery.toLowerCase();
      final nameStr = c['name']?.toString().toLowerCase() ?? '';
      final phoneStr = c['phone']?.toString() ?? '';
      return nameStr.contains(query) || phoneStr.contains(query);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search contacts...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filteredContacts.length,
            itemBuilder: (context, index) {
              final contact = filteredContacts[index];
              final name = contact['name']?.toString() ?? 'Generic Contact';
              final phone = contact['phone']?.toString() ?? 'N/A';
              final id = contact['id']?.toString();
              
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: contact['type'] == 'Farmer' ? AppColors.secondary.withOpacity(0.2) : Colors.blue.withOpacity(0.1), 
                  child: Icon(
                    contact['type'] == 'Farmer' ? Icons.person : Icons.business_center_rounded, 
                    color: contact['type'] == 'Farmer' ? AppColors.primary : Colors.blue
                  )
                ),
                title: Text(name),
                subtitle: Text('$phone • ${contact['subtitle']}'),
                trailing: IconButton(
                  icon: const Icon(Icons.call, color: Colors.green),
                  onPressed: () => _initiateCall(phone, farmerId: id),
                ),
                onTap: () => _initiateCall(phone, farmerId: id),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecentsTab() {
    final logs = _callLogs ?? [];
    
    return Column(
      children: [
        _buildDateFilterBar(),
        Expanded(
          child: _isLogsLoading
              ? const Center(child: CircularProgressIndicator())
              : logs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history_rounded, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text('No calls found for this date', style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        final log = logs[index];
                        final farmerName = log['farmers']?['name'] ?? 'Direct Call';
                        final createdAt = log['created_at']?.toString() ?? DateTime.now().toIso8601String();
                        final startTime = DateTime.tryParse(createdAt) ?? DateTime.now();
                        final timeStr = DateFormat('hh:mm a').format(startTime);
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.call_made_rounded, color: Colors.green, size: 20),
                            ),
                            title: Text(farmerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${log['phone_number'] ?? 'Unknown'} • $timeStr'),
                                if (log['profiles']?['full_name'] != null)
                                  Text(
                                    'Spoke: ${log['profiles']['full_name']}',
                                    style: TextStyle(
                                      color: AppColors.primary, 
                                      fontSize: 11, 
                                      fontWeight: FontWeight.bold,
                                      backgroundColor: AppColors.primary.withOpacity(0.05)
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${(log['duration_seconds'] ?? 0) ~/ 60}m ${log['duration_seconds'] % 60}s',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (log['summary'] != null &&
                                        log['summary'].toString().isNotEmpty)
                                      const SizedBox(height: 4),
                                  ],
                                ),
                                if (log['summary'] != null &&
                                    log['summary'].toString().isNotEmpty)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.note_alt_outlined,
                                      size: 20,
                                      color: AppColors.primary,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: 'View Summary',
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder:
                                            (context) => AlertDialog(
                                              title: const Text('Call Summary'),
                                              content: Text(
                                                log['summary'].toString(),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed:
                                                      () =>
                                                          Navigator.pop(context),
                                                  child: const Text('Close'),
                                                ),
                                              ],
                                            ),
                                      );
                                    },
                                  ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(
                                    Icons.call_rounded,
                                    color: Colors.green,
                                  ),
                                  onPressed:
                                      () => _initiateCall(
                                        log['phone_number']?.toString() ?? '',
                                        farmerId: log['farmer_id']?.toString(),
                                      ),
                                ),
                              ],
                            ),
                            onTap:
                                () => _initiateCall(
                                  log['phone_number']?.toString() ?? '',
                                  farmerId: log['farmer_id']?.toString(),
                                ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildDateFilterBar() {
    final isToday = DateUtils.isSameDay(_selectedLogDate, DateTime.now());
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () {
              setState(() => _selectedLogDate = _selectedLogDate.subtract(const Duration(days: 1)));
              _loadLogs();
            },
          ),
          Expanded(
            child: InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedLogDate,
                  firstDate: DateTime(2024),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() => _selectedLogDate = date);
                  _loadLogs();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      isToday ? 'Today' : DateFormat('dd MMM yyyy').format(_selectedLogDate),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: isToday ? null : () {
              setState(() => _selectedLogDate = _selectedLogDate.add(const Duration(days: 1)));
              _loadLogs();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDialPad() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _dialButton('1'),
            _dialButton('2'),
            _dialButton('3'),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _dialButton('4'),
            _dialButton('5'),
            _dialButton('6'),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _dialButton('7'),
            _dialButton('8'),
            _dialButton('9'),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _dialButton('*'),
            _dialButton('0'),
            _dialButton('#'),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 64), 
            FloatingActionButton(
              heroTag: 'dialer_fab',
              onPressed: () => _initiateCall(_phoneNumber),
              backgroundColor: Colors.green,
              child: const Icon(Icons.call, color: Colors.white),
            ),
            const SizedBox(width: 24),
            IconButton(
              onPressed: _onBackspace,
              icon: const Icon(Icons.backspace_outlined),
              iconSize: 28,
            ),
          ],
        ),
      ],
    );
  }

  Widget _dialButton(String digit) {
    return MaterialButton(
      onPressed: () => _onDigitPress(digit),
      height: 70,
      minWidth: 70,
      shape: const CircleBorder(),
      child: Text(
        digit,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }
}
