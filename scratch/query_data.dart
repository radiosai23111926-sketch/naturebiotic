import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const apiKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV0dWpreHJvYm16bHZ1ZHB2YXBjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5MzA2NjQsImV4cCI6MjA5MDUwNjY2NH0.REckx5fsLJMEJFnQVJdjyfNHC0seokVfPYkhOr5fxCw';
  const headers = {
    'apikey': apiKey,
    'Authorization': 'Bearer $apiKey',
    'Content-Type': 'application/json',
  };

  final supabaseUrl = 'https://utujkxrobmzlvudpvapc.supabase.co/rest/v1';

  try {
    final farmsRes = await http.get(Uri.parse('$supabaseUrl/farms?select=id,name'), headers: headers);
    final farms = jsonDecode(farmsRes.body) as List;
    print('--- FARMS ---');
    for (var f in farms) {
      print('Farm ID: ${f['id']}, Name: ${f['name']}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
