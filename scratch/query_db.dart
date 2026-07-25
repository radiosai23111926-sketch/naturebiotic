import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;

void main() async {
  // Initialize sqflite ffi
  sqfliteFfiInit();
  var databaseFactory = databaseFactoryFfi;
  
  final docDir = 'C:\\Users\\ASUS\\Documents';
  final dbPath = p.join(docDir, 'nature_biotic_local.db');
  
  print("Opening DB at: $dbPath");
  if (!File(dbPath).existsSync()) {
    print("Database file does not exist.");
    return;
  }
  
  var db = await databaseFactory.openDatabase(dbPath);
  
  try {
    var rows = await db.rawQuery("SELECT * FROM store_transactions ORDER BY created_at DESC LIMIT 40;");
    print("\nStore Transactions (Last 40):");
    for (var r in rows) {
      print("${r['id']} | type: ${r['transaction_type']} | item: ${r['item_name']} | qty: ${r['quantity']} | unit: ${r['unit']} | status: ${r['status']} | date: ${r['created_at']}");
    }
  } catch (e) {
    print("Error querying store_transactions: $e");
  }
  
  await db.close();
}
