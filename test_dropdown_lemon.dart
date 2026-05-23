import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const apiKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV0dWpreHJvYm16bHZ1ZHB2YXBjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5MzA2NjQsImV4cCI6MjA5MDUwNjY2NH0.REckx5fsLJMEJFnQVJdjyfNHC0seokVfPYkhOr5fxCw';
  
  try {
    final response = await http.get(
      Uri.parse('https://utujkxrobmzlvudpvapc.supabase.co/rest/v1/dropdown_options?select=*'),
      headers: {
        'apikey': apiKey,
        'Authorization': 'Bearer $apiKey',
      },
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      print('TOTAL DROPDOWN OPTIONS: ${data.length}');
      for (var opt in data) {
        final label = opt['label'].toString().toLowerCase();
        if (label.contains('lemon') || opt['image_url'] != null) {
          print('MATCH: id=${opt['id']}, type="${opt['type']}", label="${opt['label']}", image_url="${opt['image_url']}"');
        }
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}
