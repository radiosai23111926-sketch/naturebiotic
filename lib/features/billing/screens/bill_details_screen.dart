import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:nature_biotic/services/pdf_service.dart';

class BillDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> bill;

  const BillDetailsScreen({super.key, required this.bill});

  @override
  State<BillDetailsScreen> createState() => _BillDetailsScreenState();
}

class _BillDetailsScreenState extends State<BillDetailsScreen> {
  late Map<String, dynamic> _billData;
  List<dynamic> _billItems = [];
  bool _isLoading = false;

  String _discountType = 'none'; // 'none', 'percentage', 'flat'
  double _discountValue = 0.0;
  final TextEditingController _discountValController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _billData = widget.bill;
    _billItems = widget.bill['items'] is List 
        ? widget.bill['items']
        : [];

    _discountType = widget.bill['discount_type']?.toString() ?? 'none';
    _discountValue = double.tryParse(widget.bill['discount_value']?.toString() ?? '0') ?? 0.0;
    if (_discountValue > 0) {
      _discountValController.text = _discountValue.toString();
    }
    // Pre-cache billing config, images, and fonts in background
    PdfService.preCacheBillingConfigAndImages();
  }

  @override
  void dispose() {
    _discountValController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _calculateTotals() {
    double subtotal = 0.0;       // Sum of original tax-exclusive amount
    double totalDiscount = 0.0;  // Sum of tax-exclusive discount
    double totalTaxable = 0.0;   // Sum of net tax-exclusive base
    double totalTax = 0.0;
    
    final Map<double, double> cgstGroup = {};
    final Map<double, double> sgstGroup = {};

    double inclusiveSubtotal = 0.0;
    for (var item in _billItems) {
      final double qty = double.tryParse((item['qty'] ?? item['quantity'])?.toString() ?? '0') ?? 0.0;
      final double offerPrice = double.tryParse(item['offer_price']?.toString() ?? '0') ?? 0.0;
      inclusiveSubtotal += offerPrice * qty;
    }

    double totalInclusiveDiscount = 0.0;
    if (_discountType == 'percentage') {
      totalInclusiveDiscount = inclusiveSubtotal * (_discountValue / 100.0);
    } else if (_discountType == 'flat') {
      totalInclusiveDiscount = _discountValue;
    }

    final calculatedItems = [];

    for (var item in _billItems) {
      final double qty = double.tryParse((item['qty'] ?? item['quantity'])?.toString() ?? '0') ?? 0.0;
      final double offerPrice = double.tryParse(item['offer_price']?.toString() ?? '0') ?? 0.0;
      final double taxPercentage = double.tryParse(item['tax_percentage']?.toString() ?? '0') ?? 0.0;

      final double lineOriginalTotalInclusive = offerPrice * qty;
      
      double lineInclusiveDiscount = 0.0;
      if (inclusiveSubtotal > 0) {
        lineInclusiveDiscount = totalInclusiveDiscount * (lineOriginalTotalInclusive / inclusiveSubtotal);
      }
      if (lineInclusiveDiscount > lineOriginalTotalInclusive) {
        lineInclusiveDiscount = lineOriginalTotalInclusive;
      }

      final double lineDiscountedTotalInclusive = lineOriginalTotalInclusive - lineInclusiveDiscount;

      final double originalBaseRate = offerPrice / (1.0 + taxPercentage / 100.0);
      final double originalBaseAmount = qty * originalBaseRate;

      final double netTaxableBase = lineDiscountedTotalInclusive / (1.0 + taxPercentage / 100.0);
      final double lineTaxExclusiveDiscount = originalBaseAmount - netTaxableBase;

      final double cgstRate = taxPercentage / 2.0;
      final double sgstRate = taxPercentage / 2.0;

      double cgstAmt = 0.0;
      double sgstAmt = 0.0;
      if (taxPercentage > 0) {
        cgstAmt = netTaxableBase * (cgstRate / 100.0);
        cgstAmt = double.parse(cgstAmt.toStringAsFixed(2));
        
        sgstAmt = netTaxableBase * (sgstRate / 100.0);
        sgstAmt = double.parse(sgstAmt.toStringAsFixed(2));
      }

      subtotal += originalBaseAmount;
      totalDiscount += lineTaxExclusiveDiscount;
      totalTaxable += netTaxableBase;

      if (cgstRate > 0) {
        cgstGroup[cgstRate] = (cgstGroup[cgstRate] ?? 0.0) + cgstAmt;
        sgstGroup[sgstRate] = (sgstGroup[sgstRate] ?? 0.0) + sgstAmt;
      }

      calculatedItems.add({
        ...item,
        'rate': originalBaseRate,
        'amount': originalBaseAmount,
        'line_original_total': lineOriginalTotalInclusive,
        'line_discount': lineInclusiveDiscount,
        'line_discounted_total': lineDiscountedTotalInclusive,
        'taxable_value': netTaxableBase,
        'cgst_percentage': cgstRate,
        'cgst_amount': cgstAmt,
        'sgst_percentage': sgstRate,
        'sgst_amount': sgstAmt,
        'tax_amount': cgstAmt + sgstAmt,
      });
    }

    subtotal = double.parse(subtotal.toStringAsFixed(2));
    totalDiscount = double.parse(totalDiscount.toStringAsFixed(2));
    totalTaxable = double.parse(totalTaxable.toStringAsFixed(2));

    double cgstSum = 0.0;
    double sgstSum = 0.0;
    cgstGroup.forEach((rate, amt) {
      cgstGroup[rate] = double.parse(amt.toStringAsFixed(2));
      cgstSum += cgstGroup[rate]!;
    });
    sgstGroup.forEach((rate, amt) {
      sgstGroup[rate] = double.parse(amt.toStringAsFixed(2));
      sgstSum += sgstGroup[rate]!;
    });

    totalTax = cgstSum + sgstSum;
    final double rawGrandTotal = totalTaxable + totalTax;
    final double grandTotalRounded = rawGrandTotal.roundToDouble();
    final double rounding = grandTotalRounded - rawGrandTotal;

    return {
      'subtotal': subtotal,
      'total_discount': totalDiscount,
      'total_taxable_amount': totalTaxable,
      'cgst_group': cgstGroup,
      'sgst_group': sgstGroup,
      'total_tax_amount': totalTax,
      'rounding': rounding,
      'grand_total': grandTotalRounded,
      'items': calculatedItems,
    };
  }

  Future<void> _submitForApproval(Map<String, dynamic> totals) async {
    setState(() => _isLoading = true);
    try {
      final updatedData = {
        'status': 'PENDING_APPROVAL',
        'discount_type': _discountType,
        'discount_value': _discountValue,
        'total_discount': totals['total_discount'],
        'total_taxable_amount': totals['total_taxable_amount'],
        'total_tax_amount': totals['total_tax_amount'],
        'grand_total': totals['grand_total'],
        'items': totals['items'],
        'updated_at': DateTime.now().toIso8601String(),
      };

      await SupabaseService.updateBill(_billData['id'], updatedData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Discount approval requested successfully!'), backgroundColor: AppColors.primary),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generateFinalBill(Map<String, dynamic> totals) async {
    setState(() => _isLoading = true);
    try {
      final updatedData = {
        'status': 'BILLED',
        'discount_type': _discountType,
        'discount_value': _discountValue,
        'total_discount': totals['total_discount'],
        'total_taxable_amount': totals['total_taxable_amount'],
        'total_tax_amount': totals['total_tax_amount'],
        'grand_total': totals['grand_total'],
        'items': totals['items'],
        'updated_at': DateTime.now().toIso8601String(),
      };

      // 1. Update status to BILLED in Supabase
      await SupabaseService.updateBill(_billData['id'], updatedData);

      // 2. Fetch fresh farmer details for PDF
      String farmName = 'Farm';
      String farmerName = 'Farmer';
      String farmerContact = '';
      String farmerAddress = '';
      String cropName = 'N/A';

      if (_billData['farms'] != null) {
        farmName = _billData['farms']['name'] ?? 'Farm';
        if (_billData['farms']['farmers'] != null) {
          farmerName = _billData['farms']['farmers']['name'] ?? 'Farmer';
          farmerContact = _billData['farms']['farmers']['mobile'] ?? '';
          farmerAddress = _billData['farms']['farmers']['address'] ?? '';
        }
      }

      final billToGenerate = {
        ..._billData,
        ...updatedData,
      };

      // 3. Generate and share PDF Invoice
      await PdfService.generateInvoice(
        bill: billToGenerate,
        farmName: farmName,
        farmerName: farmerName,
        cropName: cropName,
        date: DateTime.now(),
        farmerAddress: farmerAddress.isNotEmpty ? farmerAddress : null,
        farmerContact: farmerContact.isNotEmpty ? farmerContact : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill generated and invoice opened!'), backgroundColor: AppColors.primary),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating bill: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _viewInvoice() async {
    setState(() => _isLoading = true);
    try {
      String farmName = 'Farm';
      String farmerName = 'Farmer';
      String farmerContact = '';
      String farmerAddress = '';
      String cropName = 'N/A';

      if (_billData['farms'] != null) {
        farmName = _billData['farms']['name'] ?? 'Farm';
        if (_billData['farms']['farmers'] != null) {
          farmerName = _billData['farms']['farmers']['name'] ?? 'Farmer';
          farmerContact = _billData['farms']['farmers']['mobile'] ?? '';
          farmerAddress = _billData['farms']['farmers']['address'] ?? '';
        }
      }

      await PdfService.generateInvoice(
        bill: _billData,
        farmName: farmName,
        farmerName: farmerName,
        cropName: cropName,
        date: DateTime.tryParse(_billData['updated_at'] ?? '') ?? DateTime.now(),
        farmerAddress: farmerAddress.isNotEmpty ? farmerAddress : null,
        farmerContact: farmerContact.isNotEmpty ? farmerContact : null,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error showing invoice: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _billData['status']?.toString().toUpperCase() ?? 'PENDING_BILLING';
    final isLocked = status == 'PENDING_APPROVAL' || status == 'BILLED' || status == 'APPROVED';
    final hasAdminNotes = _billData['admin_notes'] != null && _billData['admin_notes'].toString().isNotEmpty;

    // Live calculation
    final totals = _calculateTotals();
    final calculatedItems = totals['items'] as List;

    // Resolve details
    String farmName = 'Unknown Farm';
    String farmerName = 'Unknown Farmer';
    String landmark = 'N/A';
    if (_billData['farms'] != null) {
      farmName = _billData['farms']['name'] ?? 'Unknown Farm';
      landmark = _billData['farms']['landmark'] ?? 'N/A';
      if (_billData['customer_name'] != null && _billData['customer_name'].toString().isNotEmpty) {
        farmerName = _billData['customer_name'].toString();
      } else if (_billData['farms']['farmers'] != null) {
        farmerName = _billData['farms']['farmers']['name'] ?? 'Unknown Farmer';
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Bill Details'),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (status == 'PENDING_APPROVAL')
                      _buildBanner('Awaiting Admin Approval', 'You have requested a discount on this bill. It is currently under review.', Colors.amber.shade800)
                    else if (status == 'APPROVED')
                      _buildBanner('Discount Approved', 'Admin has approved the requested discount. You can now generate the final bill.', Colors.green)
                    else if (status == 'REJECTED')
                      _buildBanner('Discount Rejected', 'Admin has rejected the discount. Modify the details and try again or generate without discount.', Colors.red),
                    
                    if (hasAdminNotes) ...[
                      const SizedBox(height: 12),
                      _buildAdminNotesCard(_billData['admin_notes']),
                    ],

                    const SizedBox(height: 16),
                    _buildCustomerCard(farmName, farmerName, landmark),
                    const SizedBox(height: 24),

                    Text('Item Lines', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: calculatedItems.length,
                      itemBuilder: (context, index) {
                        final item = calculatedItems[index];
                        return _buildItemRow(item);
                      },
                    ),

                    const SizedBox(height: 24),
                    if (!isLocked) _buildDiscountSelector() else _buildLockedDiscountSummary(),

                    const SizedBox(height: 24),
                    _buildCalculationsCard(totals),
                    const SizedBox(height: 100), // padding for bottom bar
                  ],
                ),
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black12,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      bottomNavigationBar: _buildBottomActions(totals),
    );
  }

  Widget _buildBanner(String title, String subtitle, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: color, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
                const SizedBox(height: 4),
                Text(subtitle, style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textGray)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminNotesCard(String notes) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Admin Feedback:', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red.shade800)),
          const SizedBox(height: 4),
          Text(notes, style: GoogleFonts.outfit(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.red.shade900)),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(String farm, String farmer, String landmark) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.agriculture_rounded, color: AppColors.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(farm, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(
                        _billData['customer_name'] != null && _billData['customer_name'].toString().isNotEmpty
                            ? 'Customer: $farmer'
                            : 'Farmer: $farmer',
                        style: GoogleFonts.outfit(color: AppColors.textGray),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Landmark:', style: GoogleFonts.outfit(color: AppColors.textGray, fontSize: 13)),
                Text(landmark, style: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 13)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Challan No:', style: GoogleFonts.outfit(color: AppColors.textGray, fontSize: 13)),
                Text(_billData['challan_no'] ?? 'N/A', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
            if (_billData['place_of_supply'] != null && _billData['place_of_supply'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Place of Supply:', style: GoogleFonts.outfit(color: AppColors.textGray, fontSize: 13)),
                  Text(_billData['place_of_supply'].toString(), style: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 13)),
                ],
              ),
            ],
            if (_billData['customer_gstin'] != null && _billData['customer_gstin'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Customer GSTIN:', style: GoogleFonts.outfit(color: AppColors.textGray, fontSize: 13)),
                  Text(_billData['customer_gstin'].toString(), style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(Map<dynamic, dynamic> item) {
    final double qty = double.tryParse((item['qty'] ?? item['quantity'])?.toString() ?? '0') ?? 0.0;
    final double rate = double.tryParse(item['offer_price']?.toString() ?? '0') ?? 0.0;
    final double lineTotal = rate * qty;
    final double taxPercentage = double.tryParse(item['tax_percentage']?.toString() ?? '0') ?? 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['name'] ?? 'Unknown Item', style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (item['description'] != null && item['description'].toString().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item['description'],
                      style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textGray),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'Unit: ${item['unit'] ?? 'N/A'} | HSN: ${item['hsn_code'] ?? 'N/A'} | Tax: ${taxPercentage.toInt()}%',
                    style: const TextStyle(color: AppColors.textGray, fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('₹${rate.toStringAsFixed(2)} x ${qty.toInt()}', style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 2),
                Text('₹${lineTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscountSelector() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add Discount', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _discountType,
                    decoration: const InputDecoration(
                      labelText: 'Discount Type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'none', child: Text('No Discount')),
                      DropdownMenuItem(value: 'percentage', child: Text('Percentage (%)')),
                      DropdownMenuItem(value: 'flat', child: Text('Flat Amount (₹)')),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _discountType = val ?? 'none';
                        if (_discountType == 'none') {
                          _discountValue = 0.0;
                          _discountValController.clear();
                        }
                      });
                    },
                  ),
                ),
                if (_discountType != 'none') ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _discountValController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: _discountType == 'percentage' ? 'Percentage %' : 'Flat Amount (₹)',
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _discountValue = double.tryParse(val) ?? 0.0;
                        });
                      },
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLockedDiscountSummary() {
    String typeStr = 'No Discount';
    if (_discountType == 'percentage') typeStr = 'Percentage (${_discountValue}%)';
    if (_discountType == 'flat') typeStr = 'Flat (₹${_discountValue})';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Discount Applied', style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textGray)),
                Text(typeStr, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            ),
            const Icon(Icons.lock_outline_rounded, color: AppColors.textGray),
          ],
        ),
      ),
    );
  }

  Widget _buildCalculationsCard(Map<String, dynamic> totals) {
    final subtotal = totals['subtotal'] as double;
    final discount = totals['total_discount'] as double;
    final taxable = totals['total_taxable_amount'] as double;
    final cgstGroup = totals['cgst_group'] as Map<double, double>;
    final sgstGroup = totals['sgst_group'] as Map<double, double>;
    final rounding = totals['rounding'] as double;
    final grand = totals['grand_total'] as double;

    final List<Widget> taxRows = [];
    cgstGroup.forEach((rate, amt) {
      if (amt > 0) {
        taxRows.add(
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _calcRow('CGST @ ${rate.toString()}%', '₹${amt.toStringAsFixed(2)}'),
          ),
        );
      }
    });

    sgstGroup.forEach((rate, amt) {
      if (amt > 0) {
        taxRows.add(
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _calcRow('SGST @ ${rate.toString()}%', '₹${amt.toStringAsFixed(2)}'),
          ),
        );
      }
    });

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _calcRow('Sub Total', '₹${subtotal.toStringAsFixed(2)}'),
            if (discount > 0) ...[
              const SizedBox(height: 8),
              _calcRow('Discount', '(-) ₹${discount.toStringAsFixed(2)}', valueColor: Colors.red),
            ],
            const SizedBox(height: 8),
            _calcRow('Taxable Value', '₹${taxable.toStringAsFixed(2)}'),
            ...taxRows,
            if (rounding.abs() > 0.001) ...[
              const SizedBox(height: 8),
              _calcRow('Rounding', '${rounding > 0 ? "+" : ""}₹${rounding.toStringAsFixed(2)}'),
            ],
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Grand Total', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(
                  '₹${grand.toStringAsFixed(2)}',
                  style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _calcRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textGray)),
        Text(value, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: valueColor)),
      ],
    );
  }

  Widget? _buildBottomActions(Map<String, dynamic> totals) {
    final status = _billData['status']?.toString().toUpperCase() ?? 'PENDING_BILLING';

    if (status == 'PENDING_APPROVAL') {
      return Container(
        padding: const EdgeInsets.all(24),
        color: Colors.white,
        child: const Text(
          'Waiting for Admin Approval. Actions will be unlocked after admin responds.',
          textAlign: TextAlign.center,
          style: TextStyle(fontStyle: FontStyle.italic, color: AppColors.textGray),
        ),
      );
    }

    if (status == 'BILLED') {
      return Container(
        padding: const EdgeInsets.all(24),
        color: Colors.white,
        child: ElevatedButton.icon(
          onPressed: _viewInvoice,
          icon: const Icon(Icons.picture_as_pdf_rounded),
          label: const Text('View / Share Invoice'),
        ),
      );
    }

    // PENDING_BILLING, REJECTED, APPROVED
    final double discount = totals['total_discount'] as double;
    final bool hasDiscount = discount > 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      if (hasDiscount && status != 'APPROVED') {
                        // Request approval
                        _submitForApproval(totals);
                      } else {
                        // Directly generate bill
                        _generateFinalBill(totals);
                      }
                    },
              child: Text(
                (hasDiscount && status != 'APPROVED')
                    ? 'Request Admin Approval'
                    : 'Generate Bill',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
