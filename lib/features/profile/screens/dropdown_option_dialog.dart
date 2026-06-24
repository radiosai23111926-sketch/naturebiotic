
import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';

class DropdownOptionDialog extends StatefulWidget {
  final String title;
  final String? initialLabel;
  final String? initialImageUrl;
  final double? initialMrp;
  final double? initialOfferPrice;
  final double? initialTaxPercentage;
  final String? initialHsnCode;
  final String? initialDescription;
  final bool isProductName;
  final bool showCascadeOption;
  final Future<String?> Function() onPickImage;

  const DropdownOptionDialog({
    super.key,
    required this.title,
    this.initialLabel,
    this.initialImageUrl,
    this.initialMrp,
    this.initialOfferPrice,
    this.initialTaxPercentage,
    this.initialHsnCode,
    this.initialDescription,
    required this.isProductName,
    this.showCascadeOption = false,
    required this.onPickImage,
  });

  @override
  State<DropdownOptionDialog> createState() => _DropdownOptionDialogState();
}

class _DropdownOptionDialogState extends State<DropdownOptionDialog> {
  late TextEditingController labelController;
  late TextEditingController mrpController;
  late TextEditingController offerController;
  late TextEditingController taxController;
  late TextEditingController hsnController;
  late TextEditingController descriptionController;
  String? imageUrl;
  bool isUploading = false;
  bool applyToVariants = true;

  @override
  void initState() {
    super.initState();
    labelController = TextEditingController(text: widget.initialLabel);
    mrpController = TextEditingController(text: widget.initialMrp?.toString());
    offerController = TextEditingController(text: widget.initialOfferPrice?.toString());
    taxController = TextEditingController(text: widget.initialTaxPercentage?.toString());
    hsnController = TextEditingController(text: widget.initialHsnCode);
    descriptionController = TextEditingController(text: widget.initialDescription);
    imageUrl = widget.initialImageUrl;
  }

  @override
  void dispose() {
    labelController.dispose();
    mrpController.dispose();
    offerController.dispose();
    taxController.dispose();
    hsnController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: labelController,
                      decoration: InputDecoration(
                        labelText: 'Label Name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 16),
                    if (imageUrl != null)
                      Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              height: 180,
                              width: double.infinity,
                              color: Colors.grey[200],
                              child: Image.network(
                                imageUrl!,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return const Center(child: CircularProgressIndicator());
                                },
                                errorBuilder: (context, error, stackTrace) => Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.broken_image_rounded, size: 48, color: Colors.grey),
                                    SizedBox(height: 8),
                                    Text('Failed to load image', style: TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(() => imageUrl = null),
                            child: const Text('Remove Image', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    if (imageUrl == null && !isUploading)
                      InkWell(
                        onTap: () async {
                          setState(() => isUploading = true);
                          try {
                            final url = await widget.onPickImage();
                            if (url != null) setState(() => imageUrl = url);
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => isUploading = false);
                          }
                        },
                        child: Container(
                          height: 120,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_rounded, size: 40, color: Colors.grey[400]),
                              const SizedBox(height: 8),
                              Text('Add Cover Image', style: TextStyle(color: Colors.grey[600])),
                            ],
                          ),
                        ),
                      ),
                    if (isUploading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: CircularProgressIndicator(),
                      ),
                    if (widget.isProductName) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: hsnController,
                        decoration: const InputDecoration(
                          labelText: 'HSN / SAC Code',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Product Description',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: mrpController,
                              decoration: const InputDecoration(labelText: 'MRP', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: offerController,
                              decoration: const InputDecoration(labelText: 'Offer Price', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: taxController,
                        decoration: const InputDecoration(
                          labelText: 'Tax Percentage (%)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      if (widget.isProductName && widget.showCascadeOption) ...[
                        const SizedBox(height: 8),
                        CheckboxListTile(
                          title: const Text(
                            'Apply to all packet sizes of this product',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          value: applyToVariants,
                          onChanged: (val) {
                            setState(() {
                              applyToVariants = val ?? false;
                            });
                          },
                          activeColor: AppColors.primary,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    final labelVal = labelController.text.trim();
                    if (labelVal.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Label name is required')),
                      );
                      return;
                    }
                    if (widget.isProductName) {
                      final taxStr = taxController.text.trim();
                      if (taxStr.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Tax percentage is required')),
                        );
                        return;
                      }
                      final taxVal = double.tryParse(taxStr);
                      if (taxVal == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a valid tax percentage')),
                        );
                        return;
                      }
                    }
                    Navigator.pop(context, {
                      'label': labelVal,
                      'imageUrl': imageUrl,
                      'mrp': double.tryParse(mrpController.text),
                      'offerPrice': double.tryParse(offerController.text),
                      'taxPercentage': double.tryParse(taxController.text),
                      'hsnCode': hsnController.text.trim(),
                      'description': descriptionController.text.trim(),
                      'applyToVariants': applyToVariants,
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
