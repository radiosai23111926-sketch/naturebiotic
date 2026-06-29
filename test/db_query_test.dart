import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Query local db', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final docDir = await getApplicationDocumentsDirectory();
    print('Documents Directory: ${docDir.path}');
    final dbPath = join(docDir.path, 'nature_biotic.db');
    print('DB Path: $dbPath');

    if (!File(dbPath).existsSync()) {
      print('DB file does not exist at path!');
      return;
    }

    final db = await openDatabase(dbPath);
    
    // 1. Query Farms
    final farms = await db.query('farms');
    print('--- FARMS (${farms.length}) ---');
    for (var f in farms) {
      print('Farm ID: ${f['id']}, Name: ${f['name']}, Place: ${f['place']}');
    }

    // Find sri's farm ID
    final sriFarm = farms.firstWhere(
      (f) => f['name'].toString().toLowerCase().contains('sri'),
      orElse: () => null as Map<String, Object?>, // type bypass
    );
    if (sriFarm == null) {
      print('Sri farm not found locally.');
      await db.close();
      return;
    }
    final sriFarmId = sriFarm['id'];
    print('Sri Farm ID: $sriFarmId');

    // 2. Query Bills
    final bills = await db.query('bills', where: 'farm_id = ?', whereArgs: [sriFarmId]);
    print('--- BILLS FOR SRI (${bills.length}) ---');
    for (var b in bills) {
      print('Bill ID: ${b['id']}, Challan No: ${b['challan_no']}, Grand Total: ${b['grand_total']}, Status: ${b['status']}, discount: ${b['total_discount']}');
    }

    // 3. Query Collections
    final collections = await db.query('farm_collections', where: 'farm_id = ?', whereArgs: [sriFarmId]);
    print('--- COLLECTIONS FOR SRI (${collections.length}) ---');
    for (var c in collections) {
      print('Collection ID: ${c['id']}, Amount: ${c['amount']}, Created At: ${c['created_at']}');
    }

    // 4. Query Transactions
    final txs = await db.query('stock_transactions', where: 'farm_id = ?', whereArgs: [sriFarmId]);
    print('--- TRANSACTIONS FOR SRI (${txs.length}) ---');
    for (var tx in txs) {
      print('Tx ID: ${tx['id']}, Item: ${tx['item_name']}, Type: ${tx['transaction_type']}, Qty: ${tx['quantity']}, Unit: ${tx['unit']}, Collected: ${tx['collected_amount']}');
    }

    await db.close();
  });
}
