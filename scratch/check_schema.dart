import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const apiKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV0dWpreHJvYm16bHZ1ZHB2YXBjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5MzA2NjQsImV4cCI6MjA5MDUwNjY2NH0.REckx5fsLJMEJFnQVJdjyfNHC0seokVfPYkhOr5fxCw';
  
  // We can fetch table information using PostgREST / RPC or schema query
  // Since we don't have direct SQL command access through HTTP easily without RPC, 
  // we can fetch some records from farmers and print the keys, or try to see if there is any other info.
  // Wait, we can query public tables using the REST API to see their structure.
  
  try {
    final response = await http.get(
      Uri.parse('https://utujkxrobmzlvudpvapc.supabase.co/rest/v1/dropdown_options?limit=1'),
      headers: {
        'apikey': apiKey,
        'Authorization': 'Bearer $apiKey',
      },
    );
    print('Dropdown options response status: ${response.statusCode}');
    print('Dropdown options response body: ${response.body}');
  } catch (e) {
    print('Error: $e');
  }
}
