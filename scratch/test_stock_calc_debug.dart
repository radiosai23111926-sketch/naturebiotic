import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

Future<http.Response> postWithRetry(Uri url, Map<String, String> headers, String body) async {
  int attempts = 0;
  while (true) {
    try {
      attempts++;
      final res = await http.post(url, headers: headers, body: body).timeout(const Duration(seconds: 10));
      return res;
    } catch (e) {
      if (attempts >= 5) rethrow;
      print("POST Attempt $attempts failed: $e. Retrying in 1s...");
      await Future.delayed(const Duration(seconds: 1));
    }
  }
}

Future<http.Response> getWithRetry(Uri url, Map<String, String> headers) async {
  int attempts = 0;
  while (true) {
    try {
      attempts++;
      final res = await http.get(url, headers: headers).timeout(const Duration(seconds: 10));
      return res;
    } catch (e) {
      if (attempts >= 5) rethrow;
      print("GET Attempt $attempts failed: $e. Retrying in 1s...");
      await Future.delayed(const Duration(seconds: 1));
    }
  }
}

void main() async {
  final anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV0dWpreHJvYm16bHZ1ZHB2YXBjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5MzA2NjQsImV4cCI6MjA5MDUwNjY2NH0.REckx5fsLJMEJFnQVJdjyfNHC0seokVfPYkhOr5fxCw';
  final authUrl = Uri.parse("https://utujkxrobmzlvudpvapc.supabase.co/auth/v1/token?grant_type=password");
  
  final loginResponse = await postWithRetry(
    authUrl,
    {
      'apikey': anonKey,
      'Content-Type': 'application/json',
    },
    jsonEncode({
      'email': 'naturebiotic96@gmail.com',
      'password': 'admin123',
    }),
  );
  
  final token = jsonDecode(loginResponse.body)['access_token'];
  
  // Fetch ALL store transactions from Supabase (this simulates _allTransactions in UI)
  final txUrl = Uri.parse("https://utujkxrobmzlvudpvapc.supabase.co/rest/v1/store_transactions?select=*");
  final response = await getWithRetry(txUrl, {
    'apikey': anonKey,
    'Authorization': 'Bearer $token',
  });
  
  final List<dynamic> data = jsonDecode(response.body);
  final List<Map<String, dynamic>> allTxs = [];
  for (var tx in data) {
    allTxs.add({...tx, '_source': 'store'});
  }
  
  // Sort descending by date
  allTxs.sort((a, b) {
    final dateA = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
    final dateB = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
    return dateB.compareTo(dateA);
  });

  print("Total transactions loaded: ${allTxs.length}");

  // We want to debug stock calculations for Chakkra 250ml
  final chakkraTxs = allTxs.where((tx) => 
    (tx['item_name']?.toString() ?? '').trim().toLowerCase() == 'chakkra' &&
    (tx['unit']?.toString() ?? '').split(' {₹')[0].trim().toLowerCase() == '250ml'
  ).toList();

  print("Chakkra 250ml transactions: ${chakkraTxs.length}");

  for (var tx in chakkraTxs) {
    final txDate = DateTime.tryParse(tx['created_at']?.toString() ?? '');
    if (txDate == null) continue;

    final txType = tx['transaction_type']?.toString().toUpperCase() ?? '';
    final txQty = double.tryParse(tx['quantity']?.toString() ?? '0') ?? 0.0;
    
    // Calculate stock before tx using exact UI logic
    double stock = 0.0;
    print("\n==================================================");
    print("Evaluating Tx ID: ${tx['id']} | Type: $txType | Qty: $txQty | Date: ${tx['created_at']}");
    print("==================================================");

    for (var t in allTxs) {
      if (t['status'] != 'ACCEPTED') continue;
      if (t['_source'] == 'field') continue; // skips field source
      
      final tDate = DateTime.tryParse(t['created_at']?.toString() ?? '');
      if (tDate == null) continue;
      if (!tDate.isBefore(txDate)) continue;

      final tItem = (t['item_name']?.toString() ?? '').trim().toLowerCase();
      if (tItem != 'chakkra') continue;

      final tRawUnit = t['unit']?.toString() ?? 'Units';
      final tUnit = tRawUnit.split(' {₹')[0].trim().toLowerCase();
      if (tUnit != '250ml') continue;

      final qty = double.tryParse(t['quantity']?.toString() ?? '0') ?? 0.0;
      final tType = t['transaction_type']?.toString().toUpperCase() ?? '';
      
      print("  MATCHED t ID: ${t['id']} | Type: $tType | Qty: $qty | Date: ${t['created_at']}");
      if (tType == 'PURCHASE' || tType == 'RETURN') {
        stock += qty;
      } else if (tType == 'DELIVERY') {
        stock -= qty;
      }
    }
    
    final stockAfter = (txType == 'PURCHASE' || txType == 'RETURN') ? stock + txQty : stock - txQty;
    print("SUMMARY for ${tx['created_at']}: Stock Before: $stock | Qty: $txQty | Stock After: $stockAfter");
  }

  exit(0);
}
