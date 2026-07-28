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
  
  final url = Uri.parse("https://utujkxrobmzlvudpvapc.supabase.co/rest/v1/dropdown_options?label=ilike.*Chakkra*&select=*");
  final response = await http.get(url, headers: {'apikey': anonKey, 'Authorization': 'Bearer $token'});
  final List<dynamic> data = jsonDecode(response.body);
  
  print("Options containing 'Chakkra' (${data.length} found):");
  for (var item in data) {
    print("ID: ${item['id']} | Type: ${item['type']} | Label: '${item['label']}' | Parent ID: ${item['parent_id']}");
  }
  
  exit(0);
}
