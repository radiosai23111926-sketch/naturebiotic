import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  sqfliteFfiInit();
  var databaseFactory = databaseFactoryFfi;
  final dbPath = 'C:\\Users\\ASUS\\OneDrive\\Documents\\nature_biotic_local.db';
  
  var db = await databaseFactory.openDatabase(dbPath);
  
  var result = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table';");
  print("Tables in db: $result");
  
  await db.close();
  exit(0);
}
