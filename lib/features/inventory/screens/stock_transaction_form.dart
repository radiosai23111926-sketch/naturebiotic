import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:nature_biotic/services/local_database_service.dart';
import 'package:nature_biotic/services/sync_manager.dart';
import 'package:uuid/uuid.dart';

class StockTransactionForm extends StatefulWidget {
  final String transactionType; // PURCHASE, DELIVERY, RETURN
  final Map<String, dynamic>? initialData;

  const StockTransactionForm({
    super.key,
    required this.transactionType,
    this.initialData,
  });

  @override
  State<StockTransactionForm> createState() => _StockTransactionFormState();
}

class _StockTransactionFormState extends State<StockTransactionForm> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isLoadingData = true;

  final _itemNameController = TextEditingController();
  final _buyerNameController = TextEditingController();

  String? _selectedExecutiveId;
  String? _userRole;
  List<Map<String, dynamic>> _staffMembers = [];
  Map<int, String> _productVendors = {};
  List<String> _allVendors = [];
  Map<String, Map<String, double>> _detailedStock = {};

  // Product Dropdown Data
  List<Map<String, dynamic>> _masterProducts = [];
  List<_StockItem> _items = [];
  int? _editingIndex = 0; // Track which item is currently being edited

  @override
  void initState() {
    super.initState();
    _items = [_StockItem()];
    _loadData();
  }

  Future<void> _loadData() async {
    final user = SupabaseService.client.auth.currentUser;
    final profile = await SupabaseService.getProfile();

    if (mounted) {
      setState(() {
        _userRole = profile?['role'];
        if (_userRole == 'executive' || _userRole == 'telecaller') {
          _selectedExecutiveId = user?.id;
        }
      });
    }

    try {
      final products = await SupabaseService.getHierarchicalDropdownOptions(
        'product_name',
      );
      final vendorMappings = await SupabaseService.getDropdownOptions(
        'product_vendor_map',
      );

      final Map<int, String> vendorMap = {};
      for (var mapping in vendorMappings) {
        if (mapping['parent_id'] != null) {
          vendorMap[mapping['parent_id'] as int] = mapping['label'] ?? '';
        }
      }

      if (mounted) {
        setState(() {
          _masterProducts = products;
          _productVendors = vendorMap;
          _allVendors =
              vendorMappings
                  .map((m) => (m['label'] as String?)?.trim() ?? '')
                  .where((v) => v.isNotEmpty)
                  .toSet()
                  .toList();

          // If editing, populate the form
          if (widget.initialData != null) {
            final data = widget.initialData!;
            _selectedExecutiveId = data['executive_id'];

            _items = [];
            // Find and set selected product and variant
            for (var p in products) {
              if (p['label'] == data['item_name']) {
                final item = _StockItem(
                  product: p,
                  qty: data['quantity']?.toString(),
                  unit: data['unit']?.toString(),
                  vendor: data['vendor_name']?.toString(),
                );

                final variants = List<Map<String, dynamic>>.from(
                  p['variants'] ?? [],
                );
                for (var v in variants) {
                  if (v['label'] == item.unitController.text) {
                    item.variant = v;
                    break;
                  }
                }
                _items.add(item);
                break;
              }
            }
            if (_items.isEmpty) _items = [_StockItem()];
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading products: $e');
    }

    if (widget.transactionType == 'DELIVERY' ||
        widget.transactionType == 'RETURN') {
      // For Store/Admin users, show the dropdown. For Executives/Telecallers, we already set the ID.
      if (_userRole != 'executive' && _userRole != 'telecaller') {
        final staff = await SupabaseService.getAllStaff();
        final storeStock = await SupabaseService.getDetailedStoreStock();
        if (mounted) {
          setState(() {
            _staffMembers = staff;
            _detailedStock = storeStock;
            _isLoadingData = false;
          });
        }
      } else {
        // Fetch detailed stock for validation
        final stock = await SupabaseService.getDetailedExecutiveStock();
        if (mounted) {
          setState(() {
            _detailedStock = stock;
            _isLoadingData = false;
          });
        }
      }
    } else {
      setState(() => _isLoadingData = false);
    }
  }

  Future<void> _submit() async {
    // Custom validation check
    if (widget.transactionType == 'DELIVERY' &&
        (_userRole == 'store' ||
            _userRole == 'manager' ||
            _userRole == 'admin')) {
      if (_selectedExecutiveId == null &&
          _buyerNameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a staff member or enter buyer name'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    if (!_formKey.currentState!.validate()) return;

    // --- VALIDATION ---
    for (var item in _items) {
      if (item.product == null || item.variant == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select product and size for all items'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final double qty = double.tryParse(item.quantityController.text) ?? 0;
      if (qty <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid quantity for all items'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Stock validation for Executives/Telecallers on RETURN
      if ((_userRole == 'executive' || _userRole == 'telecaller') &&
          widget.transactionType == 'RETURN') {
        final productName = item.product?['label'] ?? '';
        final variantName = item.variant?['label'] ?? '';
        final availableQty = _detailedStock[productName]?[variantName] ?? 0.0;

        if (qty > availableQty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red,
              content: Text(
                'Insufficient stock for $productName ($variantName). Available: $availableQty',
              ),
            ),
          );
          return;
        }
      }

      // Stock validation for Store/Admin on DELIVERY
      if ((_userRole == 'store' || _userRole == 'admin') &&
          widget.transactionType == 'DELIVERY') {
        final productName = item.product?['label'] ?? '';
        final variantName = item.variant?['label'] ?? '';
        final availableQty = _detailedStock[productName]?[variantName] ?? 0.0;

        if (qty > availableQty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red,
              content: Text(
                'Insufficient store stock for $productName ($variantName). Available: $availableQty',
              ),
            ),
          );
          return;
        }
      }
    }

    setState(() => _isSaving = true);
    try {
      final user = SupabaseService.client.auth.currentUser;
      final transactionId = const Uuid().v4();

      final isDirectPurchase =
          widget.transactionType == 'DELIVERY' &&
          (_userRole == 'store' ||
              _userRole == 'manager' ||
              _userRole == 'admin') &&
          _selectedExecutiveId == null &&
          _buyerNameController.text.trim().isNotEmpty;

      final List<Map<String, dynamic>> transactionList = [];

      int itemIndex = 0;
      for (var item in _items) {
        final newTransactionId = const Uuid().v4();
        transactionList.add({
          'id':
              (widget.initialData != null && itemIndex == 0)
                  ? widget.initialData!['id']
                  : newTransactionId,
          'item_name': item.product?['label'] ?? '',
          'transaction_type': widget.transactionType,
          'quantity': double.parse(item.quantityController.text),
          'unit': item.unitController.text,
          'executive_id': isDirectPurchase ? null : _selectedExecutiveId,
          'vendor_name':
              widget.transactionType == 'REQUEST'
                  ? 'Store'
                  : (isDirectPurchase
                      ? _buyerNameController.text.trim()
                      : item.vendorController.text.trim()),
          'status':
              (widget.transactionType == 'PURCHASE' || isDirectPurchase)
                  ? 'ACCEPTED'
                  : 'PENDING',
          'created_by': user?.id,
          'created_at':
              widget.initialData?['created_at'] ??
              DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          if (isDirectPurchase) 'accepted_at': DateTime.now().toIso8601String(),
        });
        itemIndex++;
      }

      if (kIsWeb) {
        if (widget.initialData != null) {
          await SupabaseService.updateStoreTransaction(
            transactionList.first['id'],
            transactionList.first,
          );
        } else {
          for (var data in transactionList) {
            await SupabaseService.addStoreTransaction(data);
          }
        }
      } else {
        int dbItemIndex = 0;
        for (var data in transactionList) {
          await LocalDatabaseService.saveAndQueue(
            tableName: 'store_transactions',
            data: data,
            operation:
                widget.initialData != null && dbItemIndex == 0
                    ? 'UPDATE'
                    : 'INSERT',
          );
          dbItemIndex++;
        }
        // Trigger immediate sync to push the transaction to Supabase for the receiver
        SyncManager().sync();
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction recorded successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String title = 'Record Stock';
    if (widget.transactionType == 'PURCHASE') title = 'Stock Purchase';
    if (widget.transactionType == 'DELIVERY') title = 'Stock Delivery';
    if (widget.transactionType == 'RETURN') title = 'Stock Return';
    if (widget.transactionType == 'REQUEST') title = 'Request Product';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(title)),
      body:
          _isLoadingData
              ? const Center(child: CircularProgressIndicator())
              : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    if (widget.transactionType == 'PURCHASE') ...[
                      const SizedBox(height: 8),
                    ],

                    if (widget.transactionType == 'DELIVERY' ||
                        widget.transactionType == 'RETURN') ...[
                      if (_userRole != 'executive' &&
                          _userRole != 'telecaller') ...[
                        _buildSectionTitle(
                          widget.transactionType == 'DELIVERY'
                              ? 'Delivery Target'
                              : 'Returning From',
                        ),
                        const SizedBox(height: 16),
                        _dropdownField(),
                        const SizedBox(height: 24),

                        if ((_userRole == 'store' ||
                                _userRole == 'manager' ||
                                _userRole == 'admin') &&
                            widget.transactionType == 'DELIVERY') ...[
                          _buildSectionTitle('Direct Sale from Store'),
                          const SizedBox(height: 8),
                          Text(
                            'To sell directly to a farmer/customer from the store, leave "Staff Member" empty and enter Buyer Name below.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          AbsorbPointer(
                            absorbing: _selectedExecutiveId != null,
                            child: Opacity(
                              opacity: _selectedExecutiveId != null ? 0.5 : 1.0,
                              child: _textField(
                                _buyerNameController,
                                'Buyer Name',
                                _selectedExecutiveId != null
                                    ? 'Clear staff to use direct sale'
                                    : 'Who bought this?',
                                Icons.person_add_alt_1_rounded,
                                optional: true,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ],
                    ],

                    _buildSectionTitle('Product Items'),
                    const SizedBox(height: 16),
                    ..._items.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;

                      if (_editingIndex == index) {
                        return _buildItemEntry(index, item);
                      } else {
                        return _buildItemSummary(index, item);
                      }
                    }),

                    const SizedBox(height: 8),
                    Center(
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _items.add(_StockItem());
                            _editingIndex = _items.length - 1;
                          });
                        },
                        icon: const Icon(Icons.add_circle_outline_rounded),
                        label: const Text('Add Another Product'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: AppColors.primary.withOpacity(0.05),
                        ),
                      ),
                    ),

                    const SizedBox(height: 48),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child:
                          _isSaving
                              ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                              : Text(
                                widget.transactionType == 'REQUEST'
                                    ? 'Submit Request'
                                    : 'Record Transaction',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Transaction will be marked as PENDING until verified by the other party.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: AppColors.textGray),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: AppColors.primary,
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label,
    String hint,
    IconData icon, {
    bool isNumeric = false,
    bool readOnly = false,
    bool optional = false,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: readOnly ? Colors.grey[100] : Colors.white,
      ),
      validator: (value) {
        if (optional) return null;
        return value == null || value.isEmpty ? 'Required' : null;
      },
    );
  }

  Widget _dropdownField() {
    return DropdownButtonFormField<String>(
      value: _selectedExecutiveId,
      decoration: InputDecoration(
        labelText: 'Select Staff Member',
        prefixIcon: const Icon(Icons.person_rounded, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
      items:
          (_staffMembers).map((staff) {
            final role = staff['role']?.toString().toUpperCase() ?? '';
            return DropdownMenuItem<String>(
              value: staff['id'],
              child: Text('${staff['full_name'] ?? 'Unknown'} ($role)'),
            );
          }).toList(),
      onChanged: (val) {
        setState(() => _selectedExecutiveId = val);
        if (val != null) {
          _buyerNameController.clear();
        }
      },
      validator: (val) {
        if (widget.transactionType == 'DELIVERY' &&
            (_userRole == 'store' ||
                _userRole == 'manager' ||
                _userRole == 'admin')) {
          return null;
        }
        return val == null ? 'Please select a staff member' : null;
      },
    );
  }

  Widget _buildItemSummary(int index, _StockItem item) {
    final productName = item.product?['label'] ?? 'Select Product';
    final variantName = item.variant?['label'] ?? '';
    final qty =
        item.quantityController.text.isEmpty
            ? '0'
            : item.quantityController.text;
    final vendor =
        item.vendorController.text.isEmpty
            ? 'No Vendor'
            : item.vendorController.text;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.secondary.withOpacity(0.2)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        title: Text(
          productName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          widget.transactionType == 'REQUEST'
              ? (variantName.isNotEmpty ? variantName : "")
              : '${variantName.isNotEmpty ? "$variantName • " : ""}$vendor',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'QTY',
                  style: TextStyle(
                    fontSize: 8,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  qty,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(
                Icons.edit_note_rounded,
                color: AppColors.primary,
                size: 22,
              ),
              onPressed: () => setState(() => _editingIndex = index),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        onTap: () => setState(() => _editingIndex = index),
      ),
    );
  }

  Widget _buildItemEntry(int index, _StockItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Item #${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Editing...',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (_items.length > 1)
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _items.removeAt(index);
                          _editingIndex = null;
                        });
                      },
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.red,
                        size: 20,
                      ),
                    ),
                  IconButton(
                    onPressed: () => setState(() => _editingIndex = null),
                    icon: const Icon(
                      Icons.check_circle_outline_rounded,
                      color: Colors.green,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildProductDropdownFor(item),
          const SizedBox(height: 12),
          if (widget.transactionType != 'REQUEST') ...[
            _buildVendorFieldFor(item),
            const SizedBox(height: 12),
          ],
          if (item.product != null) ...[
            const SizedBox(height: 12),
            _buildVariantDropdownFor(item),
          ],
          const SizedBox(height: 12),
          _textField(
            item.quantityController,
            'Quantity',
            '0.0',
            Icons.numbers_rounded,
            isNumeric: true,
          ),
        ],
      ),
    );
  }

  Widget _buildProductDropdownFor(_StockItem item) {
    return DropdownButtonFormField<Map<String, dynamic>>(
      value: item.product,
      hint: const Text('Select Product'),
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Product',
        prefixIcon: const Icon(Icons.shopping_bag_rounded, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items:
          _masterProducts.map((p) {
            return DropdownMenuItem<Map<String, dynamic>>(
              value: p,
              child: Text(
                p['label'] ?? 'Unknown',
                style: const TextStyle(fontSize: 14),
              ),
            );
          }).toList(),
      onChanged: (val) {
        setState(() {
          item.product = val;
          item.variant = null;
          item.unitController.text = 'Units';
          if (val != null && _productVendors.containsKey(val['id'])) {
            item.vendorController.text = _productVendors[val['id']]!;
          }
        });
      },
    );
  }

  Widget _buildVariantDropdownFor(_StockItem item) {
    final List<Map<String, dynamic>> variants = List<Map<String, dynamic>>.from(
      item.product?['variants'] ?? [],
    );

    return DropdownButtonFormField<Map<String, dynamic>>(
      value: item.variant,
      hint: const Text('Select Size'),
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Size',
        prefixIcon: const Icon(Icons.straighten_rounded, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items:
          variants.map((v) {
            return DropdownMenuItem<Map<String, dynamic>>(
              value: v,
              child: Text(
                v['label'] ?? 'Unknown',
                style: const TextStyle(fontSize: 14),
              ),
            );
          }).toList(),
      onChanged: (val) {
        setState(() {
          item.variant = val;
          item.unitController.text = val?['label'] ?? 'Units';
        });
      },
    );
  }

  Widget _buildVendorFieldFor(_StockItem item) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RawAutocomplete<String>(
          textEditingController: item.vendorController,
          focusNode: FocusNode(),
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return _allVendors;
            }
            return _allVendors.where((String option) {
              return option.toLowerCase().contains(
                textEditingValue.text.toLowerCase(),
              );
            });
          },
          onSelected: (String selection) {
            item.vendorController.text = selection;
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                labelText: 'Vendor Name',
                hintText: 'Select or type supplier',
                prefixIcon: const Icon(Icons.store_rounded, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onFieldSubmitted: (String value) {
                onFieldSubmitted();
              },
              validator: (value) {
                return value == null || value.isEmpty ? 'Required' : null;
              },
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: constraints.maxWidth,
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String option = options.elementAt(index);
                      return ListTile(
                        title: Text(option),
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _StockItem {
  Map<String, dynamic>? product;
  Map<String, dynamic>? variant;
  final quantityController = TextEditingController();
  final unitController = TextEditingController(text: 'Units');
  final vendorController = TextEditingController();

  _StockItem({this.product, String? qty, String? unit, String? vendor}) {
    if (qty != null) quantityController.text = qty;
    if (unit != null) unitController.text = unit;
    if (vendor != null) vendorController.text = vendor;
  }

  void dispose() {
    quantityController.dispose();
    unitController.dispose();
    vendorController.dispose();
  }
}
