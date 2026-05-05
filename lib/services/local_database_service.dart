import 'dart:convert';
import 'dart:typed_data';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:uuid/uuid.dart';

class LocalDatabaseService {
  static Database? _database;
  static Future<Database?>? _initFuture;
  static const String _databaseName = "nature_biotic_local.db";
  static const int _databaseVersion = 12;

  static Future<Database?> get database async {
    if (kIsWeb) return null;
    if (_database != null) return _database!;
    
    // Prevent multiple simultaneous initializations
    _initFuture ??= _initDatabase();
    _database = await _initFuture;
    return _database;
  }

  static Future<Database?> _initDatabase() async {
    if (kIsWeb) return null;
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('DB: Upgrading from $oldVersion to $newVersion');
    if (oldVersion < 2) {
      // Migration from 1 to 2
      try {
        await db.execute('ALTER TABLE attendance ADD COLUMN check_in_photo BLOB');
        await db.execute('ALTER TABLE attendance ADD COLUMN check_out_photo BLOB');
        await db.execute('ALTER TABLE attendance ADD COLUMN check_in_location_lat REAL');
        await db.execute('ALTER TABLE attendance ADD COLUMN check_in_location_lng REAL');
        await db.execute('ALTER TABLE attendance ADD COLUMN check_out_location_lat REAL');
        await db.execute('ALTER TABLE attendance ADD COLUMN check_out_location_lng REAL');
        
        await db.execute('ALTER TABLE reports ADD COLUMN photo BLOB');
        await db.execute('ALTER TABLE reports ADD COLUMN location_lat REAL');
        await db.execute('ALTER TABLE reports ADD COLUMN location_lng REAL');
      } catch (e) {
        debugPrint('DB Upgrade Error (v2): $e');
      }
    }

    if (oldVersion < 3) {
      // Migration to version 3
      try {
        // Update crops table
        final List<String> cropColumns = ['age', 'life', 'count', 'acre', 'expected_yield'];
        for (var col in cropColumns) {
          try {
            await db.execute('ALTER TABLE crops ADD COLUMN $col TEXT');
          } catch (_) { /* Column might already exist if migration partially failed */ }
        }

        // Update farms table
        final List<String> farmColumns = [
          'place', 'area', 'soil_type', 'irrigation_type', 
          'water_source', 'water_quantity', 'power_source', 'report_url'
        ];
        for (var col in farmColumns) {
          try {
            if (col == 'area') {
               await db.execute('ALTER TABLE farms ADD COLUMN $col REAL');
            } else {
               await db.execute('ALTER TABLE farms ADD COLUMN $col TEXT');
            }
          } catch (_) { /* Column might already exist */ }
        }
      } catch (e) {
        debugPrint('DB Upgrade Error (v3): $e');
      }
    }

    if (oldVersion < 4) {
      // Migration to version 4: Add contacts to farms
      try {
        await db.execute('ALTER TABLE farms ADD COLUMN contacts TEXT');
      } catch (e) {
        debugPrint('DB Upgrade Error (v4): $e');
      }
    }

    if (oldVersion < 5) {
      // Migration to version 5: Add stock_transactions
      try {
        await db.execute('''
          CREATE TABLE stock_transactions (
            id TEXT PRIMARY KEY,
            farm_id TEXT,
            item_name TEXT,
            transaction_type TEXT,
            quantity REAL,
            unit TEXT,
            executive_id TEXT,
            created_at TEXT
          )
        ''');
      } catch (e) {
        debugPrint('DB Upgrade Error (v5): $e');
      }
    }

    if (oldVersion < 6) {
      // Migration to version 6: Add collected_amount to stock_transactions
      try {
        await db.execute('ALTER TABLE stock_transactions ADD COLUMN collected_amount REAL');
      } catch (e) {
        debugPrint('DB Upgrade Error (v6): $e');
      }
    }
    if (oldVersion < 7) {
      // Migration to version 7: Add follow_up_date to reports
      try {
        await db.execute('ALTER TABLE reports ADD COLUMN follow_up_date TEXT');
      } catch (e) {
        debugPrint('DB Upgrade Error (v7): $e');
      }
    }
    if (oldVersion < 8) {
      // Migration to version 8: Add store_transactions
      try {
        await db.execute('''
          CREATE TABLE store_transactions (
            id TEXT PRIMARY KEY,
            item_name TEXT,
            transaction_type TEXT, -- 'PURCHASE', 'DELIVERY', 'RETURN'
            quantity REAL,
            unit TEXT,
            executive_id TEXT, -- For Delivery/Return
            vendor_name TEXT, -- For Purchase
            status TEXT, -- 'PENDING', 'ACCEPTED', 'REJECTED'
            accepted_at TEXT,
            created_by TEXT,
            created_at TEXT
          )
        ''');
      } catch (e) {
        debugPrint('DB Upgrade Error (v8): $e');
      }
    }
    if (oldVersion < 9) {
      // Migration to version 9: Add is_verified to core tables
      try {
        final tables = ['farmers', 'farms', 'crops', 'reports'];
        for (var table in tables) {
          try {
            await db.execute('ALTER TABLE $table ADD COLUMN is_verified INTEGER DEFAULT 0');
            await db.execute('ALTER TABLE $table ADD COLUMN verified_by TEXT');
            await db.execute('ALTER TABLE $table ADD COLUMN verified_at TEXT');
          } catch (_) { /* Progressively add columns */ }
        }
      } catch (e) {
        debugPrint('DB Upgrade Error (v9): $e');
      }
    }
    if (oldVersion < 10) {
      // Migration to version 10: Add landmark and intercrop to farms, and updated_at to store_transactions
      try {
        await db.execute('ALTER TABLE farms ADD COLUMN landmark TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE farms ADD COLUMN intercrop TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE store_transactions ADD COLUMN updated_at TEXT');
      } catch (_) {}
    }

    if (oldVersion < 11) {
      // Version 11: Safety check for updated_at column
      try {
        await db.execute('ALTER TABLE store_transactions ADD COLUMN updated_at TEXT');
      } catch (_) {}
    }

    if (oldVersion < 12) {
      // Version 12: Add farm_collections table
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS farm_collections (
            id TEXT PRIMARY KEY,
            farm_id TEXT NOT NULL,
            farmer_name TEXT,
            amount REAL NOT NULL,
            notes TEXT,
            created_by TEXT,
            created_at TEXT,
            sync_status TEXT DEFAULT 'pending'
          )
        ''');
      } catch (e) {
        debugPrint('DB Upgrade Error (v12): $e');
      }
    }
  }

  static Future<void> _onCreate(Database db, int version) async {
    // Farmers table
    await db.execute('''
      CREATE TABLE farmers (
        id TEXT PRIMARY KEY,
        name TEXT,
        mobile TEXT,
        village TEXT,
        address TEXT,
        category TEXT,
        created_by TEXT,
        created_at TEXT,
        is_verified INTEGER DEFAULT 0,
        verified_by TEXT,
        verified_at TEXT
      )
    ''');

    // Farms table
    await db.execute('''
      CREATE TABLE farms (
        id TEXT PRIMARY KEY,
        farmer_id TEXT,
        name TEXT,
        place TEXT,
        area REAL,
        soil_type TEXT,
        irrigation_type TEXT,
        water_source TEXT,
        water_quantity TEXT,
        power_source TEXT,
        landmark TEXT,
        intercrop TEXT,
        report_url TEXT,
        assigned_to TEXT,
        contacts TEXT,
        created_by TEXT,
        created_at TEXT,
        is_verified INTEGER DEFAULT 0,
        verified_by TEXT,
        verified_at TEXT
      )
    ''');

    // Crops table
    await db.execute('''
      CREATE TABLE crops (
        id TEXT PRIMARY KEY,
        farm_id TEXT,
        name TEXT,
        variety TEXT,
        age TEXT,
        life TEXT,
        count TEXT,
        acre TEXT,
        expected_yield TEXT,
        created_at TEXT,
        is_verified INTEGER DEFAULT 0,
        verified_by TEXT,
        verified_at TEXT
      )
    ''');

    // Reports table
    await db.execute('''
      CREATE TABLE reports (
        id TEXT PRIMARY KEY,
        farm_id TEXT,
        crop_id TEXT,
        problem TEXT,
        previous_inputs TEXT,
        recommendations TEXT,
        estimated_cost TEXT,
        signature_url TEXT,
        follow_up_date TEXT,
        created_by TEXT,
        created_at TEXT,
        is_verified INTEGER DEFAULT 0,
        verified_by TEXT,
        verified_at TEXT,
        _local_signature BLOB,
        _local_images TEXT
      )
    ''');

    // Attendance table
    await db.execute('''
      CREATE TABLE attendance (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        check_in_time TEXT,
        check_out_time TEXT,
        check_in_location TEXT,
        check_out_location TEXT,
        check_in_photo TEXT,
        check_out_photo TEXT,
        check_in_location_lat REAL,
        check_in_location_lng REAL,
        check_out_location_lat REAL,
        check_out_location_lng REAL,
        status TEXT,
        created_at TEXT,
        _local_photo BLOB
      )
    ''');

    // Call Logs table
    await db.execute('''
      CREATE TABLE call_logs (
        id TEXT PRIMARY KEY,
        farmer_id TEXT,
        executive_id TEXT,
        phone_number TEXT,
        start_time TEXT,
        duration_seconds INTEGER,
        summary TEXT,
        created_at TEXT
      )
    ''');

    // Sync Queue table
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT,
        record_id TEXT,
        operation TEXT, -- 'INSERT', 'UPDATE', 'DELETE'
        payload TEXT, -- JSON string
        status TEXT, -- 'PENDING', 'SYNCED', 'FAILED'
        error TEXT,
        created_at TEXT
      )
    ''');

    // Stock Transactions table
    await db.execute('''
      CREATE TABLE stock_transactions (
        id TEXT PRIMARY KEY,
        farm_id TEXT,
        item_name TEXT,
        transaction_type TEXT,
        quantity REAL,
        unit TEXT,
        executive_id TEXT,
        collected_amount REAL,
        created_at TEXT
      )
    ''');

    // Store Transactions table
    await db.execute('''
      CREATE TABLE store_transactions (
        id TEXT PRIMARY KEY,
        item_name TEXT,
        transaction_type TEXT,
        quantity REAL,
        unit TEXT,
        executive_id TEXT,
        vendor_name TEXT,
        status TEXT,
        accepted_at TEXT,
        created_by TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // Farm Collections table
    await db.execute('''
      CREATE TABLE farm_collections (
        id TEXT PRIMARY KEY,
        farm_id TEXT NOT NULL,
        farmer_name TEXT,
        amount REAL NOT NULL,
        notes TEXT,
        created_by TEXT,
        created_at TEXT,
        sync_status TEXT DEFAULT 'pending'
      )
    ''');
  }

  // Generic Save and Queue method
  static Future<void> saveAndQueue({
    required String tableName,
    required Map<String, dynamic> data,
    required String operation,
  }) async {
    final db = await database;
    if (db == null) return;
    
    final id = data['id'] ?? const Uuid().v4();
    
    // 1. Save locally
    final localData = {...data, 'id': id};
    
    // Convert Map fields to JSON string for local storage (SQLite doesn't support Maps)
    if (tableName == 'reports' && localData['_local_images'] != null) {
      if (localData['_local_images'] is Map) {
        localData['_local_images'] = jsonEncode(localData['_local_images'], toEncodable: (o) => o is Uint8List ? o.toList() : o);
      }
    }

    // Encode contacts list for farms
    if (tableName == 'farms' && localData['contacts'] != null) {
      if (localData['contacts'] is List || localData['contacts'] is Map) {
        localData['contacts'] = jsonEncode(localData['contacts']);
      }
    }

    if (operation == 'INSERT') {
      await db.insert(tableName, localData, conflictAlgorithm: ConflictAlgorithm.replace);
    } else if (operation == 'UPDATE') {
      await db.update(tableName, localData, where: 'id = ?', whereArgs: [id]);
    }

    // 2. Add to sync queue
    await db.insert('sync_queue', {
      'table_name': tableName,
      'record_id': id,
      'operation': operation,
      'payload': jsonEncode(localData, toEncodable: (o) => o is Uint8List ? o.toList() : o),
      'status': 'PENDING',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // Delete and Queue method
  static Future<void> deleteAndQueue({
    required String tableName,
    required String id,
  }) async {
    final db = await database;
    if (db == null) return;

    // 1. Delete locally
    await db.delete(tableName, where: 'id = ?', whereArgs: [id]);

    // 2. Add to sync queue
    await db.insert('sync_queue', {
      'table_name': tableName,
      'record_id': id,
      'operation': 'DELETE',
      'payload': jsonEncode({'id': id}), // Payload just contains the ID
      'status': 'PENDING',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // Get local data
  static Future<List<Map<String, dynamic>>> getData(
    String tableName, {
    String? where, 
    List<dynamic>? whereArgs, 
    List<String>? columns,
  }) async {
    final db = await database;
    if (db == null) return [];
    List<String>? selectedColumns = columns;
    
    // Safety Blanket: Automatically exclude massive binary columns for specific tables if not explicitly requested
    if (selectedColumns == null) {
      if (tableName == 'reports') {
        selectedColumns = ['id', 'farm_id', 'crop_id', 'problem', 'previous_inputs', 'recommendations', 'estimated_cost', 'signature_url', 'created_by', 'created_at', 'is_verified'];
      } else if (tableName == 'attendance') {
        selectedColumns = ['id', 'user_id', 'check_in_time', 'check_out_time', 'check_in_location', 'check_out_location', 'check_in_location_lat', 'check_in_location_lng', 'check_out_location_lat', 'check_out_location_lng', 'status', 'created_at'];
      }
    }

    return await db.query(
      tableName, 
      where: where, 
      whereArgs: whereArgs, 
      columns: selectedColumns,
      orderBy: 'created_at DESC'
    );
  }

  static Future<Map<String, dynamic>?> getDataById(String tableName, String id) async {
    final db = await database;
    if (db == null) return null;
    final results = await db.query(tableName, where: 'id = ?', whereArgs: [id]);
    if (results.isEmpty) return null;
    return results.first;
  }

  static Future<Map<String, dynamic>?> getTodayAttendance() async {
    final db = await database;
    if (db == null) return null;
    
    final startOfDay = DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);
    
    final results = await db.query(
      'attendance',
      where: 'created_at >= ?',
      whereArgs: [startOfDay.toIso8601String()],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    
    if (results.isEmpty) return null;
    return results.first;
  }

  static Future<List<Map<String, dynamic>>> getAllAttendanceLogs() async {
    final db = await database;
    if (db == null) return [];
    
    return await db.query(
      'attendance',
      columns: ['id', 'user_id', 'check_in_time', 'check_out_time', 'check_in_location', 'check_out_location', 'check_in_location_lat', 'check_in_location_lng', 'check_out_location_lat', 'check_out_location_lng', 'status', 'created_at'],
      orderBy: 'check_in_time DESC',
    );
  }

  // Sync Queue methods
  static Future<List<Map<String, dynamic>>> getPendingSyncItems() async {
    final db = await database;
    if (db == null) return [];
    // WARNING: This can fail with "Row too big" if a payload is very large (>2MB).
    // Use getPendingSyncIds and getSyncItem for better robustness.
    return await db.query('sync_queue', where: 'status = ?', whereArgs: ['PENDING'], orderBy: 'id ASC');
  }

  static Future<List<int>> getPendingSyncIds() async {
    final db = await database;
    if (db == null) return [];
    final results = await db.query(
      'sync_queue', 
      columns: ['id'], 
      where: 'status = ? OR status = ?', 
      whereArgs: ['PENDING', 'FAILED'], 
      orderBy: 'id ASC'
    );
    return results.map((r) => r['id'] as int).toList();
  }

  static Future<Map<String, dynamic>?> getSyncItem(int id) async {
    final db = await database;
    if (db == null) return null;
    final results = await db.query('sync_queue', where: 'id = ?', whereArgs: [id]);
    if (results.isEmpty) return null;
    return results.first;
  }

  static Future<void> updateSyncStatus(int queueId, String status, {String? error}) async {
    final db = await database;
    if (db == null) return;
    await db.update('sync_queue', {
      'status': status,
      'error': error,
    }, where: 'id = ?', whereArgs: [queueId]);
  }
}
