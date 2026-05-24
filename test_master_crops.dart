import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const url = 'https://utujkxrobmzlvudpvapc.supabase.co/rest/v1/master_crops?select=*';
  const apiKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV0dWpreHJvYm16bHZ1ZHB2YXBjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5MzA2NjQsImV4cCI6MjA5MDUwNjY2NH0.REckx5fsLJMEJFnQVJdjyfNHC0seokVfPYkhOr5fxCw';
  
  try {
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'apikey': apiKey,
        'Authorization': 'Bearer $apiKey',
      },
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      print('MASTER CROPS COUNT: ${data.length}');
      
      for (var opt in data) {
        print('MASTER CROP: id=${opt['id']}, name="${opt['name']}", image_url="${opt['image_url']}"');
      }
    } else {
      print('ERROR: Status code ${response.statusCode}');
      print('RESPONSE: ${response.body}');
    }
  } catch (e) {
    print('ERROR FETCHING MASTER CROPS: $e');
  }
}

