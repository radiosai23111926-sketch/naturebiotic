import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';

class EditRequestDialog extends StatefulWidget {
  final String entityType;
  final String entityId;
  final Map<String, String> fieldMap; // {'mobile': 'Mobile Number', ...}
  final Map<String, dynamic> currentData;

  const EditRequestDialog({
    super.key,
    required this.entityType,
    required this.entityId,
    required this.fieldMap,
    required this.currentData,
  });

  static Future<void> show(
    BuildContext context, {
    required String entityType,
    required String entityId,
    required Map<String, String> fieldMap,
    required Map<String, dynamic> currentData,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => EditRequestDialog(
            entityType: entityType,
            entityId: entityId,
            fieldMap: fieldMap,
            currentData: currentData,
          ),
    );
  }

  @override
  State<EditRequestDialog> createState() => _EditRequestDialogState();
}

class _EditRequestDialogState extends State<EditRequestDialog> {
  String? _selectedFieldKey;
  String? _currentValueStr;
  final TextEditingController _newValueController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _newValueController.dispose();
    super.dispose();
  }

  void _onFieldChanged(String? newKey) {
    setState(() {
      _selectedFieldKey = newKey;
      _currentValueStr =
          newKey != null ? widget.currentData[newKey]?.toString() ?? '' : null;
      _newValueController.clear();
    });
  }

  Future<void> _handleSubmit() async {
    if (_selectedFieldKey == null) return;
    final label = widget.fieldMap[_selectedFieldKey!];
    final newVal = _newValueController.text.trim();

    if (newVal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the new corrected value.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await SupabaseService.submitEditRequest(
        entityType: widget.entityType,
        entityId: widget.entityId,
        fieldName: _selectedFieldKey!,
        fieldLabel: label ?? _selectedFieldKey!,
        oldValue: _currentValueStr ?? '',
        newValue: newVal,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Edit Request (Rise Token) submitted successfully.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(top: 20, left: 24, right: 24, bottom: padding + 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit_note_rounded, color: AppColors.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rise Token (Edit Request)',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textBlack,
                        ),
                      ),
                      Text(
                        'Select the field and provide corrected information.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Select Field to Correct',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedFieldKey,
              isExpanded: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              items:
                  widget.fieldMap.entries.map((entry) {
                    return DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value),
                    );
                  }).toList(),
              onChanged: _onFieldChanged,
              hint: const Text('Choose info type...'),
            ),
            if (_selectedFieldKey != null) ...[
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Value',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentValueStr == null || _currentValueStr!.isEmpty
                          ? '[No Data / Empty]'
                          : _currentValueStr!,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Enter Correct Information',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _newValueController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Type the new corrected value here...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child:
                      _isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                            'Submit to Admin',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
