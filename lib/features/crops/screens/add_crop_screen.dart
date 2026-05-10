import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:nature_biotic/services/local_database_service.dart';
import 'package:nature_biotic/services/sync_manager.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AddCropScreen extends StatefulWidget {
  final String? farmId;
  final Map<String, dynamic>? crop;
  const AddCropScreen({super.key, this.farmId, this.crop});

  @override
  State<AddCropScreen> createState() => _AddCropScreenState();
}

class _AddCropScreenState extends State<AddCropScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ageController = TextEditingController();
  final _lifeController = TextEditingController();
  final _countController = TextEditingController();
  final _acreController = TextEditingController();
  final _yieldController = TextEditingController();

  bool _isLoading = true;
  bool _isConfigLoading = true;
  bool _isEdit = false;
  String? _userRole;

  List<Map<String, dynamic>> _masterCrops = [];
  List<Map<String, dynamic>> _farms = [];
  int? _selectedCropId;
  int? _selectedVarietyId;
  String? _selectedFarmId;

  // Unit Lists
  List<String> _ageUnits = ['Years', 'Months'];
  List<String> _lifeUnits = ['Years', 'Months'];
  List<String> _acreUnits = ['Acres', 'Cent'];
  List<String> _yieldUnits = ['Tons', 'Kg', 'Quintals'];
  List<String> _countUnits = ['Plants', 'Saplings'];

  // Selected Units
  String _selectedAgeUnit = 'Years';
  String _selectedLifeUnit = 'Years';
  String _selectedAcreUnit = 'Acres';
  String _selectedYieldUnit = 'Tons';
  String _selectedYieldPeriodUnit = 'Per Month';
  String _selectedCountUnit = 'Plants';

  List<String> _yieldPeriodUnits = [
    'Per Month',
    'Per Week',
    'Per Season',
    'Per Year',
  ];

  @override
  void initState() {
    super.initState();
    _isEdit = widget.crop != null;
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isConfigLoading = true;
      _isLoading = true;
    });

    try {
      final profile = await SupabaseService.getProfile();
      _userRole = profile?['role'];
    } catch (_) {}

    await Future.wait([
      _loadMasterData(),
      _loadDropdownUnits(),
      if (widget.farmId == null) _loadFarms(),
    ]);

    if (_isEdit) {
      _populateForEdit();
    }

    if (mounted) {
      setState(() {
        _isConfigLoading = false;
        _isLoading = false;
      });
    }
  }

  void _populateForEdit() {
    if (widget.crop == null) return;

    _selectedFarmId = widget.crop!['farm_id']?.toString();

    // Attempt to match master crop and variety
    final cropName = widget.crop!['name'];
    final varietyName = widget.crop!['variety'];

    try {
      final matchedCrop = _masterCrops.firstWhere((c) => c['name'] == cropName);
      _selectedCropId = matchedCrop['id'];

      final varieties = List<Map<String, dynamic>>.from(
        matchedCrop['master_crop_varieties'] ?? [],
      );
      final matchedVariety = varieties.firstWhere(
        (v) => v['variety_name'] == varietyName,
      );
      _selectedVarietyId = matchedVariety['id'];
    } catch (_) {
      // If master data changed, we just keep IDs null and user selects again
    }

    // Split "Value Unit"
    void split(
      String? full,
      TextEditingController ctrl,
      Function(String) setUnit,
      List<String> units,
    ) {
      if (full == null || full.isEmpty) return;
      final parts = full.split(' ');
      if (parts.isNotEmpty) ctrl.text = parts[0];
      if (parts.length > 1) {
        final unit = parts.sublist(1).join(' ');
        if (units.contains(unit)) setUnit(unit);
      }
    }

    split(
      widget.crop!['age'],
      _ageController,
      (v) => _selectedAgeUnit = v,
      _ageUnits,
    );
    split(
      widget.crop!['life'],
      _lifeController,
      (v) => _selectedLifeUnit = v,
      _lifeUnits,
    );
    split(
      widget.crop!['count'],
      _countController,
      (v) => _selectedCountUnit = v,
      _countUnits,
    );
    split(
      widget.crop!['acre'],
      _acreController,
      (v) => _selectedAcreUnit = v,
      _acreUnits,
    );

    // Yield "Value Unit Period"
    final yFull = widget.crop!['expected_yield'] as String?;
    if (yFull != null && yFull.isNotEmpty) {
      final yParts = yFull.split(' ');
      if (yParts.isNotEmpty) _yieldController.text = yParts[0];

      for (var unit in _yieldUnits) {
        if (yFull.contains(unit)) _selectedYieldUnit = unit;
      }
      for (var period in _yieldPeriodUnits) {
        if (yFull.contains(period)) _selectedYieldPeriodUnit = period;
      }
    }
  }

  Future<void> _loadDropdownUnits() async {
    try {
      final results = await Future.wait([
        SupabaseService.getDropdownOptions('age_unit'),
        SupabaseService.getDropdownOptions('life_unit'),
        SupabaseService.getDropdownOptions('count_unit'),
        SupabaseService.getDropdownOptions('acre_unit'),
        SupabaseService.getDropdownOptions('yield_unit'),
        SupabaseService.getDropdownOptions('yield_period'),
      ]);

      if (mounted) {
        setState(() {
          if (results[0].isNotEmpty) {
            _ageUnits = results[0].map((e) => e['label'] as String).toList();
          }
          if (results[1].isNotEmpty) {
            _lifeUnits = results[1].map((e) => e['label'] as String).toList();
          }
          if (results[2].isNotEmpty) {
            _countUnits = results[2].map((e) => e['label'] as String).toList();
          }
          if (results[3].isNotEmpty) {
            _acreUnits = results[3].map((e) => e['label'] as String).toList();
          }
          if (results[4].isNotEmpty) {
            _yieldUnits = results[4].map((e) => e['label'] as String).toList();
          }
          if (results[5].isNotEmpty) {
            _yieldPeriodUnits =
                results[5].map((e) => e['label'] as String).toList();
          }

          if (!_isEdit) {
            _selectedAgeUnit = _ageUnits.first;
            _selectedLifeUnit = _lifeUnits.first;
            _selectedCountUnit = _countUnits.first;
            _selectedAcreUnit = _acreUnits.first;
            _selectedYieldUnit = _yieldUnits.first;
            _selectedYieldPeriodUnit = _yieldPeriodUnits.first;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading units: $e');
    }
  }

  Future<void> _loadFarms() async {
    try {
      final farms = await SupabaseService.getFarms();
      if (mounted) {
        setState(() {
          _farms = farms;
        });
      }
    } catch (e) {
      debugPrint('Error loading farms: $e');
    }
  }

  Future<void> _loadMasterData() async {
    try {
      final crops = await SupabaseService.getMasterCrops();
      if (mounted) {
        setState(() {
          _masterCrops = crops;
          _isConfigLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        // Fallback or warning
      }
    }
  }

  @override
  void dispose() {
    _ageController.dispose();
    _lifeController.dispose();
    _countController.dispose();
    _acreController.dispose();
    _yieldController.dispose();
    super.dispose();
  }

  Future<void> _showQuickAddVariety() async {
    if (_selectedCropId == null) return;

    final varietyController = TextEditingController();
    final lifeController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Quick Add Variety'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: varietyController,
                  decoration: const InputDecoration(
                    labelText: 'Variety Name',
                    hintText: 'e.g. G-4 or Local',
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: lifeController,
                  decoration: const InputDecoration(
                    labelText: 'Expected Life (Optional)',
                    hintText: 'e.g. 6 Months',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Add'),
              ),
            ],
          ),
    );

    if (result == true && varietyController.text.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        await SupabaseService.addMasterVariety(
          _selectedCropId!,
          varietyController.text.trim(),
          lifeController.text.trim(),
        );

        // Reload master data to get the new variety with its ID
        await _loadMasterData();

        // Find the newly added variety to select it
        final updatedCrop = _masterCrops.firstWhere(
          (c) => c['id'] == _selectedCropId,
        );
        final updatedVarieties = List<Map<String, dynamic>>.from(
          updatedCrop['master_crop_varieties'] ?? [],
        );

        final newVar = updatedVarieties.firstWhere(
          (v) => v['variety_name'] == varietyController.text.trim(),
        );

        if (mounted) {
          setState(() {
            _selectedVarietyId = newVar['id'];
            _lifeController.text = lifeController.text.trim();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Variety added and selected'),
              backgroundColor: AppColors.primary,
            ),
          );
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
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCropId == null || _selectedVarietyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select Crop and Variety'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final crop = _masterCrops.firstWhere(
      (c) => c['id'] == _selectedCropId,
      orElse: () => <String, dynamic>{'name': 'Unknown'},
    );
    final varieties = List<Map<String, dynamic>>.from(
      crop['master_crop_varieties'] ?? [],
    );
    final variety = varieties.firstWhere(
      (v) => v['id'] == _selectedVarietyId,
      orElse: () => <String, dynamic>{'variety_name': 'Unknown'},
    );

    final farmIdToUse = widget.farmId ?? _selectedFarmId;
    if (farmIdToUse == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a Farm'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final cropData = {
        'farm_id': farmIdToUse,
        'name': crop['name'],
        'variety': variety['variety_name'],
        'age': '${_ageController.text.trim()} $_selectedAgeUnit',
        'life': '${_lifeController.text.trim()} $_selectedLifeUnit',
        'count': '${_countController.text.trim()} $_selectedCountUnit',
        'acre': '${_acreController.text.trim()} $_selectedAcreUnit',
        'expected_yield':
            '${_yieldController.text.trim()} $_selectedYieldUnit $_selectedYieldPeriodUnit',
        'created_at':
            _isEdit
                ? (widget.crop!['created_at'] ??
                    DateTime.now().toIso8601String())
                : DateTime.now().toIso8601String(),
      };

      if (kIsWeb) {
        if (_isEdit) {
          await SupabaseService.updateCrop(
            widget.crop!['id'].toString(),
            cropData,
          );
        } else {
          await SupabaseService.addCrop(cropData);
        }
      } else {
        final offlineData = {
          ...cropData,
          if (_isEdit) 'id': widget.crop!['id'].toString(),
        };
        await LocalDatabaseService.saveAndQueue(
          tableName: 'crops',
          data: offlineData,
          operation: _isEdit ? 'UPDATE' : 'INSERT',
        );
        // Trigger sync
        SyncManager().sync();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEdit ? 'Crop Updated Successfully' : 'Crop Added Successfully',
            ),
            backgroundColor: AppColors.primary,
          ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(_isEdit ? 'Edit Crop' : 'Add Crop')),
      body:
          _isConfigLoading
              ? const Center(child: CircularProgressIndicator())
              : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.farmId == null) ...[
                            const Text(
                              'Farm Selection',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textBlack,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: DropdownButtonFormField<String>(
                                value:
                                    (_selectedFarmId != null &&
                                            _farms.any(
                                              (f) =>
                                                  f['id'].toString() ==
                                                  _selectedFarmId,
                                            ))
                                        ? _selectedFarmId
                                        : null,
                                decoration: const InputDecoration(
                                  labelText: 'Select Farm',
                                  fillColor: Colors.white,
                                ),
                                items:
                                    _farms
                                        .map(
                                          (farm) => DropdownMenuItem<String>(
                                            value: farm['id'].toString(),
                                            child: Text(
                                              farm['name'] ?? 'Unknown Farm',
                                            ),
                                          ),
                                        )
                                        .toList(),
                                onChanged:
                                    (id) =>
                                        setState(() => _selectedFarmId = id),
                                validator: (v) => v == null ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                          const Text(
                            'Crop Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textBlack,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Column(
                              children: [
                                DropdownButtonFormField<int>(
                                  value:
                                      (_selectedCropId != null &&
                                              _masterCrops.any(
                                                (c) =>
                                                    c['id'] == _selectedCropId,
                                              ))
                                          ? _selectedCropId
                                          : null,
                                  decoration: const InputDecoration(
                                    labelText: 'Crop Name',
                                    fillColor: Colors.white,
                                  ),
                                  items:
                                      _masterCrops
                                          .map(
                                            (crop) => DropdownMenuItem<int>(
                                              value: crop['id'],
                                              child: Text(crop['name']),
                                            ),
                                          )
                                          .toList(),
                                  onChanged: (id) {
                                    setState(() {
                                      _selectedCropId = id;
                                      _selectedVarietyId = null;
                                      _lifeController.clear();
                                      _selectedLifeUnit = 'Years';
                                    });
                                  },
                                  validator:
                                      (v) => v == null ? 'Required' : null,
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<int>(
                                  value:
                                      (_selectedVarietyId != null &&
                                              ((_masterCrops.firstWhere(
                                                            (c) =>
                                                                c['id'] ==
                                                                _selectedCropId,
                                                            orElse: () => {},
                                                          )['master_crop_varieties']
                                                          as List?) ??
                                                      [])
                                                  .any(
                                                    (v) =>
                                                        v['id'] ==
                                                        _selectedVarietyId,
                                                  ))
                                          ? _selectedVarietyId
                                          : null,
                                  decoration: const InputDecoration(
                                    labelText: 'Variety',
                                    fillColor: Colors.white,
                                  ),
                                  hint: const Text('Select a variety'),
                                  items:
                                      (_masterCrops.firstWhere(
                                                (c) =>
                                                    c['id'] == _selectedCropId,
                                                orElse:
                                                    () => {
                                                      'master_crop_varieties':
                                                          [],
                                                    },
                                              )['master_crop_varieties']
                                              as List)
                                          .map(
                                            (v) => DropdownMenuItem<int>(
                                              value: v['id'],
                                              child: Text(v['variety_name']),
                                            ),
                                          )
                                          .toList(),
                                  onChanged:
                                      _selectedCropId == null
                                          ? null
                                          : (id) {
                                            setState(() {
                                              _selectedVarietyId = id;
                                              if (id != null) {
                                                final crop = _masterCrops
                                                    .firstWhere(
                                                      (c) =>
                                                          c['id'] ==
                                                          _selectedCropId,
                                                    );
                                                final varieties = List<
                                                  Map<String, dynamic>
                                                >.from(
                                                  crop['master_crop_varieties'] ??
                                                      [],
                                                );
                                                final variety = varieties
                                                    .firstWhere(
                                                      (v) => v['id'] == id,
                                                      orElse:
                                                          () =>
                                                              <String, dynamic>{
                                                                'life': '',
                                                              },
                                                    );

                                                String lifeVal =
                                                    variety['life'] ?? '';
                                                if (lifeVal.contains(' ')) {
                                                  final parts = lifeVal.split(
                                                    ' ',
                                                  );
                                                  _lifeController.text =
                                                      parts[0];
                                                  if (_lifeUnits.contains(
                                                    parts[1],
                                                  )) {
                                                    _selectedLifeUnit =
                                                        parts[1];
                                                  }
                                                } else {
                                                  _lifeController.text =
                                                      lifeVal;
                                                  _selectedLifeUnit = 'Years';
                                                }
                                              }
                                            });
                                          },
                                  validator:
                                      (v) => v == null ? 'Required' : null,
                                ),
                                if (_selectedCropId != null &&
                                    _userRole == 'admin' &&
                                    (_masterCrops.firstWhere(
                                                  (c) =>
                                                      c['id'] ==
                                                      _selectedCropId,
                                                  orElse: () => {},
                                                )['master_crop_varieties']
                                                as List?)
                                            ?.isEmpty ==
                                        true)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12.0),
                                    child: TextButton.icon(
                                      onPressed: _showQuickAddVariety,
                                      icon: const Icon(
                                        Icons.add_circle_outline_rounded,
                                        size: 18,
                                      ),
                                      label: const Text(
                                        'No varieties found. Add one now?',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.orange[800],
                                        backgroundColor: Colors.orange[50],
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Growth & Yield',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textBlack,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildUnitTextField(
                                        controller: _ageController,
                                        label: 'Age',
                                        units: _ageUnits,
                                        selectedUnit: _selectedAgeUnit,
                                        onUnitChanged:
                                            (v) => setState(
                                              () => _selectedAgeUnit = v!,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildUnitTextField(
                                        controller: _lifeController,
                                        label: 'Life',
                                        units: _lifeUnits,
                                        selectedUnit: _selectedLifeUnit,
                                        onUnitChanged:
                                            (v) => setState(
                                              () => _selectedLifeUnit = v!,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildUnitTextField(
                                        controller: _countController,
                                        label: 'Count',
                                        units: _countUnits,
                                        selectedUnit: _selectedCountUnit,
                                        onUnitChanged:
                                            (v) => setState(
                                              () => _selectedCountUnit = v!,
                                            ),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildUnitTextField(
                                        controller: _acreController,
                                        label: 'Area/Scale',
                                        units: _acreUnits,
                                        selectedUnit: _selectedAcreUnit,
                                        onUnitChanged:
                                            (v) => setState(
                                              () => _selectedAcreUnit = v!,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _buildYieldTextField(
                                  controller: _yieldController,
                                  label: 'Expected Yield',
                                  units: _yieldUnits,
                                  selectedUnit: _selectedYieldUnit,
                                  onUnitChanged:
                                      (v) => setState(
                                        () => _selectedYieldUnit = v!,
                                      ),
                                  periods: _yieldPeriodUnits,
                                  selectedPeriod: _selectedYieldPeriodUnit,
                                  onPeriodChanged:
                                      (v) => setState(
                                        () => _selectedYieldPeriodUnit = v!,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 48),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleSubmit,
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
                                      : Text(
                                        _isEdit
                                            ? 'Update Crop Records'
                                            : 'Save Crop Data',
                                      ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
    );
  }

  Widget _buildYieldTextField({
    required TextEditingController controller,
    required String label,
    required List<String> units,
    required String selectedUnit,
    required Function(String?) onUnitChanged,
    required List<String> periods,
    required String selectedPeriod,
    required Function(String?) onPeriodChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: label,
        hintText: '0',
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.fromLTRB(16, 12, 0, 12),
        suffixIcon: Container(
          width: 200, // Wider for two dropdowns
          padding: const EdgeInsets.only(left: 8),
          child: Row(
            children: [
              Container(
                height: 30,
                width: 1,
                color: Colors.grey.withOpacity(0.2),
              ),
              // Unit Selection (e.g. Tons)
              Expanded(
                flex: 4,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value:
                        (units.contains(selectedUnit))
                            ? selectedUnit
                            : (units.isNotEmpty ? units.first : null),
                    isExpanded: true,
                    icon: const Icon(
                      Icons.arrow_drop_down_rounded,
                      color: AppColors.textGray,
                      size: 20,
                    ),
                    items:
                        units
                            .map(
                              (unit) => DropdownMenuItem(
                                value: unit,
                                child: Text(
                                  unit,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textGray,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                    onChanged: onUnitChanged,
                  ),
                ),
              ),
              Container(
                height: 30,
                width: 1,
                color: Colors.grey.withOpacity(0.2),
              ),
              // Period Selection (e.g. Per Month)
              Expanded(
                flex: 6,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value:
                        (periods.contains(selectedPeriod))
                            ? selectedPeriod
                            : (periods.isNotEmpty ? periods.first : null),
                    isExpanded: true,
                    icon: const Icon(
                      Icons.arrow_drop_down_rounded,
                      color: AppColors.textGray,
                      size: 20,
                    ),
                    style: const TextStyle(overflow: TextOverflow.ellipsis),
                    items:
                        periods
                            .map(
                              (period) => DropdownMenuItem(
                                value: period,
                                child: Text(
                                  period,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textGray,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                    onChanged: onPeriodChanged,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnitTextField({
    required TextEditingController controller,
    required String label,
    required List<String> units,
    required String selectedUnit,
    required Function(String?) onUnitChanged,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: label,
        hintText: '0',
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.fromLTRB(16, 12, 0, 12),
        suffixIcon: Container(
          width: 90,
          padding: const EdgeInsets.only(left: 8),
          child: Row(
            children: [
              Container(
                height: 30,
                width: 1,
                color: Colors.grey.withOpacity(0.2),
              ),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value:
                        (units.contains(selectedUnit))
                            ? selectedUnit
                            : (units.isNotEmpty ? units.first : null),
                    isExpanded: true,
                    icon: const Icon(
                      Icons.arrow_drop_down_rounded,
                      color: AppColors.textGray,
                    ),
                    items:
                        units
                            .map(
                              (unit) => DropdownMenuItem(
                                value: unit,
                                child: Text(
                                  unit,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textGray,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                    onChanged: onUnitChanged,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
