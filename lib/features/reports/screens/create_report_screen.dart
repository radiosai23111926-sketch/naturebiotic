import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:nature_biotic/services/local_database_service.dart';
import 'package:nature_biotic/services/sync_manager.dart';
import 'package:nature_biotic/features/reports/screens/report_generator_screen.dart';
import 'package:signature/signature.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class CreateReportScreen extends StatefulWidget {
  final String? preSelectedFarmId;
  final String? preSelectedCropId;
  final Map<String, dynamic>? existingReport;

  const CreateReportScreen({
    super.key,
    this.preSelectedFarmId,
    this.preSelectedCropId,
    this.existingReport,
  });

  @override
  State<CreateReportScreen> createState() => _CreateReportScreenState();
}

class _CreateReportScreenState extends State<CreateReportScreen> {
  int _currentStep = 0;
  bool _isLoading = false;

  // Data
  List<Map<String, dynamic>> _farms = [];
  List<Map<String, dynamic>> _crops = [];
  List<Map<String, dynamic>> _productOptions = [];
  List<Map<String, dynamic>> _applicationOptions = [];
  List<Map<String, dynamic>> _doseUnitOptions = [];
  List<Map<String, dynamic>> _fillerUnitOptions = [];
  List<Map<String, dynamic>> _fillerMaterialOptions = [];
  List<Map<String, dynamic>> _perUnitOptions = [];
  List<String> _suggestedProblems = [];

  // Selection
  String? _selectedFarmId;
  String? _selectedCropId;
  Map<String, dynamic>? _activeCategory;
  Map<String, dynamic>? _activeSubcategory;
  List<Map<String, dynamic>> _problemCategoriesList = [];
  List<Map<String, dynamic>> _problemSubcategoriesList = [];
  List<Map<String, dynamic>> _problemItemsList = [];
  int _categoryIndex = -1;
  int _subcategoryIndex = -1;
  String _problemSearchQuery = '';
  final Set<String> _selectedProblems = {};
  final Map<String, Uint8List?> _problemImages = {};
  final Map<String, String> _problemImageNames = {};
  final ImagePicker _picker = ImagePicker();

  // Hierarchical Problems are now fetched dynamically
  bool _isProblemIdentificationFinished = false;

  // Inputs
  final _additionalNotesController = TextEditingController();

  // Previous Inputs Categories
  Map<String, List<PreviousInputRow>> _previousInputsMap = {
    'Pesticides': [PreviousInputRow()],
    'Fungicides': [PreviousInputRow()],
    'Fertilizers': [PreviousInputRow()],
    'Bio Stimulant': [PreviousInputRow()],
    'Herbicide': [PreviousInputRow()],
  };

  // Crop/Farm Metadata for Calculations
  double _cropAcre = 0.0;
  int _cropCount = 0;

  // Recommendations Categories
  final List<RecommendationRow> _recommendationsList = [];

  // Cost Estimations Categories
  final List<CostEstimationRow> _costEstimations = [];
  DateTime? _nextVisitDate;

  final _costController =
      TextEditingController(); // To be removed or used for summary

