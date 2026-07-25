import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  sqfliteFfiInit();
  var databaseFactory = databaseFactoryFfi;
  
  final dbPath = 'd:\\Personal\\naturebiotic\\nature_biotic_local.db';
  print("Opening DB at: $dbPath");
  if (!File(dbPath).existsSync()) {
    print("Database file does not exist at project root.");
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
    print("Error: $e");
  }
  await db.close();
}
