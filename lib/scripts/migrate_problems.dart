import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://utujkxrobmzlvudpvapc.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV0dWpreHJvYm16bHZ1ZHB2YXBjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5MzA2NjQsImV4cCI6MjA5MDUwNjY2NH0.REckx5fsLJMEJFnQVJdjyfNHC0seokVfPYkhOr5fxCw',
  );

  print('Fetching all problem categories, subcategories, and items...');

  try {
    final categories = await supabase.from('dropdown_options').select().eq('type', 'problem_category');
    final subcategories = await supabase.from('dropdown_options').select().eq('type', 'problem_subcategory');
    final items = await supabase.from('dropdown_options').select().eq('type', 'problem_item');

    print('Found ${categories.length} categories, ${subcategories.length} subcategories, and ${items.length} items.');

    int migratedCount = 0;

    for (var item in items) {
      final parentId = item['parent_id'];
      if (parentId != null) {
        // Check if the parent_id points to a subcategory
        final subcategory = subcategories.cast<Map<String, dynamic>>().firstWhere(
              (s) => s['id'] == parentId,
              orElse: () => {},
            );

        if (subcategory.isNotEmpty) {
          final rootCategoryId = subcategory['parent_id'];
          if (rootCategoryId != null) {
            print('Migrating item "${item['label']}" from Subcategory "${subcategory['label']}" to Root Category ID $rootCategoryId');
            
            // Update the item's parent_id
            await supabase.from('dropdown_options').update({'parent_id': rootCategoryId}).eq('id', item['id']);
            migratedCount++;
          } else {
            print('Warning: Subcategory "${subcategory['label']}" has no parent_id!');
          }
        }
      }
    }

    print('Successfully migrated $migratedCount items.');

    if (subcategories.isNotEmpty) {
      print('Deleting all ${subcategories.length} problem_subcategories...');
      for (var sub in subcategories) {
        await supabase.from('dropdown_options').delete().eq('id', sub['id']);
      }
      print('Deleted all subcategories.');
    } else {
      print('No subcategories to delete.');
    }

  } catch (e) {
    print('Error during migration: $e');
  }

  print('Migration complete.');
}
