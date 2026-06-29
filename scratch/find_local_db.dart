import 'dart:io';
import 'package:path/path.dart';

void main() {
  final userHome = Platform.environment['USERPROFILE'] ?? '';
  print('User home: $userHome');
  
  final appDataLocal = Directory(join(userHome, 'AppData', 'Local'));
  final appDataRoaming = Directory(join(userHome, 'AppData', 'Roaming'));
  final documents = Directory(join(userHome, 'Documents'));
  
  search(appDataLocal);
  search(appDataRoaming);
  search(documents);
}

void search(Directory dir) {
  if (!dir.existsSync()) return;
  
  try {
    final entities = dir.listSync(recursive: false);
    for (var entity in entities) {
      if (entity is File) {
        if (basename(entity.path).toLowerCase() == 'nature_biotic.db') {
          print('FOUND DB: ${entity.path}');
        }
      } else if (entity is Directory) {
        final name = basename(entity.path).toLowerCase();
        // Skip large unneeded directories
        if (name == 'temp' || name == 'google' || name == 'microsoft' || name == 'cache' || name == 'packages' || name == 'package') {
          continue;
        }
        searchRecursive(entity);
      }
    }
  } catch (e) {
    // Ignore permissions errors
  }
}

void searchRecursive(Directory dir) {
  try {
    final entities = dir.listSync(recursive: true, followLinks: false);
    for (var entity in entities) {
      if (entity is File && basename(entity.path).toLowerCase() == 'nature_biotic.db') {
        print('FOUND DB: ${entity.path}');
      }
    }
  } catch (_) {}
}
