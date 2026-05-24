import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const url = 'https://utujkxrobmzlvudpvapc.supabase.co/storage/v1/object/list/dropdown_covers';
  const apiKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV0dWpreHJvYm16bHZ1ZHB2YXBjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5MzA2NjQsImV4cCI6MjA5MDUwNjY2NH0.REckx5fsLJMEJFnQVJdjyfNHC0seokVfPYkhOr5fxCw';

  try {
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'apikey': apiKey,
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'prefix': '',
        'limit': 100,
        'sortBy': {
          'column': 'name',
          'order': 'asc',
        },
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      print('FILES IN dropdown_covers BUCKET: ${data.length}');
      for (var file in data) {
        print('FILE: name="${file['name']}", size=${file['metadata']?['size']} bytes, created_at=${file['created_at']}');
      }
    } else {
      print('ERROR: Status code ${response.statusCode}');
      print('RESPONSE: ${response.body}');
    }
  } catch (e) {
    print('ERROR LISTING STORAGE FILES: $e');
  }
}
