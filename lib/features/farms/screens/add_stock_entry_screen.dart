import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:nature_biotic/services/local_database_service.dart';
import 'package:nature_biotic/services/sync_manager.dart';
import 'package:nature_biotic/services/pdf_service.dart';
import 'package:nature_biotic/features/farms/screens/challan_preview_screen.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:nature_biotic/core/widgets/data_entry_selector.dart';

class AddStockEntryScreen extends StatefulWidget {
  final String farmId;
  final String farmName;
  final String? farmerName;
  final String? cropName;

  const AddStockEntryScreen({
    super.key,
    required this.farmId,
    required this.farmName,
    this.farmerName,
    this.cropName,
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
  List<String> _placeOfSupplyOptions = [];
  String? _selectedPlaceOfSupply;
  bool _isGstApplicable = false;
  final _gstinController = TextEditingController();
  final _customerNameController = TextEditingController();

  bool _isLoading = false;
  bool _isDataLoading = true;
  String? _overrideStaffId;
  String? _overrideStaffRole;
  DateTime _overrideDate = DateTime.now();

  Future<void> _loadOverrideStaffStock(String staffId) async {
    setState(() => _isLoading = true);
    try {
      final overrideStock = await SupabaseService.getDetailedExecutiveStock(userId: staffId);
      if (mounted) {
        setState(() {
          _myStock = overrideStock;
          for (var row in _itemRows) {
            _updateRowPacketOptions(row);
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading override stock: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  String _userRole = 'executive';
  Map<String, Map<String, double>> _myStock = {};
  Map<String, dynamic>? _fullFarmData;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _gstinController.dispose();
    _customerNameController.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    try {
      final profile = await SupabaseService.getProfile();
      final items = await SupabaseService.getHierarchicalDropdownOptions(
        'product_name',
      );
      final units = await SupabaseService.getDropdownOptions('dose_unit');
      final farmInfo = await SupabaseService.getFarmAndFarmerInfo(widget.farmId);
      final supplyOptions = await SupabaseService.getDropdownOptions('place_of_supply');
      final gstMappings = await SupabaseService.getDropdownOptions('farmer_gst');

      if (mounted) {
        setState(() {
          _userRole = profile?['role'] ?? 'executive';
          _allProducts = items;
          _itemOptions = items.map((e) => e['label'].toString()).toList();
          _globalDoseUnits = units.map((e) => e['label'].toString()).toList();
          _placeOfSupplyOptions = supplyOptions.map((e) => e['label'].toString()).toList();
          _fullFarmData = farmInfo;

          final farmerData = farmInfo?['farmers'];
          final farmerName = widget.farmerName ?? farmerData?['name'] ?? '';
          if (farmerName.isNotEmpty) {
            _customerNameController.text = farmerName;
          }

          final farmerPlaceOfSupply = farmerData?['place_of_supply']?.toString() ?? '';
          final farmLocation = farmInfo?['location']?.toString() ?? farmInfo?['place']?.toString() ?? '';
          
          String? defaultPos;
          if (farmerPlaceOfSupply.isNotEmpty) {
            defaultPos = farmerPlaceOfSupply;
          } else if (farmLocation.isNotEmpty) {
            defaultPos = farmLocation;
          }

          if (defaultPos != null && defaultPos.isNotEmpty) {
            if (!_placeOfSupplyOptions.contains(defaultPos)) {
              _placeOfSupplyOptions.add(defaultPos);
            }
            _selectedPlaceOfSupply = defaultPos;
          }

          final farmerId = farmerData?['id']?.toString() ?? '';
          if (farmerId.isNotEmpty) {
            final matchedMapping = gstMappings.firstWhere(
              (m) => m['label']?.toString() == farmerId,
              orElse: () => <String, dynamic>{},
            );
            if (matchedMapping.isNotEmpty) {
              try {
                final desc = jsonDecode(matchedMapping['description'] ?? '{}') as Map<String, dynamic>;
                final mappedGstin = desc['gstin']?.toString() ?? '';
                final mappedPos = desc['place_of_supply']?.toString() ?? '';
                final mappedName = desc['farmer_name']?.toString() ?? '';

                if (mappedGstin.isNotEmpty) {
                  _isGstApplicable = true;
                  _gstinController.text = mappedGstin;
                  if (mappedName.isNotEmpty) {
                    _customerNameController.text = mappedName;
                  }
                  if (mappedPos.isNotEmpty) {
                    if (!_placeOfSupplyOptions.contains(mappedPos)) {
                      _placeOfSupplyOptions.add(mappedPos);
                    }
                    _selectedPlaceOfSupply = mappedPos;
                  }
                }
              } catch (e) {
                debugPrint('Error parsing farmer GST mapping: $e');
              }
            }
          }
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
    final checkRole = _overrideStaffId != null ? _overrideStaffRole : _userRole;
    if ((checkRole == 'executive' || checkRole == 'telecaller') &&
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
          return;
        }
      }
    }

    setState(() => _isLoading = true);
    String generatedDcNo;
    try {
      generatedDcNo = await PdfService.generateNextDcNumber();
    } catch (e) {
      generatedDcNo = 'SAI${DateTime.now().millisecondsSinceEpoch}';
    } finally {
      setState(() => _isLoading = false);
    }

    final itemsForChallan = _itemRows.map((row) => {
      'name': row.selectedItem,
      'unit': row.selectedUnit,
      'quantity': double.tryParse(row.qtyController.text) ?? 0.0,
      'price': row.selectedPrice,
    }).toList();

    final farmerData = _fullFarmData?['farmers'];
    
    final shouldSave = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ChallanPreviewScreen(
          items: itemsForChallan,
          farmName: widget.farmName,
          farmerName: _isGstApplicable ? _customerNameController.text.trim() : (widget.farmerName ?? farmerData?['name'] ?? 'N/A'),
          cropName: widget.cropName ?? 'N/A',
          transactionType: _transactionType,
          date: _overrideStaffId != null ? _overrideDate : DateTime.now(),
          farmerAddress: farmerData?['address'] ?? _fullFarmData?['landmark'] ?? 'N/A',
          farmerContact: farmerData?['mobile'] ?? 'N/A',
          dcNumber: generatedDcNo,
          placeOfSupply: _selectedPlaceOfSupply,
          customerGstin: _isGstApplicable ? _gstinController.text.trim() : null,
        ),
      ),
    );

    if (shouldSave != true) return;

    setState(() => _isLoading = true);
    try {
      final timestamp = DateTime.now().toIso8601String();
      final List<Map<String, dynamic>> savedData = [];

      for (var row in _itemRows) {
        final data = {
          'id': const Uuid().v4(),
          'farm_id': widget.farmId,
          'item_name': row.selectedItem,
          'transaction_type': _transactionType,
          'quantity': double.tryParse(row.qtyController.text) ?? 0.0,
          'unit': row.selectedUnit,
          'executive_id': _overrideStaffId ?? SupabaseService.client.auth.currentUser?.id,
          'created_at': _overrideStaffId != null ? _overrideDate.toIso8601String() : timestamp,
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
        savedData.add(data);
      }

      // Automatically create a draft bill if transaction type is RECEIVED
      if (_transactionType == 'RECEIVED') {
        final List<Map<String, dynamic>> billItems = [];
        double totalTaxable = 0.0;
        double totalTax = 0.0;
        double grandTotal = 0.0;

        for (var row in _itemRows) {
          final qty = double.tryParse(row.qtyController.text) ?? 0.0;
          final price = row.selectedPrice;
          final totalItemPrice = qty * price;

          // Find the product and variant to resolve tax_percentage
          final product = _allProducts.firstWhere(
            (p) => p['label'] == row.selectedItem,
            orElse: () => {},
          );
          final List variants = product['variants'] ?? [];
          Map<String, dynamic> variant = {};
          double taxPercentage = 0.0;
          if (variants.isNotEmpty) {
            final found = variants.firstWhere(
              (v) => v['label'] == row.selectedUnit,
              orElse: () => {},
            );
            if (found is Map) {
              variant = Map<String, dynamic>.from(found);
            }
            if (variant.isNotEmpty) {
              taxPercentage = double.tryParse(variant['tax_percentage']?.toString() ?? '0') ?? 0.0;
            }
          }
          if (taxPercentage == 0.0 && product.isNotEmpty) {
            taxPercentage = double.tryParse(product['tax_percentage']?.toString() ?? '0') ?? 0.0;
          }

          double basePrice = totalItemPrice;
          double taxAmt = 0.0;
          if (taxPercentage > 0) {
            basePrice = (totalItemPrice * 100) / (100 + taxPercentage);
            basePrice = double.parse(basePrice.toStringAsFixed(2));
            taxAmt = totalItemPrice - basePrice;
            taxAmt = double.parse(taxAmt.toStringAsFixed(2));
          }

          totalTaxable += basePrice;
          totalTax += taxAmt;
          grandTotal += totalItemPrice;

          String hsnCode = variant['hsn_code']?.toString() ?? '';
          if (hsnCode.isEmpty && product.isNotEmpty) {
            hsnCode = product['hsn_code']?.toString() ?? '';
          }
          String description = variant['description']?.toString() ?? '';
          if (description.isEmpty && product.isNotEmpty) {
            description = product['description']?.toString() ?? '';
          }

          billItems.add({
            'name': row.selectedItem,
            'unit': row.selectedUnit,
            'quantity': qty,
            'offer_price': price,
            'tax_percentage': taxPercentage,
            'hsn_code': hsnCode,
            'description': description,
          });
        }

        final billData = {
          'id': const Uuid().v4(),
          'farm_id': widget.farmId,
          'executive_id': _overrideStaffId ?? SupabaseService.client.auth.currentUser?.id,
          'challan_no': generatedDcNo,
          'challan_date': _overrideStaffId != null ? _overrideDate.toIso8601String() : timestamp,
          'items': billItems,
          'discount_type': 'none',
          'discount_value': 0.0,
          'total_discount': 0.0,
          'total_taxable_amount': totalTaxable,
          'total_tax_amount': totalTax,
          'grand_total': grandTotal,
          'status': 'PENDING_BILLING',
          'place_of_supply': _selectedPlaceOfSupply,
          'customer_gstin': _isGstApplicable && _gstinController.text.trim().isNotEmpty ? _gstinController.text.trim() : null,
          'customer_name': _isGstApplicable && _customerNameController.text.trim().isNotEmpty ? _customerNameController.text.trim() : null,
          'created_at': _overrideStaffId != null ? _overrideDate.toIso8601String() : timestamp,
          'updated_at': _overrideStaffId != null ? _overrideDate.toIso8601String() : timestamp,
        };

        if (kIsWeb) {
          await SupabaseService.addBill(billData);
        } else {
          await LocalDatabaseService.saveAndQueue(
            tableName: 'bills',
            data: billData,
            operation: 'INSERT',
          );
        }
      }

      if (!kIsWeb) {
        SyncManager().sync();
      }

      if (mounted) {
        _showSuccessDialog(savedData, generatedDcNo);
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
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('New Sales Entry', style: TextStyle(fontSize: 16)),
            Text(
              '${widget.farmerName ?? 'Farmer'} • ${widget.farmName}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
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
                      DataEntrySelector(
                        onStaffChanged: (profile) {
                          _overrideStaffId = profile?['id']?.toString();
                          _overrideStaffRole = profile?['role']?.toString();
                          if (_overrideStaffId != null) {
                            _loadOverrideStaffStock(_overrideStaffId!);
                          }
                        },
                        onDateChanged: (dt) => _overrideDate = dt,
                      ),
                      const SizedBox(height: 16),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedPlaceOfSupply,
                        decoration: const InputDecoration(
                          labelText: 'Place of Supply',
                          prefixIcon: Icon(Icons.location_on_outlined),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: _placeOfSupplyOptions
                            .map(
                              (e) => DropdownMenuItem(
                                value: e,
                                child: Text(e, style: const TextStyle(fontSize: 13)),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          setState(() {
                            _selectedPlaceOfSupply = v;
                          });
                        },
                        validator: (v) {
                          if (_isGstApplicable && (v == null || v.isEmpty)) {
                            return 'Place of Supply is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _customerNameController,
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Customer Name (for GST)',
                          prefixIcon: Icon(Icons.person_outline),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        validator: (v) {
                          if (_isGstApplicable && (v == null || v.trim().isEmpty)) {
                            return 'Customer Name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _gstinController,
                        style: const TextStyle(fontSize: 13),
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Customer GSTIN',
                          prefixIcon: Icon(Icons.badge_outlined),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (widget.cropName != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Crop: ${widget.cropName}',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),

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
                                  : const Text('Preview & Save'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: DropdownButtonFormField<String>(
                value: row.selectedItem,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Item Name',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items:
                    _allProducts
                        .map(
                          (e) {
                            final imgUrl = e['image_url']?.toString();
                            final hasImg = imgUrl != null && imgUrl.isNotEmpty && imgUrl != 'null';
                            return DropdownMenuItem(
                              value: e['label'].toString(),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: AppColors.secondary.withOpacity(0.5),
                                    backgroundImage: hasImg ? NetworkImage(imgUrl) : null,
                                    child: hasImg
                                        ? null
                                        : const Icon(
                                            Icons.inventory_2_rounded,
                                            color: AppColors.primary,
                                            size: 12,
                                          ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      e['label'].toString(),
                                      style: const TextStyle(fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
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
                validator: (v) => v == null ? 'Req' : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<String>(
                value: row.selectedUnit,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Size',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items:
                    row.packetSizeOptions
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(
                              e,
                              style: const TextStyle(fontSize: 11),
                              overflow: TextOverflow.ellipsis,
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
                validator: (v) => v == null ? 'Req' : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: row.qtyController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Qty',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) => (v == null || v.isEmpty) ? 'Req' : null,
              ),
            ),
            if (_itemRows.length > 1)
              IconButton(
                onPressed: () => _removeRow(index),
                icon: const Icon(
                  Icons.remove_circle_outline,
                  color: Colors.red,
                  size: 20,
                ),
                padding: const EdgeInsets.only(top: 10, left: 4),
                constraints: const BoxConstraints(),
              ),
          ],
        ),
        if (row.selectedItem != null && row.selectedUnit != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 4),
            child: Row(
              children: [
                Text(
                  'Avl: ${(_myStock[row.selectedItem]?[row.selectedUnit] ?? 0.0).toStringAsFixed(1)}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color:
                        (_myStock[row.selectedItem]?[row.selectedUnit] ?? 0) > 0
                            ? Colors.green
                            : Colors.red,
                  ),
                ),
                const Spacer(),
                if (row.selectedPrice > 0)
                  Text(
                    'Amt: ₹${(row.selectedPrice * (double.tryParse(row.qtyController.text) ?? 0)).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: AppColors.primary,
                    ),
                  ),
              ],
            ),
          ),
        const Divider(height: 24),
      ],
    );
  }

  void _showSuccessDialog(List<Map<String, dynamic>> savedData, String dcNumber) {
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
          (dialogContext) => AlertDialog(
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
                  'Sales Recorded!',
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
                  onPressed: () async {
                    try {
                      final farmerData = _fullFarmData?['farmers'];
                      await PdfService.generateStockChallan(
                        items: itemsForChallan,
                        farmName: widget.farmName,
                        farmerName: _isGstApplicable ? _customerNameController.text.trim() : (widget.farmerName ?? farmerData?['name'] ?? 'N/A'),
                        cropName: widget.cropName ?? 'N/A',
                        transactionType: _transactionType,
                        date: now,
                        farmerAddress: farmerData?['address'] ?? _fullFarmData?['landmark'] ?? 'N/A',
                        farmerContact: farmerData?['mobile'] ?? 'N/A',
                        dcNumber: dcNumber,
                        placeOfSupply: _selectedPlaceOfSupply,
                        customerGstin: _isGstApplicable ? _gstinController.text.trim() : null,
                      );
                    } catch (e) {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text('Error sharing challan: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
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
                    Navigator.pop(dialogContext); // Close dialog
                    Navigator.pop(
                      context,
                      savedData,
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
