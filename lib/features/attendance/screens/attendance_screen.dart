import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:nature_biotic/services/local_database_service.dart';
import 'package:nature_biotic/services/sync_manager.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:nature_biotic/features/expenses/widgets/trip_widgets.dart';
import 'package:uuid/uuid.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _todayAttendance;
  Position? _currentPosition;
  String _currentAddress = 'Fetching location...';
  File? _image;
  final _picker = ImagePicker();
  bool _isSubmitting = false;
  Map<String, dynamic>? _activeTrip;
  bool _isExecutive = false;
  bool _isTelecaller = false;
  bool _isManager = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final profile = await SupabaseService.getProfile();
      _isExecutive = profile?['role'] == 'executive';
      _isTelecaller = profile?['role'] == 'telecaller';
      _isManager = profile?['role'] == 'manager';

      // 1. Try fetching from remote
      _todayAttendance = await SupabaseService.getTodayAttendance();

      if (_isExecutive || _isTelecaller || _isManager) {
        final userId = SupabaseService.client.auth.currentUser?.id;
        if (userId != null) {
          _activeTrip = await SupabaseService.getActiveExpenseForExecutive(userId);
        }
      }

      // 2. If remote is null (sync pending), check local
      if (_todayAttendance == null && !kIsWeb) {
        _todayAttendance = await LocalDatabaseService.getTodayAttendance();
      }

      await _getCurrentLocation();
    } catch (e) {
      // Fallback to local on error (e.g. offline)
      if (!kIsWeb) {
        _todayAttendance = await LocalDatabaseService.getTodayAttendance();
      }

      if (mounted && _todayAttendance == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _currentAddress = 'Location services are disabled.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _currentAddress = 'Location permissions are denied');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(
        () => _currentAddress = 'Location permissions are permanently denied',
      );
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _currentPosition = position;
          _currentAddress =
              '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
        });
      }

      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (mounted && placemarks.isNotEmpty) {
          setState(() {
            Placemark place = placemarks[0];
            final address =
                '${place.name ?? ''} ${place.street ?? ''}, ${place.locality ?? ''}, ${place.postalCode ?? ''}'
                    .trim();
            if (address.isNotEmpty) {
              _currentAddress = address;
            }
          });
        }
      } catch (e) {
        debugPrint('Geocoding error: $e');
        // Keep the coordinates already set above
      }
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              _currentAddress =
                  'Location Error: ${e.toString().split('\n')[0]}',
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 50,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (pickedFile != null) {
        setState(() => _image = File(pickedFile.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _captureAndUpload(String bucketId) async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 50,
    );
    if (photo != null) {
      final bytes = await photo.readAsBytes();
      final extension = photo.path.split('.').last;
      final fileName = '${const Uuid().v4()}.$extension';

      try {
        return await SupabaseService.uploadImage(bytes, fileName, bucketId);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Upload failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
    return null;
  }

  void _showStartTripDialog() async {
    if (_activeTrip == null) {
      await SupabaseService.startExecutiveTrip();
      await _loadData();
    }

    if (!mounted || _activeTrip == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StartTripForm(
          expenseId: _activeTrip!['id'],
          onStarted: () {
            Navigator.pop(context);
            _loadData();
          },
          onCapture: () => _captureAndUpload('expense-documents'),
        ),
      ),
    );
  }

  void _showEndTripDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => EndTripDialogContent(
        expenseId: _activeTrip!['id'],
        startOdometer: double.tryParse(_activeTrip!['start_odometer_reading']?.toString() ?? '0') ?? 0.0,
        onEnded: _loadData,
        onCapture: () => _captureAndUpload('expense-documents'),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please take a photo first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wait for location...'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final isCheckIn = _todayAttendance == null;

      if (isCheckIn) {
        // Mandatory offline data sync during check-in
        try {
          await SupabaseService.syncAllDropdownOptions();
        } catch (e) {
          debugPrint('Sync failed during check-in: $e');
        }
      }

      final fileName =
          '${SupabaseService.client.auth.currentUser!.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final imageUrl = await SupabaseService.uploadImage(
        await _image!.readAsBytes(),
        fileName,
        'attendance',
      );

      final attendanceData = {
        if (isCheckIn)
          'check_in_time': DateTime.now().toIso8601String()
        else
          'check_out_time': DateTime.now().toIso8601String(),

        if (isCheckIn)
          'check_in_photo': imageUrl
        else
          'check_out_photo': imageUrl,

        if (isCheckIn)
          'check_in_location_lat': _currentPosition!.latitude
        else
          'check_out_location_lat': _currentPosition!.latitude,

        if (isCheckIn)
          'check_in_location_lng': _currentPosition!.longitude
        else
          'check_out_location_lng': _currentPosition!.longitude,

        'created_at': DateTime.now().toIso8601String(),
        // Only keep local bytes if upload failed
        '_local_photo': null,
      };

      if (!isCheckIn) attendanceData['id'] = _todayAttendance!['id'];

      if (kIsWeb) {
        if (isCheckIn) {
          await SupabaseService.checkIn({
            'check_in_time': DateTime.now().toIso8601String(),
            'check_in_photo': imageUrl,
            'check_in_location_lat': _currentPosition!.latitude,
            'check_in_location_lng': _currentPosition!.longitude,
          });
        } else {
          await SupabaseService.checkOut(_todayAttendance!['id'], {
            'check_out_time': DateTime.now().toIso8601String(),
            'check_out_photo': imageUrl,
            'check_out_location_lat': _currentPosition!.latitude,
            'check_out_location_lng': _currentPosition!.longitude,
          });
        }
      } else {
        await LocalDatabaseService.saveAndQueue(
          tableName: 'attendance',
          data: attendanceData,
          operation: isCheckIn ? 'INSERT' : 'UPDATE',
        );
        SyncManager().sync();
      }

      if (isCheckIn) {
        // After Check-In: Trigger trip start for field staff and managers
        if (_isExecutive || _isTelecaller || _isManager) {
          _showStartTripDialog();
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isCheckIn
                  ? 'Checked In Successfully'
                  : 'Checked Out Successfully',
            ),
            backgroundColor: AppColors.primary,
          ),
        );
        _loadData(); // Refresh UI
        setState(() => _image = null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCheckedIn =
        _todayAttendance != null && _todayAttendance!['check_out_time'] == null;
    final isCompleted =
        _todayAttendance != null && _todayAttendance!['check_out_time'] != null;

    // Trip Status Logic for Field Staff and Managers
    bool needsOdometer = false;
    bool tripInProgress = false;
    if (isCheckedIn && (_isExecutive || _isTelecaller || _isManager)) {
      needsOdometer = _activeTrip != null && _activeTrip!['start_odometer_reading'] == null;
      tripInProgress = _activeTrip != null && 
                       _activeTrip!['start_odometer_reading'] != null && 
                       _activeTrip!['end_odometer_reading'] == null;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Attendance')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Info Card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            children: [
                              _infoRow(
                                Icons.calendar_today_rounded,
                                'Date',
                                DateFormat(
                                  'EEEE, MMM d',
                                ).format(DateTime.now()),
                              ),
                              const Divider(height: 32),
                              _infoRow(
                                Icons.location_on_rounded,
                                'Location',
                                _currentAddress,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Photo Area
                        GestureDetector(
                          onTap: (isCompleted || needsOdometer || tripInProgress) ? null : _takePhoto,
                          child: Container(
                            width: double.infinity,
                            height: 250,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: AppColors.secondary,
                                width: 2,
                              ),
                            ),
                            child:
                                _image != null
                                    ? ClipRRect(
                                      borderRadius: BorderRadius.circular(22),
                                      child: Image.file(
                                        _image!,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                    : isCompleted
                                    ? const Center(
                                      child: Text('Shift Completed for Today'),
                                    )
                                    : (needsOdometer || tripInProgress)
                                    ? Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.speed_rounded,
                                            size: 64,
                                            color: AppColors.primary.withOpacity(0.5),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            needsOdometer ? 'Start Trip to Proceed' : 'Trip In Progress',
                                            style: const TextStyle(color: AppColors.textGray),
                                          ),
                                        ],
                                      ),
                                    )
                                    : Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.camera_alt_rounded,
                                          size: 64,
                                          color: AppColors.primary.withOpacity(
                                            0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        const Text(
                                          'Tap to take photo',
                                          style: TextStyle(
                                            color: AppColors.textGray,
                                          ),
                                        ),
                                      ],
                                    ),
                          ),
                        ),

                        const SizedBox(height: 40),

                        if (isCompleted)
                          const Text(
                            'You have already logged your attendance for today.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        else
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isSubmitting 
                                ? null 
                                : needsOdometer 
                                  ? _showStartTripDialog 
                                  : tripInProgress 
                                    ? _showEndTripDialog 
                                    : _handleSubmit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    needsOdometer 
                                        ? Colors.blue
                                        : tripInProgress
                                          ? Colors.redAccent
                                          : isCheckedIn
                                            ? Colors.orange
                                            : AppColors.primary,
                              ),
                              child:
                                  _isSubmitting
                                      ? Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              isCheckedIn ? 'Checking Out...' : 'Syncing & Checking In...',
                                              style: const TextStyle(color: Colors.white),
                                            ),
                                          ],
                                        )
                                      : Text(
                                        needsOdometer 
                                          ? 'Start Trip' 
                                          : tripInProgress 
                                            ? 'End Trip' 
                                            : isCheckedIn 
                                              ? 'Check Out' 
                                              : 'Check In',
                                      ),
                            ),
                          ),

                        const SizedBox(height: 24),

                        // Today Stats
                        if (_todayAttendance != null)
                          Container(
                            width: double.infinity,
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
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Activity Today',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _activityItem(
                                  'Check In',
                                  DateFormat('hh:mm a').format(
                                    DateTime.parse(
                                      _todayAttendance!['check_in_time'],
                                    ),
                                  ),
                                  true,
                                ),
                                if (_todayAttendance!['check_out_time'] != null)
                                  _activityItem(
                                    'Check Out',
                                    DateFormat('hh:mm a').format(
                                      DateTime.parse(
                                        _todayAttendance!['check_out_time'],
                                      ),
                                    ),
                                    false,
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: AppColors.textGray, fontSize: 12),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _activityItem(String label, String time, bool isGreen) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isGreen ? Colors.green : Colors.orange,
            ),
          ),
          const SizedBox(width: 16),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(
            time,
            style: const TextStyle(
              color: AppColors.textGray,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
