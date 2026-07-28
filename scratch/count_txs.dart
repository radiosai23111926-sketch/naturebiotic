import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  final anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV0dWpreHJvYm16bHZ1ZHB2YXBjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5MzA2NjQsImV4cCI6MjA5MDUwNjY2NH0.REckx5fsLJMEJFnQVJdjyfNHC0seokVfPYkhOr5fxCw';
  
  final res1 = await http.get(
    Uri.parse("https://utujkxrobmzlvudpvapc.supabase.co/rest/v1/store_transactions?select=id"),
    headers: {
      'apikey': anonKey,
      'Range-Unit': 'items',
      'Prefer': 'count=exact'
    }
  );
  
  print("Response headers: ${res1.headers}");
  print("Content-Range: ${res1.headers['content-range']}");
  exit(0);
}
