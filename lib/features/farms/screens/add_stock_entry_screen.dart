import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:nature_biotic/services/local_database_service.dart';
import 'package:nature_biotic/services/sync_manager.dart';
import 'package:nature_biotic/services/pdf_service.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AddStockEntryScreen extends StatefulWidget {
  final String farmId;
  final String farmName;

  const AddStockEntryScreen({
    super.key,
    required this.farmId,
    required this.farmName,
  });

  @override
  State<AddStockEntryScreen> createState() => _AddStockEntryScreenState();
}

class _AddStockEntryScreenState extends State<AddStockEntryScreen> {
  final _formKey = GlobalKey<FormState>();

  final List<StockItemRow> _itemRows = [StockItemRow()];
  String _transactionType = 'RECEIVED';

  List<String> _itemOptions = [];
  List<Map<String, dynamic>> _allProducts = [];
  List<String> _globalDoseUnits = [];

  bool _isLoading = false;
  bool _isDataLoading = true;
  String _userRole = 'executive';
  Map<String, Map<String, double>> _myStock = {};

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final profile = await SupabaseService.getProfile();
      final items = await SupabaseService.getHierarchicalDropdownOptions(
        'product_name',
      );
      final units = await SupabaseService.getDropdownOptions('dose_unit');

      if (mounted) {
        setState(() {
          _userRole = profile?['role'] ?? 'executive';
          _allProducts = items;
          _itemOptions = items.map((e) => e['label'].toString()).toList();
          _globalDoseUnits = units.map((e) => e['label'].toString()).toList();
        });

        final myStock = await SupabaseService.getDetailedExecutiveStock();
        if (mounted) {
          setState(() {
            _myStock = myStock;
            for (var row in _itemRows) {
              _updateRowPacketOptions(row);
            }
            _isDataLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isDataLoading = false);
    }
  }

  void _updateRowPacketOptions(StockItemRow row) {
    final List<String> defaults = [
      '100ml',
      '250ml',
      '500ml',
      '1 Ltr',
      '100g',
      '250g',
      '500g',
      '1kg',
      '5kg',
      '10kg',
      '25kg',
      '50kg',
      'Nos',
    ];

    if (row.selectedItem == null) {
      row.packetSizeOptions = [...defaults];
      for (var u in _globalDoseUnits) {
        if (!row.packetSizeOptions.contains(u)) row.packetSizeOptions.add(u);
      }
    } else {
      final product = _allProducts.firstWhere(
        (p) => p['label'] == row.selectedItem,
        orElse: () => {},
      );
      final List variants = product['variants'] ?? [];

      if (variants.isNotEmpty) {
        row.packetSizeOptions =
            variants
                .map((v) => v['label'].toString())
                .where(
                  (label) =>
                      !label.toLowerCase().contains('nature') &&
                      !label.toLowerCase().contains('biotic'),
                )
                .toList();
      } else {
        row.packetSizeOptions = [...defaults];
        for (var u in _globalDoseUnits) {
          if (!row.packetSizeOptions.contains(u) &&
              !u.toLowerCase().contains('nature') &&
              !u.toLowerCase().contains('biotic')) {
            row.packetSizeOptions.add(u);
          }
        }
      }
    }
  }

  void _updateRowPrice(StockItemRow row) {
    if (row.selectedItem == null || row.selectedUnit == null) {
      row.selectedPrice = 0.0;
      return;
    }

    final product = _allProducts.firstWhere(
      (p) => p['label'] == row.selectedItem,
      orElse: () => {},
    );
    final List variants = product['variants'] ?? [];

    if (variants.isNotEmpty) {
      final variant = variants.firstWhere(
        (v) => v['label'] == row.selectedUnit,
        orElse: () => {},
      );
      if (variant.isNotEmpty) {
        row.selectedPrice =
            double.tryParse(variant['offer_price']?.toString() ?? '0') ?? 0.0;
      } else {
        row.selectedPrice = 0.0;
      }
    } else {
      row.selectedPrice = 0.0;
    }
  }

  void _addRow() {
    setState(() {
      final newRow = StockItemRow();
      _updateRowPacketOptions(newRow);
      _itemRows.add(newRow);
    });
  }

  void _removeRow(int index) {
    if (_itemRows.length > 1) {
      setState(() {
        _itemRows.removeAt(index);
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    // Check if any row has no product selected
    // Check stock for executives and telecallers
    if ((_userRole == 'executive' || _userRole == 'telecaller') &&
        _transactionType == 'RECEIVED') {
      for (var row in _itemRows) {
        final requestedQty = double.tryParse(row.qtyController.text) ?? 0.0;
        final available = _myStock[row.selectedItem]?[row.selectedUnit] ?? 0.0;
        if (requestedQty > available) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Insufficient stock for ${row.selectedItem} (${row.selectedUnit}). Available: $available',
              ),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isLoading = false);
          return;
        }
      }
    }

    setState(() => _isLoading = true);
    try {
      final timestamp = DateTime.now().toIso8601String();

      for (var row in _itemRows) {
        final data = {
          'id': const Uuid().v4(),
          'farm_id': widget.farmId,
          'item_name': row.selectedItem,
          'transaction_type': _transactionType,
          'quantity': double.tryParse(row.qtyController.text) ?? 0.0,
          'unit': row.selectedUnit,
          'executive_id': SupabaseService.client.auth.currentUser?.id,
          'created_at': timestamp,
        };

        if (kIsWeb) {
          await SupabaseService.addStockTransaction(data);
        } else {
          await LocalDatabaseService.saveAndQueue(
            tableName: 'stock_transactions',
            data: data,
            operation: 'INSERT',
          );
        }
      }

      if (!kIsWeb) {
        SyncManager().sync();
      }

      if (mounted) {
        _showSuccessDialog();
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
      appBar: AppBar(title: const Text('Record Stock Activity')),
      body:
          _isDataLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Activity for ${widget.farmName}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppColors.textGray,
                        ),
                      ),
                      const SizedBox(height: 20),

                      const Text(
                        'Transaction Type',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      _buildTypeSelector(),
                      const SizedBox(height: 24),

                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _itemRows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder:
                            (context, index) =>
                                _buildItemRow(index, _itemRows[index]),
                      ),

                      const SizedBox(height: 20),
                      Center(
                        child: TextButton.icon(
                          onPressed: _addRow,
                          icon: const Icon(Icons.add_circle_outline_rounded),
                          label: const Text('Add Another Product'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            backgroundColor: AppColors.primary.withOpacity(
                              0.05,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleSubmit,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 56),
                          ),
                          child:
                              _isLoading
                                  ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Text('Save Stock Record'),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildItemRow(int index, StockItemRow row) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Product #${index + 1}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              if (_itemRows.length > 1)
                IconButton(
                  onPressed: () => _removeRow(index),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
                    size: 20,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: row.selectedItem,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Select Stock Item',
              hintText: 'Search product...',
            ),
            items:
                _itemOptions
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(e, style: const TextStyle(fontSize: 14)),
                      ),
                    )
                    .toList(),
            onChanged: (v) {
              setState(() {
                row.selectedItem = v;
                row.selectedUnit = null;
                row.selectedPrice = 0.0;
                _updateRowPacketOptions(row);
              });
            },
            validator: (v) => v == null ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: row.qtyController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    hintText: 'Qty',
                  ),
                  onChanged:
                      (_) => setState(
                        () {},
                      ), // Trigger total recalculation if needed
                  validator:
                      (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  initialValue: row.selectedUnit,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Packet Size'),
                  items:
                      row.packetSizeOptions
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(
                                e,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (v) {
                    setState(() {
                      row.selectedUnit = v;
                      _updateRowPrice(row);
                    });
                  },
                  validator: (v) => v == null ? 'Required' : null,
                ),
              ),
            ],
          ),
          if (row.selectedPrice > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Rate: ₹${row.selectedPrice}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textGray,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Amount: ₹${(row.selectedPrice * (double.tryParse(row.qtyController.text) ?? 0)).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          if (row.selectedItem != null && row.selectedUnit != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 14,
                    color:
                        (_myStock[row.selectedItem]?[row.selectedUnit] ?? 0) > 0
                            ? Colors.green
                            : Colors.red,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Available: ${(_myStock[row.selectedItem]?[row.selectedUnit] ?? 0.0).toStringAsFixed(1)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color:
                          (_myStock[row.selectedItem]?[row.selectedUnit] ?? 0) >
                                  0
                              ? Colors.green
                              : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Row(
      children: [
        _typeOption('RECEIVED', Colors.green, Icons.download_rounded),
        if (_userRole != 'executive' && _userRole != 'telecaller') ...[
          const SizedBox(width: 8),
          _typeOption('DELIVERED', Colors.orange, Icons.upload_rounded),
          const SizedBox(width: 8),
          _typeOption(
            'RETURN',
            Colors.blue,
            Icons.settings_backup_restore_rounded,
          ),
        ],
      ],
    );
  }

  Widget _typeOption(String type, Color color, IconData icon) {
    final bool isSelected = _transactionType == type;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _transactionType = type),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.1) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? color : AppColors.secondary,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Icon(icon, color: isSelected ? color : AppColors.textGray),
                const SizedBox(height: 4),
                Text(
                  type == 'RECEIVED'
                      ? 'Received'
                      : (type == 'DELIVERED' ? 'Delivered' : 'Return'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? color : AppColors.textGray,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSuccessDialog() {
    final now = DateTime.now();
    final itemsForChallan =
        _itemRows
            .map(
              (row) => {
                'name': row.selectedItem,
                'unit': row.selectedUnit,
                'quantity': double.tryParse(row.qtyController.text) ?? 0.0,
                'price': row.selectedPrice,
              },
            )
            .toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            contentPadding: const EdgeInsets.all(32),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_outline_rounded,
                    color: Colors.green,
                    size: 64,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Stock Recorded!',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'The ${_transactionType.toLowerCase()} entry for ${widget.farmName} has been saved successfully.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textGray),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () {
                    PdfService.generateStockChallan(
                      items: itemsForChallan,
                      farmName: widget.farmName,
                      transactionType: _transactionType,
                      date: now,
                    );
                  },
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Share Challan'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(
                      context,
                      true,
                    ); // Go back to management screen
                  },
                  child: const Text(
                    'Done',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}

class StockItemRow {
  String? selectedItem;
  final qtyController = TextEditingController();
  String? selectedUnit;
  double selectedPrice = 0.0;
  List<String> packetSizeOptions = [];
}
