import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:nature_biotic/services/local_database_service.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:flutter/foundation.dart';

class SyncManager {
  static final SyncManager _instance = SyncManager._internal();
  factory SyncManager() => _instance;
  SyncManager._internal();

  bool _isSyncing = false;
  bool _syncRequestedAgain = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// Reactive connectivity state — listen to show/hide the offline banner
  final ValueNotifier<bool> isOnline = ValueNotifier(true);

  /// Reactive pending sync count — shows how many items are queued
  final ValueNotifier<int> pendingCount = ValueNotifier(0);

  /// Timestamp of last successful sync pass (null if never synced this session)
  final ValueNotifier<DateTime?> lastSyncedAt = ValueNotifier(null);

  void initialize() {
    if (kIsWeb) return;

    // Set initial connectivity state immediately
    Connectivity().checkConnectivity().then((results) {
      isOnline.value = results.any((r) => r != ConnectivityResult.none);
    });

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      final nowOnline = results.any((r) => r != ConnectivityResult.none);
      isOnline.value = nowOnline;
      if (nowOnline) sync();
    });

    // Initial sync attempt + populate pending count
    sync();
    _updatePendingCount();
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }

  Future<void> sync() async {
    if (_isSyncing) {
      _syncRequestedAgain = true;
      debugPrint('SYNC: Sync already in progress, queuing another pass...');
      return;
    }

    // Check if online once at start
    final results = await Connectivity().checkConnectivity();
    if (results.every((r) => r == ConnectivityResult.none)) return;

    do {
      _isSyncing = true;
      _syncRequestedAgain = false;
      debugPrint('SYNC: Starting synchronization pass...');

      await _performSync();
    } while (_syncRequestedAgain);

    _isSyncing = false;
    await _updatePendingCount();
    debugPrint('SYNC: All synchronization passes finished.');
  }

  Future<void> _updatePendingCount() async {
    if (kIsWeb) return;
    final ids = await LocalDatabaseService.getPendingSyncIds();
    pendingCount.value = ids.length;
    // Mark the last time we completed a sync check
    if (ids.isEmpty) lastSyncedAt.value = DateTime.now();
  }

  Future<void> _performSync() async {
    try {
      final db = await LocalDatabaseService.database;
      final allQueue = await db?.query(
        'sync_queue',
        columns: ['id', 'status', 'table_name', 'operation'],
      );
      debugPrint('SYNC DUMP: All queue items: $allQueue');

      final pendingIds = await LocalDatabaseService.getPendingSyncIds();
      if (pendingIds.isEmpty) {
        debugPrint('SYNC: No pending items found.');
        return;
      }

      debugPrint('SYNC: Found ${pendingIds.length} pending items.');

      for (var queueId in pendingIds) {
        Map<String, dynamic>? item;
        try {
          item = await LocalDatabaseService.getSyncItem(queueId);
        } catch (e) {
          debugPrint('SYNC: FATAL ROW ERROR for ID $queueId: $e');
          await LocalDatabaseService.updateSyncStatus(
            queueId,
            'FAILED',
            error: 'Row too big or corrupted: $e',
          );
          continue;
        }
        if (item == null) {
          debugPrint('SYNC WARNING: Sync item $queueId is null, skipping');
          continue;
        }

        final String tableName = item['table_name'];
        final String operation = item['operation'];
        final String recordId = item['record_id'].toString();
        final Map<String, dynamic> payload = jsonDecode(item['payload']);

        try {
          debugPrint('SYNC: Executing $operation for $tableName:$recordId');
          await _processSyncItem(tableName, operation, payload);
          await LocalDatabaseService.updateSyncStatus(queueId, 'SYNCED');

          // CRITICAL: If this was an INSERT, delete the temporary local record from the source table
          // so that the next fetch gets the authoritative synced version from Supabase.
          if (operation == 'INSERT') {
            await LocalDatabaseService.deleteData(tableName, recordId);
            debugPrint(
              'SYNC: Deleted local temporary record $tableName:$recordId',
            );
          }

          debugPrint('SYNC SUCCESS: $tableName:$recordId');
        } catch (e) {
          debugPrint('SYNC FAILURE: $tableName:$recordId: $e');
          await LocalDatabaseService.updateSyncStatus(
            queueId,
            'FAILED',
            error: e.toString(),
          );
        }
      }
    } catch (e, stack) {
      debugPrint('SYNC: FATAL ERROR during sync loop: $e');
      debugPrint('SYNC: Stack trace: $stack');
    } finally {
      debugPrint('SYNC: Pass finished.');
    }
  }

  Future<void> _processSyncItem(
    String tableName,
    String operation,
    Map<String, dynamic> payload,
  ) async {
    // 1. Handle File Uploads first if any
    final cleanPayload = Map<String, dynamic>.from(payload);

    // Handle Attendance Photos
    if (cleanPayload.containsKey('_local_photo') &&
        cleanPayload['_local_photo'] != null) {
      final List<int> bytes = List<int>.from(cleanPayload['_local_photo']);
      final fileName = 'att_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final url = await SupabaseService.uploadImage(
        Uint8List.fromList(bytes),
        fileName,
        'attendance',
      );

      if (operation == 'INSERT') {
        cleanPayload['check_in_photo'] = url;
      } else {
        cleanPayload['check_out_photo'] = url;
      }

      cleanPayload.remove('_local_photo');
    } else {
      cleanPayload.remove('_local_photo');
    }

    // Handle Report Signature and Images
    if (tableName == 'reports') {
      if (cleanPayload.containsKey('_local_signature') &&
          cleanPayload['_local_signature'] != null) {
        final List<int> bytes = List<int>.from(
          cleanPayload['_local_signature'],
        );
        final fileName = 'sig_${DateTime.now().millisecondsSinceEpoch}.png';
        final url = await SupabaseService.uploadImage(
          Uint8List.fromList(bytes),
          fileName,
          'reports',
        );
        cleanPayload['signature_url'] = url;
        cleanPayload.remove('_local_signature');
      } else {
        cleanPayload.remove('_local_signature');
      }

      if (cleanPayload.containsKey('_local_images') &&
          cleanPayload['_local_images'] != null) {
        Map<String, dynamic> localImages;
        try {
          if (cleanPayload['_local_images'] is String) {
            localImages = Map<String, dynamic>.from(
              jsonDecode(cleanPayload['_local_images']),
            );
          } else {
            localImages = Map<String, dynamic>.from(
              cleanPayload['_local_images'],
            );
          }
        } catch (e) {
          debugPrint('SYNC: Error decoding _local_images: $e');
          localImages = {};
        }

        Map<String, String> uploadedUrls = {};
        String problemStr = cleanPayload['problem'] ?? '';

        for (var entry in localImages.entries) {
          if (entry.value != null) {
            final List<int> bytes = List<int>.from(entry.value);
            final fileName =
                'img_${DateTime.now().millisecondsSinceEpoch}_${entry.key.hashCode}.jpg';

            // Individual image retry logic
            String? url;
            int retries = 0;
            while (url == null && retries < 3) {
              try {
                debugPrint(
                  'SYNC: Uploading image ${entry.key} (Attempt ${retries + 1})...',
                );
                url = await SupabaseService.uploadImage(
                  Uint8List.fromList(bytes),
                  fileName,
                  'reports',
                ).timeout(const Duration(seconds: 60));
              } catch (e) {
                retries++;
                debugPrint('SYNC: Image upload failed (${entry.key}): $e');
                if (retries >= 3) break;
                await Future.delayed(Duration(seconds: 2 * retries));
              }
            }

            if (url != null) {
              uploadedUrls[entry.key] = url;
              // Replace in string immediately to be safe
              final displayKey =
                  entry.key.contains('_')
                      ? entry.key.split('_').last
                      : entry.key;
              problemStr = problemStr.replaceAll(
                entry.key,
                '$displayKey {img: $url}',
              );
            }
          }
        }

        cleanPayload['problem'] = problemStr;
        cleanPayload.remove('_local_images');
      } else {
        cleanPayload.remove('_local_images');
      }
    }
    if (tableName == 'farms' &&
        cleanPayload.containsKey('contacts') &&
        cleanPayload['contacts'] is String) {
      try {
        cleanPayload['contacts'] = jsonDecode(cleanPayload['contacts']);
      } catch (_) {}
    }

    // 2. Map to SupabaseService methods
    if (operation == 'DELETE') {
      await SupabaseService.deleteRecord(tableName, cleanPayload['id']);
      return;
    }

    switch (tableName) {
      case 'farmers':
        if (operation == 'INSERT') {
          await SupabaseService.addFarmer(cleanPayload);
        } else if (operation == 'UPDATE')
          await SupabaseService.updateFarmer(cleanPayload['id'], cleanPayload);
        break;
      case 'farms':
        if (operation == 'INSERT') {
          await SupabaseService.addFarm(cleanPayload);
        } else if (operation == 'UPDATE')
          await SupabaseService.updateFarm(cleanPayload['id'], cleanPayload);
        break;
      case 'crops':
        if (operation == 'INSERT') await SupabaseService.addCrop(cleanPayload);
        if (operation == 'UPDATE') {
          await SupabaseService.updateCrop(
            cleanPayload['id'].toString(),
            cleanPayload,
          );
        }
        break;
      case 'reports':
        if (operation == 'INSERT') {
          await SupabaseService.addReport(cleanPayload);
        }
        break;
      case 'attendance':
        if (cleanPayload['check_out_time'] != null &&
            cleanPayload['id'] != null) {
          await SupabaseService.checkOut(cleanPayload['id'], cleanPayload);
        } else {
          await SupabaseService.checkIn(cleanPayload);
        }
        break;
      case 'call_logs':
        if (operation == 'INSERT') {
          await SupabaseService.addCallLog(cleanPayload);
        }
        break;
      case 'stock_transactions':
        if (operation == 'INSERT') {
          await SupabaseService.addStockTransaction(cleanPayload);
        }
        break;
      case 'store_transactions':
        if (operation == 'INSERT') {
          await SupabaseService.addStoreTransaction(cleanPayload);
        } else if (operation == 'UPDATE') {
          await SupabaseService.updateStoreTransaction(
            cleanPayload['id'].toString(),
            cleanPayload,
          );
        }
        break;
      case 'farm_collections':
        if (operation == 'INSERT') {
          await SupabaseService.addFarmCollection(cleanPayload);
        } else if (operation == 'UPDATE') {
          // Generic fallback: push the entire payload to Supabase
          await SupabaseService.client
              .from('farm_collections')
              .update(cleanPayload)
              .eq('id', cleanPayload['id'].toString());
        }
        break;
    }
  }
}
