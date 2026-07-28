import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  final anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV0dWpreHJvYm16bHZ1ZHB2YXBjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5MzA2NjQsImV4cCI6MjA5MDUwNjY2NH0.REckx5fsLJMEJFnQVJdjyfNHC0seokVfPYkhOr5fxCw';
  final sriId = 'b105c9cb-23f0-4179-bdb9-69b895fdc731';
  
  // Fetch store_transactions for Sri
  final storeUrl = Uri.parse("https://utujkxrobmzlvudpvapc.supabase.co/rest/v1/store_transactions?executive_id=eq.$sriId&select=*");
  final res1 = await http.get(storeUrl, headers: {'apikey': anonKey});
  final List<dynamic> storeTxs = jsonDecode(res1.body);
  
  // Fetch stock_transactions for Sri
  final stockUrl = Uri.parse("https://utujkxrobmzlvudpvapc.supabase.co/rest/v1/stock_transactions?executive_id=eq.$sriId&select=*");
  final res2 = await http.get(stockUrl, headers: {'apikey': anonKey});
  final List<dynamic> stockTxs = jsonDecode(res2.body);
  
  print("Sri's Store Transactions (${storeTxs.length} found):");
  for (var tx in storeTxs) {
    print("ID: ${tx['id']} | Type: ${tx['transaction_type']} | Item: ${tx['item_name']} | Qty: ${tx['quantity']} | Unit: ${tx['unit']} | Status: ${tx['status']} | Date: ${tx['created_at']}");
  }
  
  print("\nSri's Stock Transactions (Field) (${stockTxs.length} found):");
  for (var tx in stockTxs) {
    print("ID: ${tx['id']} | Type: ${tx['transaction_type']} | Item: ${tx['item_name']} | Qty: ${tx['quantity']} | Unit: ${tx['unit']} | Date: ${tx['created_at']}");
  }
  
  exit(0);
}
