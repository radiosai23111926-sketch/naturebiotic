import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const url = 'https://utujkxrobmzlvudpvapc.supabase.co/rest/v1/master_crops?id=eq.4';
  const apiKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV0dWpreHJvYm16bHZ1ZHB2YXBjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5MzA2NjQsImV4cCI6MjA5MDUwNjY2NH0.REckx5fsLJMEJFnQVJdjyfNHC0seokVfPYkhOr5fxCw';

  try {
    final response = await http.patch(
      Uri.parse(url),
      headers: {
        'apikey': apiKey,
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
      },
      body: jsonEncode({
        'image_url': 'https://utujkxrobmzlvudpvapc.supabase.co/storage/v1/object/public/dropdown_covers/319814da-eac5-445a-aedd-ce0e58b4bc04.jpg',
      }),
    );

    print('STATUS CODE: ${response.statusCode}');
    print('RESPONSE BODY: ${response.body}');
  } catch (e) {
    print('Error: $e');
  }
}
