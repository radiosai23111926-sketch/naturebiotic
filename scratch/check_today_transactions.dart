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
  final txUrl = Uri.parse("https://utujkxrobmzlvudpvapc.supabase.co/rest/v1/store_transactions?created_at=gte.2026-07-24T00:00:00&select=*");
  
  final response = await http.get(
    txUrl,
    headers: {
      'apikey': anonKey,
      'Authorization': 'Bearer $token',
    },
  );
  
  final List<dynamic> data = jsonDecode(response.body);
  print("Transactions since July 24, 2026 (${data.length} found):");
  for (var tx in data) {
    print("ID: ${tx['id']} | Type: ${tx['transaction_type']} | Item: ${tx['item_name']} | Qty: ${tx['quantity']} | Unit: ${tx['unit']} | Status: ${tx['status']} | Date: ${tx['created_at']}");
  }
  
  exit(0);
}
