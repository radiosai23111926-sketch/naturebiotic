import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  final anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV0dWpreHJvYm16bHZ1ZHB2YXBjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5MzA2NjQsImV4cCI6MjA5MDUwNjY2NH0.REckx5fsLJMEJFnQVJdjyfNHC0seokVfPYkhOr5fxCw';
  final authUrl = Uri.parse("https://utujkxrobmzlvudpvapc.supabase.co/auth/v1/token?grant_type=password");
  
  print("Logging in via HTTP Auth...");
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
  
  if (loginResponse.statusCode != 200) {
    print("Login failed: ${loginResponse.statusCode} - ${loginResponse.body}");
    exit(1);
  }
  
  final loginData = jsonDecode(loginResponse.body);
  final token = loginData['access_token'];
  print("Login success!");
  
  print("Fetching store_transactions for Asstra...");
  final txUrl = Uri.parse("https://utujkxrobmzlvudpvapc.supabase.co/rest/v1/store_transactions?item_name=eq.Asstra&select=*");
  
  final response = await http.get(
    txUrl,
    headers: {
      'apikey': anonKey,
      'Authorization': 'Bearer $token',
    },
  );
  
  if (response.statusCode == 200) {
    final List<dynamic> data = jsonDecode(response.body);
    print("Transactions for Asstra (${data.length} found):");
    for (var tx in data) {
      print("ID: ${tx['id']} | Type: ${tx['transaction_type']} | Qty: ${tx['quantity']} | Unit: ${tx['unit']} | Status: ${tx['status']} | Date: ${tx['created_at']}");
    }
  } else {
    print("Error fetching transactions: ${response.statusCode} - ${response.body}");
  }
  
  exit(0);
}
