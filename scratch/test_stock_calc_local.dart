import 'dart:convert';
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
    // Query cached_data for key 'store_transactions'
    var rows = await db.query(
      'cached_data',
      where: 'cache_key = ?',
      whereArgs: ['store_transactions'],
    );
    
    if (rows.isEmpty) {
      print("No cached store_transactions found.");
      return;
    }
    
    final String payload = rows.first['payload'] as String;
    final List<dynamic> rawList = jsonDecode(payload);
    final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(rawList);
    
    // Filter Chakkra transactions
    final chakkraTxs = data.where((tx) => (tx['item_name']?.toString() ?? '').trim().toLowerCase() == 'chakkra').toList();
    
    // Sort descending by date
    chakkraTxs.sort((a, b) {
      final dateA = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateB = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      return dateB.compareTo(dateA);
    });

    print("All Chakkra Transactions in local cache (${chakkraTxs.length} found):");
    for (var tx in chakkraTxs) {
      print("ID: ${tx['id']} | Type: ${tx['transaction_type']} | Qty: ${tx['quantity']} | Unit: ${tx['unit']} | Status: ${tx['status']} | Date: ${tx['created_at']}");
    }

    print("\n--- Dry Run of _stockBeforeTransaction ---");
    for (var tx in chakkraTxs) {
      final txDate = DateTime.tryParse(tx['created_at']?.toString() ?? '');
      if (txDate == null) continue;

      final itemName = (tx['item_name']?.toString() ?? '').trim().toLowerCase();
      final rawUnit = tx['unit']?.toString() ?? 'Units';
      final unit = rawUnit.split(' {₹')[0].trim().toLowerCase();

      double stock = 0.0;
      List<String> matchedDetails = [];
      for (var t in chakkraTxs) {
        if (t['status'] != 'ACCEPTED') continue;
        final tDate = DateTime.tryParse(t['created_at']?.toString() ?? '');
        if (tDate == null) continue;
        if (!tDate.isBefore(txDate)) continue;

        final tItem = (t['item_name']?.toString() ?? '').trim().toLowerCase();
        if (tItem != itemName) continue;

        final tRawUnit = t['unit']?.toString() ?? 'Units';
        final tUnit = tRawUnit.split(' {₹')[0].trim().toLowerCase();
        if (tUnit != unit) continue;

        final qty = double.tryParse(t['quantity']?.toString() ?? '0') ?? 0.0;
        final tType = t['transaction_type']?.toString().toUpperCase() ?? '';
        
        matchedDetails.add("${t['transaction_type']} ($qty) on ${t['created_at']}");
        if (tType == 'PURCHASE' || tType == 'RETURN') {
          stock += qty;
        } else if (tType == 'DELIVERY') {
          stock -= qty;
        }
      }
      
      final qty = double.tryParse(tx['quantity']?.toString() ?? '0') ?? 0.0;
      final type = tx['transaction_type']?.toString().toUpperCase() ?? '';
      
      final double stockAfter;
      if (type == 'PURCHASE' || type == 'RETURN') {
        stockAfter = stock + qty;
      } else if (type == 'DELIVERY') {
        stockAfter = stock - qty;
      } else {
        stockAfter = stock;
      }

      print("Tx Date: ${tx['created_at']} | Type: $type | Qty: $qty | Stock Before: $stock | Stock After: $stockAfter");
      print("  Matched historical txs: ${matchedDetails.join(', ')}");
    }
  } catch (e) {
    print("Error: $e");
  }
  
  await db.close();
  exit(0);
}
