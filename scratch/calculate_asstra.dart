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
  final txUrl = Uri.parse("https://utujkxrobmzlvudpvapc.supabase.co/rest/v1/store_transactions?item_name=eq.Asstra&unit=eq.250ml&select=*");
  
  final response = await http.get(
    txUrl,
    headers: {
      'apikey': anonKey,
      'Authorization': 'Bearer $token',
    },
  );
  
  final List<dynamic> data = jsonDecode(response.body);
  // Sort chronologically
  data.sort((a, b) {
    final dateA = DateTime.parse(a['created_at']);
    final dateB = DateTime.parse(b['created_at']);
    return dateA.compareTo(dateB);
  });
  
  double runningBalance = 0;
  print("Step-by-step transactions for Asstra 250ml:\n");
  print("Date                     | Type     | Qty | New Balance | Transaction ID");
  print("-" * 90);
  
  for (var tx in data) {
    if (tx['status'] != 'ACCEPTED' && tx['transaction_type'] != 'PURCHASE') {
      continue;
    }
    
    final type = tx['transaction_type'];
    final qty = (tx['quantity'] as num).toDouble();
    
    if (type == 'PURCHASE' || type == 'RETURN') {
      runningBalance += qty;
    } else if (type == 'DELIVERY') {
      runningBalance -= qty;
    }
    
    print("${tx['created_at'].substring(0, 19)} | ${type.toString().padRight(8)} | ${qty.toString().padRight(3)} | ${runningBalance.toString().padRight(11)} | ${tx['id']}");
  }
  
  exit(0);
}