  // Signature
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: AppColors.primary,
    exportBackgroundColor: Colors.white,
  );

  // Multi-crop storage
  final List<Map<String, dynamic>> _multiCropsData = [];

  @override
  void initState() {
    super.initState();
    _initializeAll();
  }

  Future<void> _initializeAll() async {
    await _loadFarms();
    await _fetchProblemData();
    
    // Attempt to load local draft and restore form state
    await _loadDraft();

    // If still empty after draft loading, ensure at least one row exists
    if (_recommendationsList.isEmpty) {
      _addRecommendationRow();
    }

    if (widget.preSelectedCropId != null) {
      _loadCropDetails(widget.preSelectedCropId!);
    }
    if (widget.existingReport != null) {
      _populateFromExistingReport();
    }
  }

  void _populateFromExistingReport() {
    final report = widget.existingReport!;
    _selectedFarmId = report['farm_id']?.toString();
    _selectedCropId = report['crop_id']?.toString();
    
    // For now, we populate the basic selection. 
    // Full parsing of aggregated strings is complex, 
    // so we at least ensure the context is correct.
    if (_selectedFarmId != null) {
      _loadCrops(_selectedFarmId!);
    }
  }

  @override
  void dispose() {
    _signatureController.dispose();
    _additionalNotesController.dispose();
    for (var rows in _previousInputsMap.values) {
      for (var row in rows) {
        row.controller.dispose();
      }
    }
    super.dispose();
  }

  void _addRecommendationRow() {
    setState(() {
      _recommendationsList.add(RecommendationRow());
    });
  }

  void _removeRecommendationRow(int index) {
    if (_recommendationsList.length > 1) {
      setState(() {
        _recommendationsList.removeAt(index);
      });
    }
  }

  void _syncCostEstimations() {
    final validProductNames =
        _recommendationsList
            .where((r) => r.product.text.trim().isNotEmpty)
            .map((r) => r.product.text.trim())
            .toList();

    setState(() {
      // Keep existing data if the product name matches
      final existingMap = {
        for (var row in _costEstimations) row.productName: row,
      };
      _costEstimations.clear();

      for (var name in validProductNames) {
        if (existingMap.containsKey(name)) {
          _costEstimations.add(existingMap[name]!);
        } else {
          final newRow = CostEstimationRow(productName: name);
          // Auto-fill prices from product catalog
          final product = _productOptions.firstWhere(
            (p) => p['label'] == name,
            orElse: () => {},
          );
          if (product.isNotEmpty) {
            if (product['mrp'] != null)
              newRow.mrp.text = product['mrp'].toString();
            if (product['offer_price'] != null)
              newRow.offerPrice.text = product['offer_price'].toString();
          }
          _costEstimations.add(newRow);
        }
      }
      
      _autoCalculateQuantities();
    });
  }

  void _autoCalculateQuantities() {
    for (var row in _costEstimations) {
      // Find matching recommendation
      final rec = _recommendationsList.firstWhere(
        (r) => r.product.text == row.productName,
        orElse: () => RecommendationRow(),
      );

      if (rec.product.text.isEmpty) continue;

      final double dose = double.tryParse(rec.dose.text) ?? 0;
      if (dose == 0) continue;

      double totalRequired = 0;
      final perUnit = rec.perUnit?.toLowerCase() ?? '';
      
      final double fillerQty = double.tryParse(rec.fillerQty.text) ?? 0;

      if (fillerQty > 0) {
        // Use manual quantity from form if provided
        totalRequired = dose * fillerQty;
      } else if (perUnit.contains('acre')) {
        totalRequired = dose * _cropAcre;
      } else if (perUnit.contains('plant') || perUnit.contains('tree')) {
        totalRequired = dose * _cropCount;
      } else {
        // Default to 1 if no unit matched and no filler qty provided
        totalRequired = dose;
      }

      // Match with package size
      final pkgSizeStr = row.pkgSize.text;
      if (pkgSizeStr.isEmpty) continue;

      // Parse pkg size (e.g. "250ml" or "1kg")
      final double pkgValue =
          double.tryParse(pkgSizeStr.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
      if (pkgValue == 0) continue;

      // Calculate quantity
      final double qty = totalRequired / pkgValue;
      row.qty.text = qty.ceil().toString();
    }
  }

  Future<void> _loadCropDetails(String cropId) async {
    try {
      final crops = await SupabaseService.getCrops(_selectedFarmId ?? widget.preSelectedFarmId ?? '');
      final crop = crops.firstWhere((c) => c['id'].toString() == cropId);
      
      setState(() {
        // Parse acre (e.g. "2.5 Acres")
        final acreStr = crop['acre'] as String? ?? '';
        _cropAcre = double.tryParse(acreStr.split(' ')[0]) ?? 0.0;
        
        // Parse count (e.g. "500 Plants")
        final countStr = crop['count'] as String? ?? '';
        _cropCount = int.tryParse(countStr.split(' ')[0]) ?? 0;
      });
    } catch (e) {
      debugPrint('Error loading crop details for calculation: $e');
    }
  }

  Future<void> _loadFarms() async {
    final farms = await SupabaseService.getFarms();
    setState(() {
      _farms = farms;
      if (widget.preSelectedFarmId != null) {
        _selectedFarmId = widget.preSelectedFarmId;
        _loadCrops(_selectedFarmId!);
      }
    });
  }

  Future<void> _loadCrops(String farmId) async {
    final crops = await SupabaseService.getCrops(farmId);
    setState(() {
      _crops = crops;
      if (widget.preSelectedCropId != null) {
        _selectedCropId = widget.preSelectedCropId;
        _loadLastReportData(farmId, _selectedCropId!);

        // Find crop to load suggested problems
        final crop = _crops.firstWhere(
          (c) => c['id'].toString() == _selectedCropId,
          orElse: () => {},
        );
        if (crop.isNotEmpty && crop['dropdown_options'] != null) {
          final cropIntId = int.tryParse(
            crop['dropdown_options']['id'].toString(),
          );
          if (cropIntId != null) _loadSuggestedProblems(cropIntId);
        }
        if (widget.preSelectedFarmId != null && widget.preSelectedCropId != null) {
          _currentStep = 1;
        }
      } else {
        // If draft loading restored a cropId, don't clear it unless invalid for this farm
        final bool isCurrentStillValid = crops.any((c) => c['id'].toString() == _selectedCropId);
        if (!isCurrentStillValid) {
          _selectedCropId = null;
          _suggestedProblems = [];
        } else {
          // If valid, re-trigger suggested problems for this preserved selection
          final crop = _crops.firstWhere(
            (c) => c['id'].toString() == _selectedCropId,
            orElse: () => {},
          );
          if (crop.isNotEmpty && crop['dropdown_options'] != null) {
            final cropIntId = int.tryParse(crop['dropdown_options']['id'].toString());
            if (cropIntId != null) _loadSuggestedProblems(cropIntId);
          }
        }
      }
    });
  }

  Future<void> _loadSuggestedProblems(int cropId) async {
    try {
      final mappings = await SupabaseService.getProblemsByCrop(cropId);
      setState(() {
        _suggestedProblems =
            mappings
                .map((m) => m['dropdown_options']?['label']?.toString())
                .whereType<String>()
                .toList();
      });
    } catch (_) {}
  }

  Future<void> _fetchProblemData() async {
    try {
      final categories = await SupabaseService.getDropdownOptions('problem_category');
      final products = await SupabaseService.getHierarchicalDropdownOptions('product_name');
      final applications = await SupabaseService.getDropdownOptions('application_method');
      final doseUnits = await SupabaseService.getDropdownOptions('dose_unit');
      final fillerUnits = await SupabaseService.getDropdownOptions('filler_unit');
      final fillerMaterials = await SupabaseService.getDropdownOptions('filler_material');
      final perUnits = await SupabaseService.getDropdownOptions('per_unit');

      setState(() {
        _problemCategoriesList = categories;
        _productOptions = products;
        _applicationOptions = applications;
        _doseUnitOptions = doseUnits;
        _fillerUnitOptions = fillerUnits;
        _fillerMaterialOptions = fillerMaterials;
        _perUnitOptions = perUnits;
      });
    } catch (_) {}
  }

  Future<void> _fetchSubcategories(int categoryId) async {
    setState(() => _isLoading = true);
    try {
      final subs = await SupabaseService.getDropdownOptions('problem_subcategory', parentId: categoryId);
      setState(() => _problemSubcategoriesList = subs);
    } catch (_) {
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchItems(int subcategoryId) async {
    setState(() => _isLoading = true);
    try {
      final items = await SupabaseService.getDropdownOptions('problem_item', parentId: subcategoryId);
      setState(() => _problemItemsList = items);
    } catch (_) {
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _goToNextSubcategory() async {
    if (_categoryIndex == -1) return;

    if (_subcategoryIndex < _problemSubcategoriesList.length - 1) {
      // Next subcategory in same category
      setState(() {
        _subcategoryIndex++;
        _activeSubcategory = _problemSubcategoriesList[_subcategoryIndex];
      });
      await _fetchItems(_activeSubcategory!['id']);
    } else {
      // Move to next category
      if (_categoryIndex < _problemCategoriesList.length - 1) {
        setState(() {
          _categoryIndex++;
          _activeCategory = _problemCategoriesList[_categoryIndex];
          _subcategoryIndex = 0;
          _activeSubcategory = null; // Reset to let fetchSubcategories handle it
        });
        
        setState(() => _isLoading = true);
        final subs = await SupabaseService.getDropdownOptions('problem_subcategory', parentId: _activeCategory!['id']);
        setState(() {
          _problemSubcategoriesList = subs;
          if (_problemSubcategoriesList.isNotEmpty) {
            _activeSubcategory = _problemSubcategoriesList[0];
          }
          _isLoading = false;
        });

        if (_activeSubcategory != null) {
          await _fetchItems(_activeSubcategory!['id']);
        }
      } else {
        // All categories done
        setState(() {
          _activeCategory = null;
          _activeSubcategory = null;
          _categoryIndex = -1;
          _subcategoryIndex = -1;
          _isProblemIdentificationFinished = true;
        });
      }
    }
  }

  void _goToPreviousSubcategory() async {
    if (_categoryIndex == -1) return;

    if (_subcategoryIndex > 0) {
      // Previous subcategory in same category
      setState(() {
        _subcategoryIndex--;
        _activeSubcategory = _problemSubcategoriesList[_subcategoryIndex];
      });
      await _fetchItems(_activeSubcategory!['id']);
    } else {
      // Move to previous category
      if (_categoryIndex > 0) {
        setState(() {
          _categoryIndex--;
          _activeCategory = _problemCategoriesList[_categoryIndex];
          _activeSubcategory = null;
        });

        setState(() => _isLoading = true);
        final subs = await SupabaseService.getDropdownOptions('problem_subcategory', parentId: _activeCategory!['id']);
        setState(() {
          _problemSubcategoriesList = subs;
          _subcategoryIndex = _problemSubcategoriesList.length - 1;
          if (_problemSubcategoriesList.isNotEmpty) {
            _activeSubcategory = _problemSubcategoriesList[_subcategoryIndex];
          }
          _isLoading = false;
        });

        if (_activeSubcategory != null) {
          await _fetchItems(_activeSubcategory!['id']);
        }
      } else {
        // Back to category selection
        setState(() {
          _activeCategory = null;
          _activeSubcategory = null;
          _categoryIndex = -1;
          _subcategoryIndex = -1;
        });
      }
    }
  }

  Map<String, dynamic>? _lastReport;

  Future<void> _loadLastReportData(String farmId, String cropId) async {
    if (_cropAcre == 0 && _cropCount == 0) {
      await _loadCropDetails(cropId);
    }
    final lastReport = await SupabaseService.getLastReportForCrop(
      farmId,
      cropId,
    );
    setState(() => _lastReport = lastReport);
  }

  void _importLastReportData() {
    if (_lastReport == null) return;
    final history = _lastReport!['previous_inputs'] as String?;

    setState(() {
      if (history != null && history.isNotEmpty) {
        // Clear existing and import
        _previousInputsMap = {
          'Pesticides': [],
          'Fungicides': [],
          'Fertilizers': [],
          'Bio Stimulant': [],
          'Herbicide': [],
        };

        final lines = history.split('\n');
        for (var line in lines) {
          String category = '';
          String content = '';
          if (line.startsWith('Pesticides:')) {
            category = 'Pesticides';
            content = line.replaceFirst('Pesticides:', '').trim();
          } else if (line.startsWith('Fungicides:')) {
            category = 'Fungicides';
            content = line.replaceFirst('Fungicides:', '').trim();
          } else if (line.startsWith('Fertilizers:')) {
            category = 'Fertilizers';
            content = line.replaceFirst('Fertilizers:', '').trim();
          } else if (line.startsWith('Bio Stimulant:')) {
            category = 'Bio Stimulant';
            content = line.replaceFirst('Bio Stimulant:', '').trim();
          } else if (line.startsWith('Herbicide:')) {
            category = 'Herbicide';
            content = line.replaceFirst('Herbicide:', '').trim();
          }

          if (category.isNotEmpty) {
            // Split by comma if there are multiple items
            final items = content.split(',');
            for (var item in items) {
              final trimmed = item.trim();
              if (trimmed.isNotEmpty) {
                final row = PreviousInputRow();
                row.controller.text = trimmed;
                _previousInputsMap[category]!.add(row);
              }
            }
          }
        }

        // Ensure at least one row exists if empty
        for (var cat in _previousInputsMap.keys) {
          if (_previousInputsMap[cat]!.isEmpty) {
            _previousInputsMap[cat]!.add(PreviousInputRow());
          }
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Last visit data imported'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<Map<String, dynamic>> _collectCurrentCropData() async {
    final crop = _crops.firstWhere(
      (c) => c['id'] == _selectedCropId,
      orElse: () => {'name': 'Unknown Crop'},
    );

    return {
      'crop_id': _selectedCropId,
      'crop_name': crop['name'],
      'selected_problems': Set<String>.from(_selectedProblems),
      'problem_images': Map<String, Uint8List?>.from(_problemImages),
      'problem_image_names': Map<String, String>.from(_problemImageNames),
      'additional_notes': _additionalNotesController.text.trim(),
      'previous_inputs': _previousInputsMap.map(
        (k, v) => MapEntry(
          k,
          v.map((row) => PreviousInputRow()
            ..controller.text = row.controller.text
            ..image = row.image
            ..imageName = row.imageName
            ..date = row.date
          ).toList(),
        ),
      ),
      'recommendations': _recommendationsList.map((r) => RecommendationRow()
        ..product.text = r.product.text
        ..application.text = r.application.text
        ..dose.text = r.dose.text
        ..doseUnit = r.doseUnit
        ..perUnit = r.perUnit
        ..filler.text = r.filler.text
        ..fillerQty.text = r.fillerQty.text
        ..fillerUnit = r.fillerUnit
      ).toList(),
      'cost_estimations': _costEstimations.map((c) => CostEstimationRow(productName: c.productName)
        ..pkgSize.text = c.pkgSize.text
        ..qty.text = c.qty.text
        ..mrp.text = c.mrp.text
        ..offerPrice.text = c.offerPrice.text
      ).toList(),
    };
  }

  Future<void> _saveDraft() async {
    try {
      final draft = {
        'step': _currentStep,
        'farmId': _selectedFarmId,
        'cropId': _selectedCropId,
        'problems': _selectedProblems.toList(),
        'notes': _additionalNotesController.text,
        'nextVisit': _nextVisitDate?.toIso8601String(),
        'prevInputs': _previousInputsMap.map(
          (k, v) => MapEntry(
            k,
            v
                .map(
                  (r) => {
                    'text': r.controller.text,
                    'date': r.date?.toIso8601String(),
                  },
                )
                .toList(),
          ),
        ),
        'recs': _recommendationsList
            .map(
              (r) => {
                'prod': r.product.text,
                'app': r.application.text,
                'dose': r.dose.text,
                'doseU': r.doseUnit,
                'perU': r.perUnit,
                'fill': r.filler.text,
                'fillQ': r.fillerQty.text,
                'fillU': r.fillerUnit,
              },
            )
            .toList(),
        'cost': _costEstimations
            .map(
              (c) => {
                'name': c.productName,
                'pkg': c.pkgSize.text,
                'qty': c.qty.text,
                'mrp': c.mrp.text,
                'off': c.offerPrice.text,
              },
            )
            .toList(),
      };
      await LocalDatabaseService.saveCache('visit_report_draft', [draft]);
    } catch (e) {
      debugPrint('Error saving draft: $e');
    }
  }

  Future<void> _loadDraft() async {
    try {
      final cache = await LocalDatabaseService.getCache('visit_report_draft');
      if (cache != null && cache.isNotEmpty) {
        final data = cache.first;
        setState(() {
          _currentStep = data['step'] ?? 0;
          _selectedFarmId = data['farmId'];
          _selectedCropId = data['cropId'];
          _additionalNotesController.text = data['notes'] ?? '';
          
          if (data['nextVisit'] != null) {
            _nextVisitDate = DateTime.tryParse(data['nextVisit']);
          }

          final List<dynamic>? loadedProbs = data['problems'];
          if (loadedProbs != null) {
            _selectedProblems.addAll(loadedProbs.whereType<String>());
          }

          // Restore Previous Inputs
          final dynamic prevRaw = data['prevInputs'];
          if (prevRaw != null && prevRaw is Map) {
            _previousInputsMap = {};
            prevRaw.forEach((key, list) {
              if (list is List) {
                _previousInputsMap[key.toString()] = list.map((item) {
                  final row = PreviousInputRow();
                  if (item is Map) {
                    row.controller.text = item['text'] ?? '';
                    if (item['date'] != null) {
                      row.date = DateTime.tryParse(item['date']);
                    }
                  }
                  return row;
                }).toList();
              }
            });
          }

          // Restore Recommendations
          final dynamic recsRaw = data['recs'];
          if (recsRaw != null && recsRaw is List) {
            _recommendationsList.clear();
            for (var item in recsRaw) {
              if (item is Map) {
                final r = RecommendationRow();
                r.product.text = item['prod'] ?? '';
                r.application.text = item['app'] ?? '';
                r.dose.text = item['dose'] ?? '';
                r.doseUnit = item['doseU'];
                r.perUnit = item['perU'];
                r.filler.text = item['fill'] ?? '';
                r.fillerQty.text = item['fillQ'] ?? '';
                r.fillerUnit = item['fillU'];
                _recommendationsList.add(r);
              }
            }
          }

          // Restore Costs
          final dynamic costRaw = data['cost'];
          if (costRaw != null && costRaw is List) {
            _costEstimations.clear();
            for (var item in costRaw) {
              if (item is Map) {
                final c = CostEstimationRow(productName: item['name'] ?? '');
                c.pkgSize.text = item['pkg'] ?? '';
                c.qty.text = item['qty'] ?? '';
                c.mrp.text = item['mrp'] ?? '';
                c.offerPrice.text = item['off'] ?? '';
                _costEstimations.add(c);
              }
            }
          }
        });

        // Re-trigger async dependencies
        if (_selectedFarmId != null) {
          await _loadCrops(_selectedFarmId!);
          if (_selectedCropId != null) {
            await _loadCropDetails(_selectedCropId!);
            await _loadLastReportData(_selectedFarmId!, _selectedCropId!);
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading draft: $e');
    }
  }

  Future<void> _clearDraft() async {
    try {
      await LocalDatabaseService.saveCache('visit_report_draft', []);
    } catch (_) {}
  }

  Future<void> _onAttemptToLeave() async {
    await _saveDraft();
    if (mounted) Navigator.of(context).pop();
  }

  void _resetCropStepData() {
    setState(() {
      _selectedCropId = null;
      _selectedProblems.clear();
      _problemImages.clear();
      _problemImageNames.clear();
      _activeCategory = null;
      _problemSearchQuery = '';
      _additionalNotesController.clear();
      _lastReport = null;
      _suggestedProblems = [];
      _cropAcre = 0.0;
      _cropCount = 0;

      // Reset previous inputs
      _previousInputsMap = {
        'Pesticides': [PreviousInputRow()],
        'Fungicides': [PreviousInputRow()],
        'Fertilizers': [PreviousInputRow()],
        'Bio Stimulant': [PreviousInputRow()],
        'Herbicide': [PreviousInputRow()],
      };

      // Reset recommendations
      _recommendationsList.clear();
      _recommendationsList.add(RecommendationRow());

      // Reset cost estimations
      _costEstimations.clear();
      _isProblemIdentificationFinished = false;
    });
  }

  Future<void> _handleSave() async {
    setState(() => _isLoading = true);
    try {
      // Collect current crop if not already added
      final currentCropData = await _collectCurrentCropData();
      final allCrops = [..._multiCropsData, currentCropData];

      // Aggregated fields
      String combinedProblems = '';
      String combinedHistory = '';
      String combinedRecommendations = '';
      String combinedCost = '';
      double grandTotal = 0;

      Map<String, Uint8List?> allProblemImages = {};
      Map<String, String> allProblemImageNames = {};

      for (var cropData in allCrops) {
        final cropName = cropData['crop_name'];
        final header = '--- Crop: $cropName ---\n';

        // 1. Problems
        String problemStr = (cropData['selected_problems'] as Set<String>).join(', ');
        if (cropData['additional_notes'].toString().isNotEmpty) {
          problemStr += '\nNotes: ${cropData['additional_notes']}';
        }
        
        // Handle images for this crop later during upload loop
        final cropImages = cropData['problem_images'] as Map<String, Uint8List?>;
        final cropImageNames = cropData['problem_image_names'] as Map<String, String>;
        
        // We need to make problem names unique across crops if they repeat, 
        // but for now let's just upload them. 
        // Actually, the upload loop expects problem names as keys.
        // Let's prefix them to be safe.
        cropImages.forEach((prob, bytes) {
          if (bytes != null) {
            final uniqueKey = '${cropName}_$prob';
            allProblemImages[uniqueKey] = bytes;
            allProblemImageNames[uniqueKey] = cropImageNames[prob] ?? 'image.jpg';
            // Update problem string to use the unique key for image matching
            problemStr = problemStr.replaceFirst(prob, uniqueKey);
          }
        });

        combinedProblems += header + problemStr + '\n\n';

        // 2. Previous Inputs
        String historyStr = '';
        final prevInputs = cropData['previous_inputs'] as Map<String, List<PreviousInputRow>>;
        for (var entry in prevInputs.entries) {
          final category = entry.key;
          final rows = entry.value;
          String categoryContent = '';

          for (var row in rows) {
            final text = row.controller.text.trim();
            if (text.isEmpty && row.image == null && row.date == null) continue;

            String itemString = text;
            if (row.date != null) {
              itemString += (itemString.isEmpty ? '' : ' ') + '[Date: ${_formatDate(row.date)}]';
            }

            if (row.image != null) {
              try {
                final fileName = 'prev_${DateTime.now().millisecondsSinceEpoch}_${row.imageName ?? 'image.jpg'}';
                final url = await SupabaseService.uploadImage(row.image!, fileName, 'reports');
                itemString += (itemString.isEmpty ? '' : ' ') + '{img: $url}';
              } catch (e) {
                debugPrint('Error uploading previous input image: $e');
              }
            }

            if (itemString.isNotEmpty) {
              categoryContent += (categoryContent.isEmpty ? '' : ', ') + itemString;
            }
          }
          if (categoryContent.isNotEmpty) historyStr += '$category: $categoryContent\n';
        }
        if (historyStr.isNotEmpty) combinedHistory += header + historyStr + '\n';

        // 3. Recommendations
        String recStr = '';
        final recs = cropData['recommendations'] as List<RecommendationRow>;
        for (var row in recs) {
          if (row.product.text.isNotEmpty) {
            recStr += '${row.product.text} (${row.application.text}) - '
                'Dose: ${row.dose.text} ${row.doseUnit ?? ""} per ${row.perUnit ?? ""}, '
                'Filler: ${row.filler.text} ${row.fillerQty.text}\n';
          }
        }
        if (recStr.isNotEmpty) combinedRecommendations += header + recStr + '\n';

        // 4. Costs
        String costStr = '';
        final costs = cropData['cost_estimations'] as List<CostEstimationRow>;
        for (var row in costs) {
          final double qty = double.tryParse(row.qty.text) ?? 0;
          final double mrp = double.tryParse(row.mrp.text) ?? 0;
          final double offer = double.tryParse(row.offerPrice.text) ?? mrp;
          final double total = qty * offer;
          grandTotal += total;

          costStr += '${row.productName} (Pkg: ${row.pkgSize.text}) - '
              'Qty: ${row.qty.text}, MRP: ${row.mrp.text}, Offer: ${row.offerPrice.text}, Total: $total\n';
        }
        if (costStr.isNotEmpty) combinedCost += header + costStr + '\n';
      }

      // Final format for problem string with image markers
      String finalProblemData = '';
      final isOfflineMode = await SupabaseService.isOffline();
      final Map<String, String> uploadedImageUrls = {};
      
      // Upload problem images
      for (var entry in allProblemImages.entries) {
        try {
          final url = await SupabaseService.uploadImage(entry.value!, allProblemImageNames[entry.key]!, 'reports');
          uploadedImageUrls[entry.key] = url;
        } catch (e) {
          debugPrint('Error uploading problem image: $e');
        }
      }

      final lines = combinedProblems.split('\n');
      for (var line in lines) {
        String processedLine = line;
        uploadedImageUrls.forEach((key, url) {
          if (processedLine.contains(key)) {
            processedLine = processedLine.replaceFirst(key, '${key.split('_').last} {img: $url}');
          }
        });
        finalProblemData += processedLine + '\n';
      }

      if (_nextVisitDate != null) {
        combinedCost += '\nNext Visit: ${_formatDate(_nextVisitDate)}\n';
      }
      combinedCost += 'Grand Total: ₹$grandTotal';

      // Collect images that failed to upload to save them locally
      Map<String, Uint8List> failedImages = {};
      if (allProblemImages.isNotEmpty) {
        allProblemImages.forEach((key, bytes) {
          if (bytes != null && !uploadedImageUrls.containsKey(key)) {
            failedImages[key] = bytes;
          }
        });
      }

      final reportData = {
        'farm_id': _selectedFarmId,
        'crop_id': _selectedCropId, // Use the last crop ID as the primary reference
        'problem': finalProblemData.trim(),
        'previous_inputs': combinedHistory.trim(),
        'recommendations': combinedRecommendations.trim(),
        'estimated_cost': combinedCost.trim(),
        'follow_up_date': _nextVisitDate?.toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        '_local_images': failedImages.isNotEmpty ? failedImages : null,
      };

      if (kIsWeb) {
        if (widget.existingReport != null) {
          await SupabaseService.updateReport(widget.existingReport!['id'].toString(), reportData);
        } else {
          await SupabaseService.addReport(reportData);
        }
      } else {
        await LocalDatabaseService.saveAndQueue(
          tableName: 'reports',
          data: reportData,
          operation: widget.existingReport != null ? 'UPDATE' : 'INSERT',
        );
        SyncManager().sync();
      }

      // Clear Draft after successful submission
      await _clearDraft();

      if (mounted) {
        final farm = _farms.firstWhere((f) => f['id'] == _selectedFarmId, orElse: () => {});
        final farmerNameForPdf = farm['farmers']?['name'] ?? 'Valued Farmer';

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ReportGeneratorScreen(
              report: reportData,
              farmName: farm['name'] ?? 'Unknown Farm',
              cropName: allCrops.length > 1 ? 'Multiple Crops' : allCrops.first['crop_name'],
              farmerName: farmerNameForPdf,
            ),
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

  @override
  Widget build(BuildContext context) {
    final pwSubtitle = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_costEstimations.isNotEmpty)
          Text(
            'Grand Total: ₹${_calculateGrandTotal()}',
            style: const TextStyle(color: AppColors.primary, fontSize: 12),
          ),
        if (_nextVisitDate != null)
          Text(
            'Next Visit: ${_formatDate(_nextVisitDate)}',
            style: const TextStyle(color: AppColors.primary, fontSize: 12),
          ),
      ],
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _onAttemptToLeave();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Visit Report'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _onAttemptToLeave,
          ),
        ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Stepper(
            type: StepperType.vertical,
            currentStep: _currentStep,
            onStepContinue: () {
              if (_currentStep == 1 && !_isProblemIdentificationFinished) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Please complete the problem identification sequence first.',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              _saveDraft(); // Safety snap-shot on each progression
              if (_currentStep < 5) {
                if (_currentStep == 3) _syncCostEstimations();
                setState(() => _currentStep += 1);
              } else {
                _handleSave();
              }
            },
            onStepCancel: () {
              _saveDraft(); // Safety snap-shot on backtrack
              if (_currentStep > 0) {
                setState(() => _currentStep -= 1);
              }
            },
            controlsBuilder: (context, details) {
              return Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Column(
                  children: [
                    if (_currentStep == 3) ...[
                      OutlinedButton.icon(
                        onPressed: () async {
                          if (_selectedCropId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please select a crop first')),
                            );
                            return;
                          }
                          
                          final data = await _collectCurrentCropData();
                          setState(() {
                            _multiCropsData.add(data);
                            _currentStep = 0; // Go back to Select Farm & Crop
                          });
                          _resetCropStepData();
                          
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Crop added! Now select the next crop to continue.'),
                                backgroundColor: AppColors.primary,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.add_circle_outline_rounded),
                        label: const Text('Add Another Crop to this Report'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 45),
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed:
                                (_currentStep == 1 &&
                                        !_isProblemIdentificationFinished)
                                    ? null
                                    : details.onStepContinue,
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
                                      _currentStep == 5
                                          ? 'Generate Report'
                                          : 'Next Step',
                                    ),
                          ),
                        ),
                        if (_currentStep > 0) ...[
                          const SizedBox(width: 12),
                          TextButton(
                            onPressed: details.onStepCancel,
                            child: const Text('Back'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            },
            steps: [
              Step(
                title: const Text('Select Farm & Crop'),
                subtitle:
                    _selectedFarmId != null
                        ? Text(
                          '${_farms.firstWhere((f) => f['id'] == _selectedFarmId, orElse: () => {'name': 'Selected'})['name']} • '
                          '${_selectedCropId != null ? _crops.firstWhere((c) => c['id'] == _selectedCropId, orElse: () => {'name': 'Selected'})['name'] : 'Select Crop'}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                          ),
                        )
                        : null,
                isActive: _currentStep >= 0,
                content: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: (_selectedFarmId != null && _farms.any((f) => f['id'].toString() == _selectedFarmId))
                          ? _selectedFarmId
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Choose Farm',
                      ),
                      items:
                          _farms
                              .map(
                                (f) => DropdownMenuItem(
                                  value: f['id'].toString(),
                                  child: Text(f['name'] ?? 'Unknown'),
                                ),
                              )
                              .toList(),
                      onChanged:
                          (widget.preSelectedFarmId != null || _multiCropsData.isNotEmpty)
                              ? null
                              : (v) {
                                setState(() => _selectedFarmId = v);
                                _loadCrops(v!);
                              },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      key: ValueKey('crop_dropdown_${_multiCropsData.length}_$_selectedCropId'),
                      value: (_selectedCropId != null && _crops.any((c) => c['id'].toString() == _selectedCropId))
                          ? _selectedCropId
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Choose Crop',
                      ),
                      items:
                          _crops
                              .where((c) => !_multiCropsData.any((m) => m['crop_id'] == c['id'].toString()))
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c['id'].toString(),
                                  child: Text(c['name'] ?? 'Unknown'),
                                ),
                              )
                              .toList(),
                      onChanged:
                          (widget.preSelectedCropId != null && _multiCropsData.isEmpty)
                              ? null
                              : (value) {
                                setState(() {
                                  _selectedCropId = value;
                                  _suggestedProblems = [];
                                });
                                if (value != null) {
                                  final cropIntId = int.tryParse(value);
                                  if (cropIntId != null) {
                                    _loadSuggestedProblems(cropIntId);
                                    _loadCropDetails(value);
                                  }
                                  if (_selectedFarmId != null) {
                                    _loadLastReportData(
                                      _selectedFarmId!,
                                      value,
                                    );
                                  }
                                }
                              },
                    ),
                  ],
                ),
              ),
              Step(
                title: const Text('Identify Problem'),
                subtitle:
                    _selectedProblems.isNotEmpty
                        ? Text(
                          _selectedProblems.join(', '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                          ),
                        )
                        : null,
                isActive: _currentStep >= 1,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_activeCategory == null) ...[
                      const Text(
                        'Select Problem Category',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      Column(
                        children: _problemCategoriesList.map((cat) {
                          final label = cat['label'].toString();
                          IconData icon = Icons.category_rounded;
                          Color color = AppColors.primary;
                          
                          if (label.contains('Pest')) {
                            icon = Icons.pest_control_rounded;
                            color = Colors.orange;
                          } else if (label.contains('Disease')) {
                            icon = Icons.coronavirus_rounded;
                            color = Colors.red;
                          } else if (label.contains('Deficiency')) {
                            icon = Icons.science_rounded;
                            color = Colors.blue;
                          } else if (label.contains('Other')) {
                            icon = Icons.more_horiz_rounded;
                            color = Colors.grey;
                          }
                          
                          final imageUrl = cat['image_url']?.toString();
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildHierarchyCard(label, icon, color, imageUrl: imageUrl),
                          );
                        }).toList(),
                      ),
                    ] else ...[
                      // SEQUENTIAL WIZARD VIEW
                      if (_activeSubcategory == null && !_isLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40.0),
                            child: Text('No sub-categories found for this category.'),
                          ),
                        )
                      else if (_activeSubcategory != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primary.withOpacity(0.1)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${_activeCategory!['label']} > ${_activeSubcategory!['label']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              Text(
                                'Cat: ${_categoryIndex + 1}/${_problemCategoriesList.length} | Sub: ${_subcategoryIndex + 1}/${_problemSubcategoriesList.length}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textGray.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          onChanged: (v) => setState(() => _problemSearchQuery = v),
                          decoration: InputDecoration(
                            hintText: 'Search items...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_isLoading)
                          const Center(child: Padding(
                            padding: EdgeInsets.all(40.0),
                            child: CircularProgressIndicator(),
                          ))
                        else
                          Container(
                            constraints: const BoxConstraints(maxHeight: 350),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
                            ),
                            child: _buildNewProblemItemList(),
                          ),
                        
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _goToPreviousSubcategory,
                                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                                label: const Text('Back / Skip'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 45),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _goToNextSubcategory,
                                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                                label: Text(_categoryIndex == _problemCategoriesList.length - 1 && _subcategoryIndex == _problemSubcategoriesList.length - 1 ? 'Finish Identification' : 'Next Section'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(0, 45),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],

                    if (_selectedProblems.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Selected Problems:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          TextButton(
                            onPressed:
                                () => setState(() => _selectedProblems.clear()),
                            child: const Text(
                              'Clear All',
                              style: TextStyle(color: Colors.red, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            _selectedProblems
                                .map((p) => _selectedProblemChip(p))
                                .toList(),
                      ),
                    ],

                    const SizedBox(height: 32),
                    const Text(
                      'Additional Notes',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _additionalNotesController,
                      maxLines: 2,
                      style: const TextStyle(fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Any other specific observations...',
                        contentPadding: EdgeInsets.all(16),
                      ),
                    ),
                  ],
                ),
              ),
              Step(
                title: const Text('Previous Inputs'),
                subtitle: const Text(
                  'List products used since last visit',
                  style: TextStyle(fontSize: 10, color: AppColors.primary),
                ),
                isActive: _currentStep >= 2,
                content: Column(
                  children: [
                    if (_lastReport != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: ElevatedButton.icon(
                          onPressed: _importLastReportData,
                          icon: const Icon(Icons.history_rounded),
                          label: const Text('Import from Last Visit'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            foregroundColor: AppColors.primary,
                            elevation: 0,
                            minimumSize: const Size(double.infinity, 45),
                          ),
                        ),
                      ),
                    ..._previousInputsMap.keys.map((category) => _buildPreviousInputCategory(category)),
                  ],
                ),
              ),
              Step(
                title: const Text('Recommendations'),
                subtitle:
                    _recommendationsList.any((r) => r.product.text.isNotEmpty)
                        ? Text(
                          '${_recommendationsList.where((r) => r.product.text.isNotEmpty).length} Products Recommended',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                          ),
                        )
                        : null,
                isActive: _currentStep >= 3,
                content: Column(
                  children: [
                    ..._recommendationsList.asMap().entries.map(
                      (entry) =>
                          _recommendationRowWidget(entry.key, entry.value),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _addRecommendationRow,
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      label: const Text('Add Product Recommendation'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Step(
                title: const Text('Estimated Cost'),
                subtitle:
                    _costEstimations.isNotEmpty || _nextVisitDate != null
                        ? pwSubtitle
                        : null,
                isActive: _currentStep >= 4,
                content: Column(
                  children: [
                    ..._costEstimations.map(
                      (row) => _costEstimationRowWidget(row),
                    ),
                    if (_costEstimations.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'Add products in Step 4 to see them here.',
                          style: TextStyle(
                            color: AppColors.textGray,
                            fontSize: 13,
                          ),
                        ),
                      )
                    else ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Grand Total: ₹${_calculateGrandTotal()}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const Divider(),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().add(
                              const Duration(days: 7),
                            ),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (date != null)
                            setState(() => _nextVisitDate = date);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: AppColors.secondary),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Next Visit Date',
                                    style: TextStyle(
                                      color: AppColors.textGray,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _nextVisitDate == null
                                        ? 'Set Follow-up Date'
                                        : _formatDate(_nextVisitDate),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color:
                                          _nextVisitDate == null
                                              ? AppColors.textGray
                                              : AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const Icon(
                                Icons.event_repeat_rounded,
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Step(
                title: const Text('Preview Report'),
                subtitle: const Text('Review and finalize report data', style: TextStyle(fontSize: 10)),
                isActive: _currentStep >= 5,
                content: _buildPreviewStep(),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildPreviewStep() {
    final farm = _farms.firstWhere((f) => f['id'] == _selectedFarmId, orElse: () => {'name': 'N/A'});
    final crop = _crops.firstWhere((c) => c['id'] == _selectedCropId, orElse: () => {'name': 'N/A'});

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _previewSectionHeader('Farm & Crop', Icons.landscape_rounded),
        _previewInfoItem('Farmer', farm['farmers']?['name'] ?? 'N/A'),
        _previewInfoItem('Farm', farm['name'] ?? 'N/A'),
        _previewInfoItem('Crop', crop['name'] ?? 'N/A'),
        const Divider(height: 32),

        _previewSectionHeader('Problem Identification', Icons.bug_report_rounded),
        if (_selectedProblems.isEmpty)
          const Text('No problems identified', style: TextStyle(color: Colors.grey, fontSize: 13))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedProblems.map((p) => Chip(
              label: Text(p, style: const TextStyle(fontSize: 11)),
              backgroundColor: AppColors.primary.withOpacity(0.1),
              side: BorderSide.none,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            )).toList(),
          ),
        if (_additionalNotesController.text.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('Notes:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          Text(_additionalNotesController.text, style: const TextStyle(fontSize: 12, color: AppColors.textGray)),
        ],
        const Divider(height: 32),

        _previewSectionHeader('Recommendations', Icons.recommend_rounded),
        if (!_recommendationsList.any((r) => r.product.text.isNotEmpty))
          const Text('No recommendations added', style: TextStyle(color: Colors.grey, fontSize: 13))
        else
          Column(
            children: _recommendationsList.where((r) => r.product.text.isNotEmpty).map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, size: 14, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${r.product.text} (${r.application.text})', style: const TextStyle(fontSize: 12))),
                ],
              ),
            )).toList(),
          ),
        const Divider(height: 32),

        _previewSectionHeader('Cost & Follow-up', Icons.payments_rounded),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Estimated Grand Total:', style: TextStyle(fontSize: 13)),
            Text('₹${_calculateGrandTotal()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Next Visit Date:', style: TextStyle(fontSize: 13)),
            Text(_nextVisitDate != null ? _formatDate(_nextVisitDate) : 'Not set', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
        if (_multiCropsData.isNotEmpty) ...[
          const Divider(height: 32),
          _previewSectionHeader('Multiple Crops', Icons.layers_rounded),
          Text('${_multiCropsData.length} other crops included in this visit.', style: const TextStyle(fontSize: 12, color: AppColors.primary)),
        ],
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.orange, size: 18),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Please review everything carefully. Once generated, the report will be saved to history.',
                  style: TextStyle(fontSize: 11, color: Colors.orange),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _previewSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(title.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5, color: AppColors.primary)),
        ],
      ),
    );
  }

  Widget _previewInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13, color: Colors.black87),
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textGray)),
            TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildHierarchyCard(String title, IconData icon, Color color, {String? imageUrl}) {
    return GestureDetector(
      onTap: () async {
        final catIndex = _problemCategoriesList.indexWhere(
          (c) => c['label'].toString().toLowerCase() == title.toLowerCase(),
        );
        
        if (catIndex != -1) {
          final cat = _problemCategoriesList[catIndex];
          setState(() {
            _activeCategory = cat;
            _categoryIndex = catIndex;
            _activeSubcategory = null; // Clear to prevent null access before loading
            _isLoading = true;
          });
          
          final subs = await SupabaseService.getDropdownOptions('problem_subcategory', parentId: cat['id']);
          setState(() {
            _problemSubcategoriesList = subs;
            if (_problemSubcategoriesList.isNotEmpty) {
              _subcategoryIndex = 0;
              _activeSubcategory = _problemSubcategoriesList[0];
            } else {
              _subcategoryIndex = -1;
              _activeSubcategory = null;
            }
            _isLoading = false;
          });
          
          if (_activeSubcategory != null) {
            await _fetchItems(_activeSubcategory!['id']);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Category "$title" not found in database. Please add it in Dropdown Creator.')),
          );
        }
      },
      child: Container(
        height: 100, // Increased height slightly to better show images
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          image: imageUrl != null
              ? DecorationImage(
                  image: NetworkImage(imageUrl),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.5),
                    BlendMode.darken,
                  ),
                )
              : null,
          border: Border.all(
            color: imageUrl != null ? Colors.transparent : color.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: (imageUrl != null ? Colors.black : color).withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 24),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: imageUrl != null ? Colors.white.withOpacity(0.2) : color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: imageUrl != null ? Colors.white : color, size: 28),
            ),
            const SizedBox(width: 20),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: imageUrl != null ? Colors.white : color,
                fontSize: 18,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: (imageUrl != null ? Colors.white : color).withOpacity(0.5),
              size: 18,
            ),
            const SizedBox(width: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSubcategoryCard(Map<String, dynamic> sub) {
    return GestureDetector(
      onTap: () {
        setState(() => _activeSubcategory = sub);
        _fetchItems(sub['id']);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: sub['image_url'] != null
                    ? Image.network(sub['image_url'], width: double.infinity, fit: BoxFit.cover)
                    : Container(
                        color: AppColors.secondary.withOpacity(0.3),
                        child: const Icon(Icons.image_not_supported_outlined, color: AppColors.primary),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                sub['label'],
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewProblemItemList() {
    final filtered = _problemItemsList
        .where((item) => item['label'].toString().toLowerCase().contains(_problemSearchQuery.toLowerCase()))
        .toList();

    if (filtered.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(24.0), child: Text('No items found')));
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final item = filtered[index];
        final label = item['label'].toString();
        bool isChecked = _selectedProblems.contains(label);

        return GestureDetector(
          onTap: () {
            setState(() {
              if (!isChecked) {
                _selectedProblems.add(label);
                _pickImage(label, ImageSource.camera);
              } else {
                _selectedProblems.remove(label);
                _problemImages.remove(label);
                _problemImageNames.remove(label);
              }
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: isChecked ? AppColors.primary.withOpacity(0.05) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isChecked ? AppColors.primary : Colors.grey[200]!,
                width: 2,
              ),
            ),
            child: Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                        child: item['image_url'] != null
                            ? Image.network(item['image_url'], width: double.infinity, fit: BoxFit.cover)
                            : Container(
                                color: AppColors.secondary.withOpacity(0.3),
                                child: const Center(
                                  child: Icon(Icons.bug_report_outlined, size: 24, color: AppColors.primary),
                                ),
                              ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isChecked ? FontWeight.bold : FontWeight.normal,
                          color: isChecked ? AppColors.primary : Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (isChecked)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      child: const Icon(Icons.check, size: 12, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _selectedProblemChip(String item) {
    final hasImage = _problemImages[item] != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => _pickImage(item, ImageSource.camera),
            icon: Icon(
              Icons.camera_alt_rounded,
              size: 16,
              color: hasImage ? Colors.green : AppColors.primary,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          Text(
            item,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap:
                () => setState(() {
                  _selectedProblems.remove(item);
                  _problemImages.remove(item);
                }),
            child: const Icon(
              Icons.close_rounded,
              size: 16,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(String problem, ImageSource source) async {
    final XFile? image = await _picker.pickImage(
      source: source,
      imageQuality: 50,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _problemImages[problem] = bytes;
        _problemImageNames[problem] = image.name;
      });
    }
  }

  Widget _costEstimationRowWidget(CostEstimationRow row) {
    // Find the product and its variants
    final product = _productOptions.firstWhere(
      (p) => p['label'] == row.productName,
      orElse: () => {},
    );
    final List variants = product['variants'] ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.secondary),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            row.productName,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  value:
                      variants.any((v) => v['label'].toString() == row.pkgSize.text)
                          ? row.pkgSize.text
                          : null,
                  decoration: const InputDecoration(
                    labelText: 'Pkg Size',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items:
                      variants.map((v) {
                        return DropdownMenuItem<String>(
                          value: v['label'].toString(),
                          child: Text(
                            v['label'].toString(),
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                      }).toList(),
                  onChanged: (val) {
                    final variant = variants.firstWhere(
                      (v) => v['label'] == val,
                      orElse: () => {},
                    );
                    if (variant.isNotEmpty) {
                      setState(() {
                        row.pkgSize.text = val ?? '';
                        if (variant['mrp'] != null)
                          row.mrp.text = variant['mrp'].toString();
                        if (variant['offer_price'] != null)
                          row.offerPrice.text =
                              variant['offer_price'].toString();
                        _autoCalculateQuantities();
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _miniField(row.qty, 'Qty #', isNumber: true),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _miniField(row.mrp, 'MRP', isNumber: true)),
              const SizedBox(width: 8),
              Expanded(
                child: _miniField(
                  row.offerPrice,
                  'Offer Price',
                  isNumber: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          StatefulBuilder(
            builder: (context, setInternalState) {
              row.qty.addListener(() => setInternalState(() {}));
              row.mrp.addListener(() => setInternalState(() {}));
              row.offerPrice.addListener(() => setInternalState(() {}));

              final double q = double.tryParse(row.qty.text) ?? 0;
              final double p = double.tryParse(row.mrp.text) ?? 0;
              final double offer = double.tryParse(row.offerPrice.text) ?? p;
              return Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Total: ₹${q * offer}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  double _calculateGrandTotal() {
    double total = 0;
    for (var row in _costEstimations) {
      final double q = double.tryParse(row.qty.text) ?? 0;
      final double p = double.tryParse(row.mrp.text) ?? 0;
      final double offer = double.tryParse(row.offerPrice.text) ?? p;
      total += (q * offer);
    }
    return total;
  }

  Widget _miniField(
    TextEditingController controller,
    String label, {
    bool isNumber = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 10, color: AppColors.primary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        isDense: true,
        filled: true,
        fillColor: AppColors.secondary.withOpacity(0.05),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.secondary.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _recommendationRowWidget(int index, RecommendationRow row) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.secondary),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: DropdownButtonFormField<String>(
                    value:
                        _productOptions.any(
                              (p) => p['label'].toString() == row.product.text,
                            )
                            ? row.product.text
                            : null,
                    decoration: const InputDecoration(
                      labelText: 'Product Name',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    items:
                        _productOptions.map((p) {
                          return DropdownMenuItem<String>(
                            value: p['label'].toString(),
                            child: Text(
                              p['label'].toString(),
                              style: const TextStyle(fontSize: 14),
                            ),
                          );
                        }).toList(),
                    onChanged: (val) {
                      setState(() {
                        row.product.text = val ?? '';
                      });
                      _syncCostEstimations();
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (_recommendationsList.length > 1)
                IconButton(
                  onPressed: () => _removeRecommendationRow(index),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
                    size: 20,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value:
                      _applicationOptions.any(
                            (a) => a['label'].toString() == row.application.text,
                          )
                          ? row.application.text
                          : null,
                  decoration: const InputDecoration(
                    labelText: 'Application',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  items:
                      _applicationOptions.map((a) {
                        return DropdownMenuItem<String>(
                          value: a['label'].toString(),
                          child: Text(
                            a['label'].toString(),
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }).toList(),
                  onChanged: (val) {
                    setState(() {
                      row.application.text = val ?? '';
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Per unit in its own row to prevent horizontal overflow
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value:
                      _perUnitOptions.any(
                        (u) => u['label'].toString() == row.perUnit,
                      )
                          ? row.perUnit
                          : null,
                  decoration: const InputDecoration(
                    labelText: 'Per Unit (e.g. Acre, Litre, Plant)',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  items:
                      _perUnitOptions.map((u) {
                        return DropdownMenuItem<String>(
                          value: u['label'].toString(),
                          child: Text(
                            u['label'].toString(),
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                      }).toList(),
                  onChanged: (val) {
                    setState(() => row.perUnit = val);
                    _syncCostEstimations();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Dose and Unit in one row
          Row(
            children: [
              Expanded(
                flex: 1,
                child: TextField(
                  controller: row.dose,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Dose',
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.secondary.withOpacity(0.05),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: AppColors.secondary.withOpacity(0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                  onChanged: (_) => _syncCostEstimations(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<String>(
                  value:
                      _doseUnitOptions.any(
                        (u) => u['label'].toString() == row.doseUnit,
                      )
                          ? row.doseUnit
                          : null,
                  decoration: const InputDecoration(
                    labelText: 'Unit',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  items:
                      _doseUnitOptions.map((u) {
                        return DropdownMenuItem<String>(
                          value: u['label'].toString(),
                          child: Text(
                            u['label'].toString(),
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                      }).toList(),
                  onChanged: (val) {
                    setState(() => row.doseUnit = val);
                    _syncCostEstimations();
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    // Filler Material Dropdown
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        value:
                            _fillerMaterialOptions.any(
                                  (m) => m['label'].toString() == row.filler.text,
                                )
                                ? row.filler.text
                                : null,
                        decoration: const InputDecoration(
                          labelText: 'Filler (Material)',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        items:
                            _fillerMaterialOptions.map((m) {
                              return DropdownMenuItem<String>(
                                value: m['label'].toString(),
                                child: Text(
                                  m['label'].toString(),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              );
                            }).toList(),
                        onChanged:
                            (val) =>
                                setState(() => row.filler.text = val ?? ''),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Filler Qty
                    Expanded(
                      flex: 2,
                      child: _miniField(row.fillerQty, 'Qty', isNumber: true),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreviousInputCategory(String category) {
    final rows = _previousInputsMap[category] ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              category,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppColors.textBlack,
              ),
            ),
            IconButton(
              onPressed: () {
                setState(() {
                  _previousInputsMap[category]!.add(PreviousInputRow());
                });
              },
              icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
              color: AppColors.primary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...rows.asMap().entries.map((entry) {
          final index = entry.key;
          final row = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: row.controller,
                        decoration: InputDecoration(
                          hintText: 'Product Name...',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (row.image != null)
                                const Icon(Icons.check_circle, color: Colors.green, size: 16),
                              IconButton(
                                icon: Icon(
                                  row.image == null ? Icons.camera_alt_rounded : Icons.image_rounded,
                                  size: 20,
                                  color: row.image == null ? AppColors.textGray : AppColors.primary,
                                ),
                                onPressed: () => _pickPreviousInputImage(category, index),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (rows.length > 1)
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _previousInputsMap[category]!.removeAt(index);
                          });
                        },
                        icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.red, size: 18),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: row.date ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => row.date = date);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: row.date == null ? Colors.transparent : AppColors.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: row.date == null ? AppColors.secondary.withOpacity(0.5) : AppColors.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 12,
                          color: row.date == null ? AppColors.textGray : AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          row.date == null ? 'Select Input Date' : _formatDate(row.date),
                          style: TextStyle(
                            fontSize: 11,
                            color: row.date == null ? AppColors.textGray : AppColors.primary,
                            fontWeight: row.date == null ? FontWeight.normal : FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        const Divider(height: 24),
      ],
    );
  }

  Future<void> _pickPreviousInputImage(String category, int index) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _previousInputsMap[category]![index].image = bytes;
        _previousInputsMap[category]![index].imageName = image.name;
      });
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class PreviousInputRow {
  final controller = TextEditingController();
  Uint8List? image;
  String? imageName;
  DateTime? date;
}

class RecommendationRow {
  final product = TextEditingController();
  final application = TextEditingController();
  final dose = TextEditingController();
  String? doseUnit;
  String? perUnit;
  final fillerQty = TextEditingController();
  final filler = TextEditingController();
  String? fillerUnit;
}

class CostEstimationRow {
  final String productName;
  final pkgSize = TextEditingController();
  final qty = TextEditingController();
  final mrp = TextEditingController();
  final offerPrice = TextEditingController();

  CostEstimationRow({required this.productName});
}
