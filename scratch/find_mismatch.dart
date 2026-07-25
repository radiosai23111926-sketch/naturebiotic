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
  transactions.sort((a, b) => DateTime.parse(a['created_at']).compareTo(DateTime.parse(b['created_at'])));

  double qty250 = 0;
  double qty100 = 0;
  double qty1L = 0;
  
  print("Date                     | Tx Type  | Unit  | Qty | 250ml | 100ml | 1Ltr | Display 250 | ID");
  print("-" * 110);
  
  for (var tx in transactions.where((t) => t['status'] == 'ACCEPTED' || t['transaction_type'] == 'PURCHASE')) {
    final type = tx['transaction_type'];
    final rawUnit = tx['unit']?.toString() ?? 'Units';
    final unit = rawUnit.split(' {₹')[0].trim();
    final qty = double.parse(tx['quantity'].toString());
    
    if (unit == '250ml') {
      if (type == 'PURCHASE' || type == 'RETURN') {
        qty250 += qty;
      } else {
        qty250 -= qty;
      }
    } else if (unit == '100ml') {
      if (type == 'PURCHASE' || type == 'RETURN') {
        qty100 += qty;
      } else {
        qty100 -= qty;
      }
    } else if (unit == '1 Ltr') {
      if (type == 'PURCHASE' || type == 'RETURN') {
        qty1L += qty;
      } else {
        qty1L -= qty;
      }
    }
    
    final display250 = qty250 > 0 ? qty250 : 0.0;
    
    print("${tx['created_at'].substring(0, 19)} | ${type.toString().padRight(8)} | ${unit.padRight(5)} | ${qty.toString().padRight(3)} | ${qty250.toString().padRight(5)} | ${qty100.toString().padRight(5)} | ${qty1L.toString().padRight(4)} | ${display250.toString().padRight(11)} | ${tx['id'].substring(0, 8)}");
  }
  
  exit(0);
}
