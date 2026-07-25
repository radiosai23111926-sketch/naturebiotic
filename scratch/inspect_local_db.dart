import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  sqfliteFfiInit();
  var databaseFactory = databaseFactoryFfi;
  
  final dbPath = 'C:\\Users\\ASUS\\OneDrive\\Documents\\nature_biotic_local.db';
  print("Opening DB at: $dbPath");
  if (!File(dbPath).existsSync()) {
    print("Database file does not exist.");
    return;
  }
  
  var db = await databaseFactory.openDatabase(dbPath);
  try {
    var tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table';");
    print("\nTables in SQLite Database:");
    for (var t in tables) {
      final tableName = t['name'] as String;
      if (tableName.startsWith('sqlite_') || tableName == 'android_metadata') continue;
      
      try {
        var countResult = await db.rawQuery("SELECT COUNT(*) as count FROM $tableName;");
        final count = countResult.first['count'];
        print("- $tableName: $count rows");
      } catch (e) {
        print("- $tableName: Error counting rows: $e");
      }
    }
  } catch (e) {
    print("Error: $e");
  }
  await db.close();
  exit(0);
}
