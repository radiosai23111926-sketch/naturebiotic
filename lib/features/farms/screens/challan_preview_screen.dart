import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/pdf_service.dart';

class ChallanPreviewScreen extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final String farmName;
  final String farmerName;
  final String cropName;
  final String transactionType;
  final DateTime date;
  final String? farmerAddress;
  final String? farmerContact;
  final String? dcNumber;
  final String? placeOfSupply;
  final String? customerGstin;

  const ChallanPreviewScreen({
    super.key,
    required this.items,
    required this.farmName,
    required this.farmerName,
    required this.cropName,
    required this.transactionType,
    required this.date,
    this.farmerAddress,
    this.farmerContact,
    this.dcNumber,
    this.placeOfSupply,
    this.customerGstin,
  });

  @override
  State<ChallanPreviewScreen> createState() => _ChallanPreviewScreenState();
}

class _ChallanPreviewScreenState extends State<ChallanPreviewScreen> {
  Uint8List? _pdfBytes;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _generatePdf();
  }

  Future<void> _generatePdf() async {
    try {
      final bytes = await PdfService.generateStockChallanBytes(
        items: widget.items,
        farmName: widget.farmName,
        farmerName: widget.farmerName,
        cropName: widget.cropName,
        transactionType: widget.transactionType,
        date: widget.date,
        farmerAddress: widget.farmerAddress,
        farmerContact: widget.farmerContact,
        dcNumber: widget.dcNumber,
        placeOfSupply: widget.placeOfSupply,
        customerGstin: widget.customerGstin,
      );
      if (mounted) {
        setState(() {
          _pdfBytes = bytes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating preview: $e'),
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
        title: const Text('Challan Preview'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pdfBytes == null
              ? const Center(child: Text('Failed to load preview'))
              : Column(
                  children: [
                    Expanded(
                      child: PdfPreview(
                        build: (format) => _pdfBytes!,
                        allowSharing: false,
                        allowPrinting: false,
                        canChangeOrientation: false,
                        canChangePageFormat: false,
                        canDebug: false,
                        useActions: false,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, -5),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context, false),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                side: const BorderSide(color: AppColors.primary),
                              ),
                              child: const Text('Edit Entry'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: const Text('Confirm & Save'),
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
