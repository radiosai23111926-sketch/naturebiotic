import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const apiKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV0dWpreHJvYm16bHZ1ZHB2YXBjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5MzA2NjQsImV4cCI6MjA5MDUwNjY2NH0.REckx5fsLJMEJFnQVJdjyfNHC0seokVfPYkhOr5fxCw';
  
  // 1. Search dropdown_options for any label matching "Lemon"
  try {
    final response = await http.get(
      Uri.parse('https://utujkxrobmzlvudpvapc.supabase.co/rest/v1/dropdown_options?label=eq.Lemon&select=*'),
      headers: {
        'apikey': apiKey,
        'Authorization': 'Bearer $apiKey',
      },
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      print('DROPDOWN OPTIONS MATCHING "Lemon": ${data.length}');
      for (var opt in data) {
        print('OPTION: id=${opt['id']}, type="${opt['type']}", label="${opt['label']}", image_url="${opt['image_url']}"');
      }
    }
  } catch (e) {
    print('Error dropdown options: $e');
  }

  // 2. Search dropdown_options for any options with a non-null image_url
  try {
    final response = await http.get(
      Uri.parse('https://utujkxrobmzlvudpvapc.supabase.co/rest/v1/dropdown_options?image_url=not.eq.null&select=*'),
      headers: {
        'apikey': apiKey,
        'Authorization': 'Bearer $apiKey',
      },
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      print('DROPDOWN OPTIONS WITH IMAGE_URL: ${data.length}');
      for (var opt in data) {
        print('OPTION: id=${opt['id']}, type="${opt['type']}", label="${opt['label']}", image_url="${opt['image_url']}"');
      }
    }
  } catch (e) {
    print('Error dropdown options image: $e');
  }
}
