import 'dart:io';
import 'package:path/path.dart';

void main() async {
  // Let's search for nature_biotic.db in common locations
  final userHome = Platform.environment['USERPROFILE'] ?? '';
  print('User home: $userHome');
  
  final dirsToSearch = [
    Directory(join(userHome, 'Documents')),
    Directory(join(userHome, 'AppData', 'Local')),
    Directory(join(userHome, 'AppData', 'Roaming')),
  ];
  
  for (var dir in dirsToSearch) {
    if (!dir.existsSync()) continue;
    print('Searching in ${dir.path}...');
    try {
      final files = dir.listSync(recursive: true, followLinks: false);
      for (var f in files) {
        if (f is File && basename(f.path) == 'nature_biotic.db') {
          print('Found db: ${f.path}');
        }
      }
    } catch (e) {
      print('Error listing ${dir.path}: $e');
    }
  }
}
