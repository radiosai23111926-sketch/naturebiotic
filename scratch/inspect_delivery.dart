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
  
  // 1. Get transaction details
  final txUrl = Uri.parse("https://utujkxrobmzlvudpvapc.supabase.co/rest/v1/store_transactions?id=eq.36501db8-a35a-4934-a8a0-3991cf5a1ff8&select=*");
  final txResponse = await http.get(txUrl, headers: {'apikey': anonKey, 'Authorization': 'Bearer $token'});
  print("Transaction Details:\n${txResponse.body}\n");
  
  // 2. Get profiles to find 'sri'
  final profilesUrl = Uri.parse("https://utujkxrobmzlvudpvapc.supabase.co/rest/v1/profiles?select=id,full_name,role");
  final profilesResponse = await http.get(profilesUrl, headers: {'apikey': anonKey, 'Authorization': 'Bearer $token'});
  final List<dynamic> profiles = jsonDecode(profilesResponse.body);
  print("Profiles:");
  for (var p in profiles) {
    print("ID: ${p['id']} | Name: ${p['full_name']} | Role: ${p['role']}");
  }
  
  exit(0);
}
