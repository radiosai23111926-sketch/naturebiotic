import 'dart:io';
import 'package:path/path.dart';

void main() {
  final file = File('C:\\Users\\ASUS\\Documents\\nature_biotic.db');
  if (file.existsSync()) {
    print('DB exists! Size: ${file.lengthSync()} bytes');
  } else {
    print('DB does not exist at C:\\Users\\ASUS\\Documents\\nature_biotic.db');
  }
}
