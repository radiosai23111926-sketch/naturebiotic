import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  final anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV0dWpreHJvYm16bHZ1ZHB2YXBjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5MzA2NjQsImV4cCI6MjA5MDUwNjY2NH0.REckx5fsLJMEJFnQVJdjyfNHC0seokVfPYkhOr5fxCw';
  
  // Fetch ALL store transactions for Chakkra with no limit (using offset if needed, but let's query with a large limit)
  final txUrl = Uri.parse("https://utujkxrobmzlvudpvapc.supabase.co/rest/v1/store_transactions?item_name=eq.Chakkra&select=unit");
  final response = await http.get(txUrl, headers: {'apikey': anonKey});
  final List<dynamic> data = jsonDecode(response.body);
  
  final Map<String, int> unitsCount = {};
  for (var row in data) {
    final u = row['unit']?.toString() ?? 'null';
    unitsCount[u] = (unitsCount[u] ?? 0) + 1;
  }
  
  print("Chakkra unit counts: $unitsCount");
  exit(0);
}
