import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:nature_biotic/services/local_database_service.dart';
import 'package:nature_biotic/services/sync_manager.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import 'package:nature_biotic/features/farms/screens/collection_preview_screen.dart';
import 'package:nature_biotic/core/widgets/data_entry_selector.dart';

class AddCollectionScreen extends StatefulWidget {
  final String farmId;
  final String farmName;
  final String? farmerName;
  final String? cropId;
  final String? cropName;
  final double? accAmount;
  final double? balanceDue;

  const AddCollectionScreen({
    super.key,
    required this.farmId,
    required this.farmName,
    this.farmerName,
    this.cropId,
    this.cropName,
    this.accAmount,
    this.balanceDue,
  });

  @override
  State<AddCollectionScreen> createState() => _AddCollectionScreenState();
}

class _AddCollectionScreenState extends State<AddCollectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  late final TextEditingController _farmerNameController;

  final ImagePicker _picker = ImagePicker();
  XFile? _paymentProofFile;
  Uint8List? _paymentProofBytes;

  bool _isLoading = false;
  Map<String, dynamic>? _overrideStaffProfile;
  DateTime _overrideDate = DateTime.now();
  String _paymentMethod = 'Cash';
  final List<String> _paymentOptions = [
    'Cash',
    'Bank',
    'Cheque',
    'UPI',
    'Other',
  ];

  Map<String, dynamic>? _farmerDetails;

  double _totalBilled = 0.0;
  double _totalCollected = 0.0;
  double _pendingBalance = 0.0;
  bool _isBalanceLoading = true;

  @override
  void initState() {
    super.initState();
    _farmerNameController =
        TextEditingController(text: widget.farmerName ?? '');
    _loadFarmerDetails();
    _fetchBillingAndCollections();
  }

  Future<void> _pickPaymentProof() async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded),
                title: const Text('Take Photo'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );

    if (source == null) return;

    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 70,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _paymentProofFile = image;
          _paymentProofBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting image: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _loadFarmerDetails() async {
    try {
      final info = await SupabaseService.getFarmAndFarmerInfo(widget.farmId);
      if (info != null && info['farmers'] != null) {
        if (mounted) {
          setState(() {
            _farmerDetails = info['farmers'];
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchBillingAndCollections() async {
    setState(() => _isBalanceLoading = true);
    try {
      final results = await Future.wait([
        SupabaseService.getFarmBills(widget.farmId),
        SupabaseService.getFarmCollections(widget.farmId),
      ]);
      final bills = results[0];
      final collections = results[1];

      final totalBill = bills.fold<double>(
        0.0,
        (sum, b) {
          if (b['status']?.toString().toUpperCase() == 'REJECTED') {
            return sum;
          }
          return sum + (double.tryParse(b['grand_total']?.toString() ?? '0') ?? 0.0);
        },
      );

      final totalColl = collections.fold<double>(
        0.0,
        (sum, c) => sum + (double.tryParse(c['amount']?.toString() ?? '0') ?? 0.0),
      );

      if (mounted) {
        setState(() {
          _totalBilled = totalBill;
          _totalCollected = totalColl;
          _pendingBalance = totalBill - totalColl;
          if (_pendingBalance < 0) _pendingBalance = 0;
          _isBalanceLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching billing balance: $e');
      if (mounted) {
        setState(() => _isBalanceLoading = false);
      }
    }
  }

  String _formatAmount(dynamic amount) {
    final val = double.tryParse(amount.toString()) ?? 0.0;
    final formatted = NumberFormat('#,##,##0.00', 'en_IN').format(val);
    return '₹$formatted';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _farmerNameController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_paymentMethod != 'Cash' && _paymentProofBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment proof is required for non-cash payments'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final profile = _overrideStaffProfile ?? await SupabaseService.getProfile();
      String execPart = '0000';
      if (profile != null) {
        final staffNo = profile['staff_number']?.toString();
        if (staffNo != null && staffNo.isNotEmpty) {
          execPart = staffNo.padLeft(4, '0');
          if (execPart.length > 4) {
            execPart = execPart.substring(execPart.length - 4);
          }
        } else {
          final username = profile['username']?.toString() ?? '';
          final digits = username.replaceAll(RegExp(r'[^0-9]'), '');
          if (digits.isNotEmpty) {
            execPart = digits.padLeft(4, '0');
            if (execPart.length > 4) {
              execPart = execPart.substring(execPart.length - 4);
            }
          } else {
            final id = profile['id']?.toString() ?? '';
            if (id.length >= 4) execPart = id.substring(0, 4).toUpperCase();
          }
        }
      }

      int globalCounter = prefs.getInt('global_receipt_counter') ?? 1;
      final receiptPart = globalCounter.toString().padLeft(4, '0');

      final now = _overrideStaffProfile != null ? _overrideDate : DateTime.now();
      int startYear = now.month < 4 ? now.year - 1 : now.year;
      final fy = '$startYear-${startYear + 1}';
      final receiptNo = 'SAI$execPart$receiptPart/$fy';

      final collectedAmount = double.tryParse(_amountController.text) ?? 0.0;
      final currentAccAmount = widget.accAmount ?? 0.0;
      final currentBalanceDue = widget.balanceDue ?? 0.0;

      // PREVIEW STEP
      final confirmed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder:
              (context) => CollectionPreviewScreen(
                receiptNo: receiptNo,
                date: now,
                customerName: _farmerNameController.text.trim(),
                contactNo: _farmerDetails?['mobile'] ?? 'N/A',
                customerAddress: _farmerDetails?['address'] ?? 'N/A',
                amount: collectedAmount,
                purpose:
                    '${widget.farmName}${widget.cropName != null ? ' - ${widget.cropName}' : ''}',
                accAmount: currentAccAmount,
                balanceDue: currentBalanceDue - collectedAmount,
                paymentMethod: _paymentMethod,
              ),
        ),
      );

      if (confirmed != true) {
        setState(() => _isLoading = false);
        return;
      }

      // Increment counter only after confirmation
      await prefs.setInt('global_receipt_counter', globalCounter + 1);

      String? proofUrl;
      if (_paymentMethod != 'Cash' && _paymentProofBytes != null) {
        try {
          final fileName = 'proof_${DateTime.now().millisecondsSinceEpoch}.jpg';
          proofUrl = await SupabaseService.uploadImage(
            _paymentProofBytes!,
            fileName,
            'collections',
          );
        } catch (e) {
          debugPrint('Error uploading proof: $e');
        }
      }

      final data = {
        'id': const Uuid().v4(),
        'farm_id': widget.farmId,
        'farmer_name': _farmerNameController.text.trim(),
        'amount': collectedAmount,
        'payment_method': _paymentMethod,
        'receipt_no': receiptNo,
        'notes':
            _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
        'created_at': now.toIso8601String(),
        'created_by': _overrideStaffProfile?['id']?.toString() ?? SupabaseService.client.auth.currentUser?.id,
        'proof_url': proofUrl,
      };

      if (!kIsWeb && proofUrl == null && _paymentProofBytes != null && _paymentMethod != 'Cash') {
        data['_local_proof'] = _paymentProofBytes;
      }

      if (kIsWeb) {
        await SupabaseService.addFarmCollection(data);
      } else {
        await LocalDatabaseService.saveAndQueue(
          tableName: 'farm_collections',
          data: data,
          operation: 'INSERT',
        );
        SyncManager().sync();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                  '₹${_amountController.text} collected! (Rec: $receiptNo)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        Navigator.pop(context, data);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Record Collection')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DataEntrySelector(
                    onStaffChanged: (profile) => _overrideStaffProfile = profile,
                    onDateChanged: (dt) => _overrideDate = dt,
                  ),
                  // Farm context info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.account_balance_wallet_rounded,
                              color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.cropName != null 
                                  ? 'Collection for ${widget.cropName}' 
                                  : 'Collection for',
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.textGray),
                              ),
                              Text(
                                widget.farmName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppColors.textBlack,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Billing Summary Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _isBalanceLoading
                          ? Colors.grey[100]
                          : (_totalBilled == 0
                              ? Colors.red[50]
                              : (_pendingBalance <= 0
                                  ? Colors.orange[50]
                                  : Colors.green[50])),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isBalanceLoading
                            ? Colors.grey[200]!
                            : (_totalBilled == 0
                                ? Colors.red[200]!
                                : (_pendingBalance <= 0
                                    ? Colors.orange[200]!
                                    : Colors.green[200]!)),
                      ),
                    ),
                    child: _isBalanceLoading
                        ? const Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Loading billing info...',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textGray,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Icon(
                                _totalBilled == 0
                                    ? Icons.error_outline_rounded
                                    : (_pendingBalance <= 0
                                        ? Icons.check_circle_outline_rounded
                                        : Icons.info_outline_rounded),
                                color: _totalBilled == 0
                                    ? Colors.red[700]
                                    : (_pendingBalance <= 0
                                        ? Colors.orange[700]
                                        : Colors.green[700]),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_totalBilled == 0) ...[
                                      Text(
                                        'No Billing Found',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.red[900],
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Collections cannot be recorded without an existing bill.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.red[700],
                                        ),
                                      ),
                                    ] else if (_pendingBalance <= 0) ...[
                                      Text(
                                        'Fully Collected',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.orange[900],
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Billed: ${_formatAmount(_totalBilled)} | Collected: ${_formatAmount(_totalCollected)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.orange[700],
                                        ),
                                      ),
                                    ] else ...[
                                      Text(
                                        'Outstanding Balance: ${_formatAmount(_pendingBalance)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.green[900],
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Billed: ${_formatAmount(_totalBilled)} | Collected: ${_formatAmount(_totalCollected)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.green[700],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                  ),

                  const SizedBox(height: 24),

                  // Amount field - hero input
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadow.withOpacity(0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Amount Collected *',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textBlack,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primary),
                          decoration: InputDecoration(
                            prefixText: '₹  ',
                            prefixStyle: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                            hintText: '0.00',
                            hintStyle: TextStyle(
                              fontSize: 28,
                              color: Colors.grey[300],
                              fontWeight: FontWeight.bold,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey[200]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: AppColors.primary, width: 2),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey[200]!),
                            ),
                            filled: true,
                            fillColor: AppColors.background,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Please enter the amount collected';
                            final amt = double.tryParse(v);
                            if (amt == null) return 'Enter a valid number';
                            if (amt <= 0) return 'Amount must be greater than 0';
                            if (_isBalanceLoading) return 'Still loading billing info. Please wait...';
                            if (_totalBilled == 0) return 'Cannot record collection: No billing exists for this farm';
                            if (amt > _pendingBalance) {
                              return 'Amount exceeds pending balance of ${_formatAmount(_pendingBalance)}';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Farmer name field
                  TextFormField(
                    controller: _farmerNameController,
                    decoration: const InputDecoration(
                      labelText: 'Farmer Name',
                      prefixIcon: Icon(Icons.person_rounded),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Payment Method field
                  DropdownButtonFormField<String>(
                    value: _paymentMethod,
                    decoration: const InputDecoration(
                      labelText: 'Payment Method',
                      prefixIcon: Icon(Icons.payment_rounded),
                    ),
                    items: _paymentOptions.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _paymentMethod = newValue;
                        });
                      }
                    },
                  ),

                  if (_paymentMethod != 'Cash') ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _paymentProofBytes == null ? Colors.red.withValues(alpha: 0.5) : AppColors.primary.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.receipt_long_rounded, color: AppColors.primary),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Payment Proof (Required)',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _pickPaymentProof,
                                icon: const Icon(Icons.upload_file_rounded),
                                label: Text(_paymentProofBytes == null ? 'Upload Proof' : 'Change Proof'),
                              ),
                            ],
                          ),
                          if (_paymentProofBytes != null) ...[
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                _paymentProofBytes!,
                                height: 120,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ],
                          if (_paymentProofBytes == null) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'Please upload proof for non-cash payments.',
                              style: TextStyle(color: Colors.red, fontSize: 12, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Notes field
                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notes / Remarks (optional)',
                      hintText: 'e.g. Payment for previous visit, partial payment...',
                      prefixIcon: Icon(Icons.notes_rounded),
                      alignLabelWithHint: true,
                    ),
                  ),

                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: (_isLoading || _isBalanceLoading || _totalBilled == 0 || _pendingBalance <= 0) ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 2,
                      ),
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Icon((_totalBilled == 0 || _pendingBalance <= 0) ? Icons.block_rounded : Icons.save_rounded),
                      label: Text(
                        _isLoading
                            ? 'Saving...'
                            : (_isBalanceLoading
                                ? 'Loading Balance...'
                                : (_totalBilled == 0
                                    ? 'No Billing (Cannot Save)'
                                    : (_pendingBalance <= 0
                                        ? 'Fully Collected (Cannot Save)'
                                        : 'Save Collection'))),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
