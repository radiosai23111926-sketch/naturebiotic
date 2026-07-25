import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;

void main() async {
  sqfliteFfiInit();
  var databaseFactory = databaseFactoryFfi;
  
  final dbPath = 'C:\\Users\\ASUS\\OneDrive\\Documents\\nature_biotic_local.db';
  print("Opening DB at: $dbPath");
  if (!File(dbPath).existsSync()) {
    print("Database file does not exist at OneDrive Documents.");
    return;
  }
  
  var db = await databaseFactory.openDatabase(dbPath);
  try {
    var syncRows = await db.rawQuery("SELECT * FROM sync_queue WHERE status = 'PENDING';");
    print("\nPending Sync Queue (${syncRows.length} found):");
    for (var r in syncRows) {
      print(r);
    }
    
    var allLocalTxs = await db.rawQuery("SELECT * FROM store_transactions;");
    print("\nLocal Store Transactions (${allLocalTxs.length} found):");
    for (var r in allLocalTxs) {
      print(r);
    }
  } catch (e) {
    print("Error querying database: $e");
  }
  await db.close();
}
