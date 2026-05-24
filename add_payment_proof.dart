import 'dart:io';

void main() {
  final file = File('d:/Personal/naturebiotic/lib/features/farms/screens/add_collection_screen.dart');
  String content = file.readAsStringSync();
  content = content.replaceAll('\r\n', '\n');

  // Add imports
  if (!content.contains('image_picker')) {
    content = content.replaceFirst(
      'import \'package:flutter/material.dart\';',
      'import \'package:flutter/material.dart\';\nimport \'package:image_picker/image_picker.dart\';\nimport \'dart:typed_data\';'
    );
  }

  // Add state variables
  if (!content.contains('XFile? _paymentProofFile;')) {
    content = content.replaceFirst(
      '  final _notesController = TextEditingController();\n  late final TextEditingController _farmerNameController;',
      '  final _notesController = TextEditingController();\n  late final TextEditingController _farmerNameController;\n\n  final ImagePicker _picker = ImagePicker();\n  XFile? _paymentProofFile;\n  Uint8List? _paymentProofBytes;'
    );
  }

  // Add pick method
  if (!content.contains('_pickPaymentProof')) {
    content = content.replaceFirst(
      '  Future<void> _loadFarmerDetails() async {',
      '''  Future<void> _pickPaymentProof() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
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
          SnackBar(content: Text('Error taking photo: \$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _loadFarmerDetails() async {'''
    );
  }

  // Add validation
  if (!content.contains('Payment proof is required')) {
    content = content.replaceFirst(
      '    if (!_formKey.currentState!.validate()) return;\n\n    setState(() => _isLoading = true);',
      '''    if (!_formKey.currentState!.validate()) return;
    if (_paymentMethod != 'Cash' && _paymentProofBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment proof is required for non-cash payments'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);'''
    );
  }

  // Add upload logic
  if (!content.contains('proofUrl = await SupabaseService.uploadImage')) {
    content = content.replaceFirst(
      '      // Increment counter only after confirmation\n      await prefs.setInt(\'global_receipt_counter\', globalCounter + 1);',
      '''      // Increment counter only after confirmation
      await prefs.setInt('global_receipt_counter', globalCounter + 1);

      String? proofUrl;
      if (_paymentMethod != 'Cash' && _paymentProofBytes != null) {
        try {
          final fileName = 'proof_\${DateTime.now().millisecondsSinceEpoch}.jpg';
          proofUrl = await SupabaseService.uploadImage(
            _paymentProofBytes!,
            fileName,
            'collections',
          );
        } catch (e) {
          debugPrint('Error uploading proof: \$e');
        }
      }'''
    );
  }

  // Add proof_url to data
  if (!content.contains('\'proof_url\': proofUrl,')) {
    content = content.replaceFirst(
      '        \'created_by\': _overrideStaffProfile?[\'id\']?.toString() ?? SupabaseService.client.auth.currentUser?.id,\n      };',
      '        \'created_by\': _overrideStaffProfile?[\'id\']?.toString() ?? SupabaseService.client.auth.currentUser?.id,\n        \'proof_url\': proofUrl,\n      };'
    );
  }

  // Add UI for picking proof
  final uiSearchStr = '                  const SizedBox(height: 16),\n\n                  // Notes field';
  if (content.contains(uiSearchStr) && !content.contains('_pickPaymentProof,')) {
    content = content.replaceFirst(
      uiSearchStr,
      '''                  if (_paymentMethod != 'Cash') ...[
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
                                icon: const Icon(Icons.camera_alt_rounded),
                                label: Text(_paymentProofBytes == null ? 'Take Photo' : 'Retake'),
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

                  // Notes field'''
    );
  } else {
    print('Failed to find UI injection point');
  }

  content = content.replaceAll('\n', '\r\n');
  file.writeAsStringSync(content);
  print('Successfully added payment proof logic!');
}
