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
    final parentIds = [334, 682, 687, 719];
    print('--- CHECKING VARIANTS ---');
    for (var pid in parentIds) {
      final res = await http.get(
        Uri.parse('$supabaseUrl/dropdown_options?parent_id=eq.$pid&select=id,type,label,tax_percentage,parent_id'),
        headers: headers,
      );
      final list = jsonDecode(res.body) as List;
      print('Parent ID: $pid, Variants found: ${list.length}');
      for (var item in list) {
        print('  ID: ${item['id']}, Type: ${item['type']}, Label: "${item['label']}", Tax%: ${item['tax_percentage']}, ParentID: ${item['parent_id']}');
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}
