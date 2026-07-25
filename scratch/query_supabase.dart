import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url = Uri.parse("https://utujkxrobmzlvudpvapc.supabase.co/rest/v1/store_transactions?select=*");
  final headers = {
    'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV0dWpreHJvYm16bHZ1ZHB2YXBjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5MzA2NjQsImV4cCI6MjA5MDUwNjY2NH0.REckx5fsLJMEJFnQVJdjyfNHC0seokVfPYkhOr5fxCw',
    'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV0dWpreHJvYm16bHZ1ZHB2YXBjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5MzA2NjQsImV4cCI6MjA5MDUwNjY2NH0.REckx5fsLJMEJFnQVJdjyfNHC0seokVfPYkhOr5fxCw',
  };

  try {
    final response = await http.get(url, headers: headers);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      print("Total transactions: ${data.length}");
      for (var tx in data) {
        print("ID: ${tx['id']} | Type: ${tx['transaction_type']} | Item: ${tx['item_name']} | Qty: ${tx['quantity']} | Unit: ${tx['unit']} | Status: ${tx['status']} | Date: ${tx['created_at']}");
      }
    } else {
      print("Error: ${response.statusCode} - ${response.body}");
    }
  } catch (e) {
    print("Exception: $e");
  }
}
