import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  final anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV0dWpreHJvYm16bHZ1ZHB2YXBjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5MzA2NjQsImV4cCI6MjA5MDUwNjY2NH0.REckx5fsLJMEJFnQVJdjyfNHC0seokVfPYkhOr5fxCw';
  
  // Search profiles
  final url = Uri.parse("https://utujkxrobmzlvudpvapc.supabase.co/rest/v1/profiles?select=id,full_name,role");
  final res = await http.get(url, headers: {'apikey': anonKey});
  final List<dynamic> profiles = jsonDecode(res.body);
  
  print("All profiles:");
  for (var p in profiles) {
    print("ID: ${p['id']} | Name: ${p['full_name']} | Role: ${p['role']}");
  }
  
  exit(0);
}
