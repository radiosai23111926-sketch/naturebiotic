import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  print("Initializing Supabase...");
  await Supabase.initialize(
    url: 'https://utujkxrobmzlvudpvapc.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV0dWpreHJvYm16bHZ1ZHB2YXBjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5MzA2NjQsImV4cCI6MjA5MDUwNjY2NH0.REckx5fsLJMEJFnQVJdjyfNHC0seokVfPYkhOr5fxCw',
  );

  final client = Supabase.instance.client;
  
  try {
    print("Logging in as admin...");
    final authResponse = await client.auth.signInWithPassword(
      email: 'naturebiotic96@gmail.com',
      password: 'admin123',
    );
    print("Logged in. User ID: ${authResponse.user?.id}");

    print("Fetching store_transactions...");
    final response = await client.from('store_transactions')
        .select('*')
        .order('created_at', ascending: false);

    print("Total transactions: ${response.length}");
    for (var tx in response) {
      print("ID: ${tx['id']} | Type: ${tx['transaction_type']} | Item: ${tx['item_name']} | Qty: ${tx['quantity']} | Unit: ${tx['unit']} | Status: ${tx['status']} | Date: ${tx['created_at']}");
    }
  } catch (e) {
    print("Error: $e");
  }

  print("Done. Exiting.");
  exit(0);
}
