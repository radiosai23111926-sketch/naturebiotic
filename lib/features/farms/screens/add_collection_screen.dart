import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:nature_biotic/services/local_database_service.dart';
import 'package:nature_biotic/services/sync_manager.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AddCollectionScreen extends StatefulWidget {
  final String farmId;
  final String farmName;
  final String? farmerName;
  final String? cropId;
  final String? cropName;

  const AddCollectionScreen({
    super.key,
    required this.farmId,
    required this.farmName,
    this.farmerName,
    this.cropId,
    this.cropName,
  });

  @override
  State<AddCollectionScreen> createState() => _AddCollectionScreenState();
}

class _AddCollectionScreenState extends State<AddCollectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  late final TextEditingController _farmerNameController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _farmerNameController = TextEditingController(text: widget.farmerName ?? '');
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

    setState(() => _isLoading = true);

    try {
      final data = {
        'id': const Uuid().v4(),
        'farm_id': widget.farmId,
        'farmer_name': _farmerNameController.text.trim(),
        'amount': double.tryParse(_amountController.text) ?? 0.0,
        'notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        'created_by': SupabaseService.client.auth.currentUser?.id,
        'created_at': DateTime.now().toIso8601String(),
      };

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
                  '₹${_amountController.text} collected & saved!',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context, true);
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

                  const SizedBox(height: 32),

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
                            if (double.tryParse(v) == null) return 'Enter a valid number';
                            if ((double.tryParse(v) ?? 0) <= 0) return 'Amount must be greater than 0';
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
                      onPressed: _isLoading ? null : _handleSubmit,
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
                          : const Icon(Icons.save_rounded),
                      label: Text(
                        _isLoading ? 'Saving...' : 'Save Collection',
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
