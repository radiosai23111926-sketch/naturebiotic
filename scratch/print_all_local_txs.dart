import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  sqfliteFfiInit();
  var databaseFactory = databaseFactoryFfi;
  final dbPath = 'C:\\Users\\ASUS\\OneDrive\\Documents\\nature_biotic_local.db';
  
  var db = await databaseFactory.openDatabase(dbPath);
  
  var result = await db.rawQuery("SELECT * FROM store_transactions LIMIT 20;");
  print("Rows in store_transactions: $result");
  
  await db.close();
  exit(0);
}
