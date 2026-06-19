import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const apiKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV0dWpreHJvYm16bHZ1ZHB2YXBjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5MzA2NjQsImV4cCI6MjA5MDUwNjY2NH0.REckx5fsLJMEJFnQVJdjyfNHC0seokVfPYkhOr5fxCw';
  
  // Since we don't have direct SQL access, we can query via PostgREST if we have an RPC, 
  // or we can try to call a query if there is any database function.
  // Wait! Does Supabase allow querying information_schema via PostgREST?
  // By default, information_schema is not exposed to the anon/authenticated roles unless a custom RPC function is created.
  // Let's see if we can do an RPC call or if there's any other way.
  // Wait, let's search if there are any custom RPC functions in the codebase.
  // Let's search for "rpc" in supabase_service.dart.
  
  try {
    final response = await http.get(
      Uri.parse('https://utujkxrobmzlvudpvapc.supabase.co/rest/v1/'),
      headers: {
        'apikey': apiKey,
        'Authorization': 'Bearer $apiKey',
      },
    );
    print('Status: ${response.statusCode}');
    if (response.statusCode == 200) {
      final swagger = jsonDecode(response.body);
      final paths = swagger['paths'] as Map;
      print('Available REST paths:');
      paths.keys.forEach((k) {
        if (k.toString().startsWith('/rpc/')) {
          print('  RPC: $k');
        } else {
          print('  Table: $k');
        }
      });
    }
  } catch (e) {
    print('Error: $e');
  }
}
