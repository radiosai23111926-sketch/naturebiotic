import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  final anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV0dWpreHJvYm16bHZ1ZHB2YXBjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5MzA2NjQsImV4cCI6MjA5MDUwNjY2NH0.REckx5fsLJMEJFnQVJdjyfNHC0seokVfPYkhOr5fxCw';
  final authUrl = Uri.parse("https://utujkxrobmzlvudpvapc.supabase.co/auth/v1/token?grant_type=password");
  
  final loginResponse = await http.post(
    authUrl,
    headers: {
      'apikey': anonKey,
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'email': 'naturebiotic96@gmail.com',
      'password': 'admin123',
    }),
  );
  
  final token = jsonDecode(loginResponse.body)['access_token'];
  final txUrl = Uri.parse("https://utujkxrobmzlvudpvapc.supabase.co/rest/v1/store_transactions?item_name=eq.Asstra&select=*");
  
  final response = await http.get(
    txUrl,
    headers: {
      'apikey': anonKey,
      'Authorization': 'Bearer $token',
    },
  );
  
  final List<dynamic> transactions = jsonDecode(response.body);

  Map<String, Map<String, double>> stock = {};
  
  print("Applying app logic (_calculateDetailedStock):");
  print("-" * 80);
  
  for (var tx in transactions.where((t) => t['status'] == 'ACCEPTED' || t['transaction_type'] == 'PURCHASE')) {
    final item = (tx['item_name']?.toString() ?? 'Unknown').trim();
    final qty = double.tryParse(tx['quantity']?.toString() ?? '0') ?? 0.0;
    final type = tx['transaction_type']?.toString();
    final rawUnit = tx['unit']?.toString() ?? 'Units';
    final unit = rawUnit.split(' {₹')[0].trim();

    if (!stock.containsKey(item)) stock[item] = {};
    
    final oldVal = stock[item]![unit] ?? 0.0;
    double newVal = oldVal;

    if (type == 'PURCHASE' || type == 'RETURN') {
      newVal = oldVal + qty;
      stock[item]![unit] = newVal;
    } else if (type == 'DELIVERY') {
      newVal = oldVal - qty;
      stock[item]![unit] = newVal;
    }
    
    if (unit == '250ml') {
      print("Tx Date: ${tx['created_at'].substring(0, 16)} | Type: $type | Status: ${tx['status']} | Qty: $qty | Bal: $oldVal -> $newVal | ID: ${tx['id'].substring(0, 8)}");
    }
  }
  
  print("\nFinal stock for Asstra:");
  print(stock['Asstra']);
  
  exit(0);
}
