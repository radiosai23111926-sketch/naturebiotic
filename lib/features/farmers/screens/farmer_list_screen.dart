import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:nature_biotic/features/farmers/screens/add_farmer_screen.dart';
import 'package:nature_biotic/features/farmers/screens/farmer_detail_screen.dart';
import 'package:nature_biotic/services/local_database_service.dart';
import 'package:nature_biotic/core/widgets/animations.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';

class FarmerListScreen extends StatefulWidget {
  const FarmerListScreen({super.key});

  @override
  State<FarmerListScreen> createState() => _FarmerListScreenState();
}

class _FarmerListScreenState extends State<FarmerListScreen> {
  List<Map<String, dynamic>> _farmers = [];
  List<Map<String, dynamic>> _teamMembers = [];
  String? _userRole;
  bool _isLoading = true;
  String? _selectedStaffId;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([_loadFarmers(), _loadTeamMembers()]);
  }

  Future<void> _loadTeamMembers() async {
    try {
      final team = await SupabaseService.getAllStaff();
      if (mounted) {
        setState(() {
          _teamMembers = team;
        });
      }
    } catch (e) {
      debugPrint('Error loading team: $e');
    }
  }

  Future<void> _loadFarmers() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final profile = await SupabaseService.getProfile();
      _userRole = profile?['role'];

      final remoteData = await SupabaseService.getFarmers();
      List<Map<String, dynamic>> localData = [];

      if (!kIsWeb) {
        localData = await LocalDatabaseService.getData('farmers');
      }

      if (mounted) {
        setState(() {
          // Merge and De-duplicate: Local truth wins over remote
          final Map<String, Map<String, dynamic>> combinedMap = {};

          for (var farmer in remoteData) {
            combinedMap[farmer['id'].toString()] = farmer;
          }
          for (var farmer in localData) {
            combinedMap[farmer['id'].toString()] = farmer;
          }

          _farmers = combinedMap.values.toList();
          _farmers.sort(
            (a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''),
          );

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getCategoryColor(String? category) {
    if (category == null) return AppColors.textGray;
    switch (category) {
      case 'Hot':
        return AppColors.hot;
      case 'Warm':
        return AppColors.warm;
      case 'Cold':
        return AppColors.cold;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                bottom: false,
                child: CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      expandedHeight: 120,
                      floating: true,
                      pinned: true,
                      backgroundColor: AppColors.background.withOpacity(0.8),
                      flexibleSpace: FlexibleSpaceBar(
                        background: ClipRRect(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(color: Colors.transparent),
                          ),
                        ),
                      ),
                      title: Text(
                        'Farmers',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w800,
                          fontSize: 24,
                          color: AppColors.textBlack,
                        ),
                      ),
                      actions: [
                        Container(
                          margin: const EdgeInsets.only(right: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: IconButton(
                            onPressed: _loadFarmers,
                            icon: const Icon(
                              Icons.refresh_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                        child: Column(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: TextField(
                                controller: _searchController,
                                onChanged: (v) => setState(() {}),
                                decoration: InputDecoration(
                                  hintText: 'Search by name, village...',
                                  prefixIcon: const Icon(
                                    Icons.search_rounded,
                                    color: AppColors.primary,
                                  ),
                                  suffixIcon:
                                      _searchController.text.isNotEmpty
                                          ? IconButton(
                                            icon: const Icon(
                                              Icons.clear_rounded,
                                            ),
                                            onPressed: () {
                                              _searchController.clear();
                                              setState(() {});
                                            },
                                          )
                                          : null,
                                ),
                              ),
                            ),
                            if (_userRole == 'admin' || _userRole == 'manager') ...[
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: AppColors.primary.withOpacity(
                                            0.2,
                                          ),
                                        ),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _selectedStaffId,
                                          hint: const Text(
                                            'Filter by Staff Member',
                                          ),
                                          isExpanded: true,
                                          icon: const Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            color: AppColors.primary,
                                          ),
                                          items: [
                                            const DropdownMenuItem<String>(
                                              value: null,
                                              child: Text('All Staff Members'),
                                            ),
                                            ..._teamMembers.map((staff) {
                                              return DropdownMenuItem<String>(
                                                value: staff['id'],
                                                child: Text(
                                                  staff['full_name'] ?? 'Staff',
                                                ),
                                              );
                                            }),
                                          ],
                                          onChanged:
                                              (v) => setState(
                                                () => _selectedStaffId = v,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  TextButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _selectedStaffId = null;
                                        _searchController.clear();
                                      });
                                    },
                                    icon: const Icon(
                                      Icons.backspace_outlined,
                                      size: 16,
                                    ),
                                    label: const Text('Clear'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.textGray,
                                      textStyle: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Builder(
                      builder: (context) {
                        final width = MediaQuery.sizeOf(context).width;
                        final bool isWide = width > 1100;
                        final int crossAxisCount = width > 1600 ? 5 : 4;

                        final query = _searchController.text.toLowerCase();
                        final filtered =
                            _farmers.where((f) {
                              final name =
                                  (f['name'] ?? '').toString().toLowerCase();
                              final village =
                                  (f['village'] ?? '').toString().toLowerCase();
                              final mobile =
                                  (f['mobile'] ?? '').toString().toLowerCase();

                              final matchesQuery =
                                  name.contains(query) ||
                                  village.contains(query) ||
                                  mobile.contains(query);
                              final matchesStaff =
                                  _selectedStaffId == null ||
                                  f['created_by'] == _selectedStaffId;

                              return matchesQuery && matchesStaff;
                            }).toList();

                        if (filtered.isEmpty) {
                          return SliverFillRemaining(
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.person_search_rounded,
                                    size: 64,
                                    color: AppColors.textGray.withOpacity(0.2),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No farmers found',
                                    style: GoogleFonts.outfit(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textGray,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        if (isWide) {
                          return SliverPadding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 8,
                            ),
                            sliver: SliverGrid(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    crossAxisSpacing: 20,
                                    mainAxisSpacing: 20,
                                    childAspectRatio: 0.9,
                                  ),
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                final farmer = filtered[index];
                                return EntranceAnimation(
                                  delay: 50 + (index * 30),
                                  child: FarmerCard(
                                    id: farmer['id'].toString(),
                                    name: farmer['name'] ?? 'N/A',
                                    village: farmer['village'] ?? 'N/A',
                                    category: farmer['category'] ?? 'Warm',
                                    categoryColor: _getCategoryColor(
                                      farmer['category'],
                                    ),
                                    photoUrl: farmer['photo_url'],
                                    localPhotoBytes: farmer['_local_photo'],
                                    isVerified: farmer['is_verified'] == true,
                                    isGrid: true,
                                    isAdmin: _userRole == 'admin',
                                    onEdit: () => _handleEditFarmer(farmer),
                                    onDelete: () => _handleDeleteFarmer(farmer),
                                    onTap: () async {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) => FarmerDetailScreen(
                                                farmer: farmer,
                                              ),
                                        ),
                                      );
                                      if (result == true) {
                                        _loadFarmers();
                                      }
                                    },
                                  ),
                                );
                              }, childCount: filtered.length),
                            ),
                          );
                        }

                        return SliverPadding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 8,
                          ),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final farmer = filtered[index];
                              return EntranceAnimation(
                                delay: 50 + (index * 50),
                                child: FarmerCard(
                                  id: farmer['id'].toString(),
                                  name: farmer['name'] ?? 'N/A',
                                  village: farmer['village'] ?? 'N/A',
                                  category: farmer['category'] ?? 'Warm',
                                  categoryColor: _getCategoryColor(
                                    farmer['category'],
                                  ),
                                  photoUrl: farmer['photo_url'],
                                  localPhotoBytes: farmer['_local_photo'],
                                  isVerified: farmer['is_verified'] == true,
                                  isAdmin: _userRole == 'admin',
                                  onEdit: () => _handleEditFarmer(farmer),
                                  onDelete: () => _handleDeleteFarmer(farmer),
                                  onTap: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => FarmerDetailScreen(
                                              farmer: farmer,
                                            ),
                                      ),
                                    );
                                    if (result == true) {
                                      _loadFarmers();
                                    }
                                  },
                                ),
                              );
                            }, childCount: filtered.length),
                          ),
                        );
                      },
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              ),
      floatingActionButton:
          _userRole == 'manager'
              ? null
              : EntranceAnimation(
                delay: 500,
                child: ScaleButton(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddFarmerScreen(),
                      ),
                    );
                    _loadFarmers();
                  },
                  child: Container(
                    height: 64,
                    width: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),

    );
  }

  Future<void> _handleEditFarmer(Map<String, dynamic> farmer) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddFarmerScreen(farmer: farmer),
      ),
    );
    if (result != null) {
      _loadFarmers();
    }
  }

  Future<void> _handleDeleteFarmer(Map<String, dynamic> farmer) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Farmer'),
        content: Text('Are you sure you want to delete "${farmer['name']}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await SupabaseService.deleteFarmer(farmer['id'].toString());
        _loadFarmers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Farmer deleted successfully'), backgroundColor: AppColors.primary),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting farmer: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}

class FilterChipWidget extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const FilterChipWidget({
    super.key,
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : color.withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                  : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : color,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class FarmerCard extends StatelessWidget {
  final String id;
  final String name;
  final String village;
  final String category;
  final Color categoryColor;
  final bool isVerified;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool isGrid;
  final bool isAdmin;
  final String? photoUrl;
  final dynamic localPhotoBytes;

  const FarmerCard({
    super.key,
    required this.id,
    required this.name,
    required this.village,
    required this.category,
    required this.categoryColor,
    this.isVerified = true,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.isGrid = false,
    this.isAdmin = false,
    this.photoUrl,
    this.localPhotoBytes,
  });

  String _getInitials(String name) {
    if (name.isEmpty) return 'F';
    final parts = name.trim().split(' ');
    if (parts.length > 1) {
      return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
    } else if (parts[0].length > 1) {
      return parts[0].substring(0, 2).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    // Map categories to modern organic-themed dark premium gradients
    final List<Color> gradientColors;
    if (category == 'Hot') {
      gradientColors = [const Color(0xFFC62828), const Color(0xFF880E4F)]; // Crimson/Burgundy
    } else if (category == 'Warm') {
      gradientColors = [const Color(0xFFE65100), const Color(0xFFBF360C)]; // Deep Flame Amber/Rust
    } else if (category == 'Cold') {
      gradientColors = [const Color(0xFF1565C0), const Color(0xFF0D47A1)]; // Classic Navy/Indigo
    } else {
      // Default / Owner / Emerald Green
      gradientColors = [const Color(0xFF2E7D32), const Color(0xFF1B5E20)]; // Deep Forest/Vibrant Green
    }

    return Container(
      margin: isGrid ? EdgeInsets.zero : const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors.last.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // Watermark leaf icon at bottom right corner
            Positioned(
              right: isGrid ? -35 : -20,
              bottom: isGrid ? -35 : -40,
              child: Transform.rotate(
                angle: -0.25,
                child: Opacity(
                  opacity: 0.08,
                  child: const Icon(
                    Icons.eco_rounded,
                    size: 160,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            // Watermark small leaf icon at top left corner
            Positioned(
              left: -20,
              top: -20,
              child: Transform.rotate(
                angle: 0.6,
                child: Opacity(
                  opacity: 0.04,
                  child: const Icon(
                    Icons.eco_rounded,
                    size: 90,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(28),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                  child: isGrid ? _buildGridLayout() : _buildListLayout(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListLayout() {
    return Row(
      children: [
        _buildAvatar(),
        const SizedBox(width: 20),
        Expanded(child: _buildDetails(isGrid: false)),
        if (isAdmin) _buildAdminMenu() else _buildChevron(),
      ],
    );
  }

  Widget _buildAdminMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
      onSelected: (value) {
        if (value == 'edit') onEdit?.call();
        if (value == 'delete') onDelete?.call();
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_rounded, size: 20, color: Colors.blue),
              SizedBox(width: 12),
              Text('Edit'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
              SizedBox(width: 12),
              Text('Delete', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGridLayout() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildAvatar(),
        const SizedBox(height: 16),
        _buildDetails(isGrid: true),
      ],
    );
  }

  Widget _buildAvatar() {
    ImageProvider? imageProvider;
    if (localPhotoBytes != null) {
      if (localPhotoBytes is Uint8List) {
        imageProvider = MemoryImage(localPhotoBytes as Uint8List);
      } else if (localPhotoBytes is List) {
        imageProvider = MemoryImage(Uint8List.fromList(List<int>.from(localPhotoBytes as List)));
      }
    } else if (photoUrl != null && photoUrl!.isNotEmpty) {
      imageProvider = NetworkImage(photoUrl!);
    }

    return Hero(
      tag: 'farmer_icon_$id',
      child: Container(
        height: 68,
        width: 68,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          image: imageProvider != null
              ? DecorationImage(
                  image: imageProvider,
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: imageProvider == null
            ? Center(
                child: Text(
                  _getInitials(name),
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildDetails({required bool isGrid}) {
    return Column(
      crossAxisAlignment:
          isGrid ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
          maxLines: 1,
          textAlign: isGrid ? TextAlign.center : TextAlign.start,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment:
              isGrid ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Icon(
              Icons.location_on_rounded,
              size: 14,
              color: Colors.white.withOpacity(0.7),
            ),
            const SizedBox(width: 4),
            Text(
              village,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.white.withOpacity(0.85),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                category.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChevron() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(
        Icons.chevron_right_rounded,
        size: 20,
        color: Colors.white,
      ),
    );
  }
}
