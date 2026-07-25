import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  final anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV0dWpreHJvYm16bHZ1ZHB2YXBjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5MzA2NjQsImV4cCI6MjA5MDUwNjY2NH0.REckx5fsLJMEJFnQVJdjyfNHC0seokVfPYkhOr5fxCw';
  final authUrl = Uri.parse("https://utujkxrobmzlvudpvapc.supabase.co/auth/v1/token?grant_type=password");
  
  final loginResponse = await http.post(
    authUrl,
    headers: {'apikey': anonKey, 'Content-Type': 'application/json'},
    body: jsonEncode({'email': 'naturebiotic96@gmail.com', 'password': 'admin123'}),
  );
  
  final token = jsonDecode(loginResponse.body)['access_token'];
  // Fetch ALL Asstra transactions (no unit filter - to catch "250ml {₹...}" variants too)
  final txUrl = Uri.parse("https://utujkxrobmzlvudpvapc.supabase.co/rest/v1/store_transactions?item_name=eq.Asstra&select=*");
  
  final response = await http.get(txUrl, headers: {
    'apikey': anonKey,
    'Authorization': 'Bearer $token',
  });
  
  final List<dynamic> data = jsonDecode(response.body);
  data.sort((a, b) => DateTime.parse(a['created_at']).compareTo(DateTime.parse(b['created_at'])));
  
  // Group by normalized unit (strip price suffix)
  final Map<String, double> balance = {};
  
  for (var tx in data) {
    if (tx['status'] != 'ACCEPTED') continue; // Only ACCEPTED transactions
    
    String rawUnit = tx['unit']?.toString() ?? 'Units';
    String unit = rawUnit.contains('{₹') ? rawUnit.split('{₹')[0].trim() : rawUnit;
    
    final qty = (tx['quantity'] as num).toDouble();
    final type = tx['transaction_type'];
    
    balance[unit] = (balance[unit] ?? 0.0);
    if (type == 'PURCHASE' || type == 'RETURN') {
      balance[unit] = balance[unit]! + qty;
    } else if (type == 'DELIVERY') {
      balance[unit] = balance[unit]! - qty;
    }
  }
  
  print("\nAsstra stock balance per unit (ACCEPTED only):");
  balance.forEach((unit, qty) => print("  $unit: $qty"));
  
  // Also compute WITH the old buggy filter for comparison
  final Map<String, double> oldBalance = {};
  for (var tx in data) {
    if (tx['status'] != 'ACCEPTED' && tx['transaction_type'] != 'PURCHASE') continue;
    
    String rawUnit = tx['unit']?.toString() ?? 'Units';
    String unit = rawUnit.contains('{₹') ? rawUnit.split('{₹')[0].trim() : rawUnit;
    
    final qty = (tx['quantity'] as num).toDouble();
    final type = tx['transaction_type'];
    
    oldBalance[unit] = (oldBalance[unit] ?? 0.0);
    if (type == 'PURCHASE' || type == 'RETURN') {
      oldBalance[unit] = oldBalance[unit]! + qty;
    } else if (type == 'DELIVERY') {
      oldBalance[unit] = oldBalance[unit]! - qty;
    }
  }
  
  print("\nAsstra stock balance per unit (OLD filter: ACCEPTED or type=PURCHASE):");
  oldBalance.forEach((unit, qty) => print("  $unit: $qty"));
  
  exit(0);
}
