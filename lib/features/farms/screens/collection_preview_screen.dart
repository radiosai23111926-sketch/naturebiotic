import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/pdf_service.dart';

class CollectionPreviewScreen extends StatefulWidget {
  final String receiptNo;
  final DateTime date;
  final String customerName;
  final String contactNo;
  final String customerAddress;
  final double amount;
  final String purpose;
  final double accAmount;
  final double balanceDue;
  final String paymentMethod;

  const CollectionPreviewScreen({
    super.key,
    required this.receiptNo,
    required this.date,
    required this.customerName,
    required this.contactNo,
    required this.customerAddress,
    required this.amount,
    required this.purpose,
    required this.accAmount,
    required this.balanceDue,
    required this.paymentMethod,
  });

  @override
  State<CollectionPreviewScreen> createState() => _CollectionPreviewScreenState();
}

class _CollectionPreviewScreenState extends State<CollectionPreviewScreen> {
  Uint8List? _pdfBytes;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _generatePdf();
  }

  Future<void> _generatePdf() async {
    try {
      final bytes = await PdfService.generatePaymentReceiptBytes(
        receiptNo: widget.receiptNo,
        date: widget.date,
        customerName: widget.customerName,
        contactNo: widget.contactNo,
        customerAddress: widget.customerAddress,
        amount: widget.amount,
        purpose: widget.purpose,
        accAmount: widget.accAmount,
        balanceDue: widget.balanceDue,
        paymentMethod: widget.paymentMethod,
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
        title: const Text('Receipt Preview'),
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
