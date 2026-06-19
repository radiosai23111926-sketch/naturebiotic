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
      
      final Map<String, int> counts = {};
      for (var opt in data) {
        final type = opt['type'].toString();
        counts[type] = (counts[type] ?? 0) + 1;
      }
      
      print('\nCounts by type:');
      counts.forEach((type, count) {
        print('  $type: $count items');
      });
      
      print('\nItems of type problem_category:');
      for (var opt in data) {
        if (opt['type'] == 'problem_category') {
          print('  ID: ${opt['id']}, Label: "${opt['label']}", Parent ID: ${opt['parent_id']}');
        }
      }
      
      print('\nItems of type problem_item (first 10):');
      int count = 0;
      for (var opt in data) {
        if (opt['type'] == 'problem_item') {
          count++;
          if (count <= 10) {
            print('  ID: ${opt['id']}, Label: "${opt['label']}", Parent ID: ${opt['parent_id']}');
          }
        }
      }
      print('  Total problem_items: $count');
    }
  } catch (e) {
    print('Error: $e');
  }
}
