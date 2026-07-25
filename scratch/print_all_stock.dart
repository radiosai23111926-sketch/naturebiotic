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
  final txUrl = Uri.parse("https://utujkxrobmzlvudpvapc.supabase.co/rest/v1/store_transactions?select=*");
  
  final response = await http.get(
    txUrl,
    headers: {
      'apikey': anonKey,
      'Authorization': 'Bearer $token',
    },
  );
  
  final List<dynamic> transactions = jsonDecode(response.body);

  Map<String, Map<String, double>> stock = {};
  
  for (var tx in transactions.where((t) => t['status'] == 'ACCEPTED' || t['transaction_type'] == 'PURCHASE')) {
    final item = (tx['item_name']?.toString() ?? 'Unknown').trim();
    final qty = double.tryParse(tx['quantity']?.toString() ?? '0') ?? 0.0;
    final type = tx['transaction_type']?.toString();
    final rawUnit = tx['unit']?.toString() ?? 'Units';
    final unit = rawUnit.split(' {₹')[0].trim();

    if (!stock.containsKey(item)) stock[item] = {};

    if (type == 'PURCHASE' || type == 'RETURN') {
      stock[item]![unit] = (stock[item]![unit] ?? 0.0) + qty;
    } else if (type == 'DELIVERY') {
      stock[item]![unit] = (stock[item]![unit] ?? 0.0) - qty;
    }
  }
  
  print("STOCKS CALCULATED FROM DATABASE TRANSACTIONS:");
  print("-" * 60);
  for (var product in stock.keys) {
    print("$product: ${stock[product]}");
  }
  
  exit(0);
}
