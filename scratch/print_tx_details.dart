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
  
  final txUrl = Uri.parse("https://utujkxrobmzlvudpvapc.supabase.co/rest/v1/store_transactions?item_name=eq.Chakkra&select=id,transaction_type,quantity,unit,status,created_at,executive_id,vendor_name");
  final response = await getWithRetry(txUrl, {
    'apikey': anonKey,
    'Authorization': 'Bearer $token',
  });
  
  final List<dynamic> data = jsonDecode(response.body);
  
  for (var tx in data) {
    print("ID: ${tx['id']} | Type: ${tx['transaction_type']} | Qty: ${tx['quantity']} | ExecID: ${tx['executive_id']} | Vendor: ${tx['vendor_name']} | Date: ${tx['created_at']}");
  }

  exit(0);
}
