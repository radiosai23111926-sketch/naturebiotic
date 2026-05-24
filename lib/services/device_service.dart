import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:device_info_plus/device_info_plus.dart';

class DeviceService {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  static Future<Map<String, String>> getDeviceInfo() async {
    try {
      if (kIsWeb) {
        return {
          'id': 'Web-Browser',
          'name': 'Web Browser',
          'os': 'Web Client',
        };
      }
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return {
          'id': androidInfo.id, // Android Hardware ID
          'name': '${androidInfo.brand} ${androidInfo.model}',
          'os': 'Android ${androidInfo.version.release}',
        };
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return {
          'id': iosInfo.identifierForVendor ?? 'Unknown-iOS',
          'name': iosInfo.name,
          'os': 'iOS ${iosInfo.systemVersion}',
        };
      }
    } catch (e) {
      debugPrint('DEBUG: Error getting device info: $e');
    }
    return {
      'id': 'Unknown',
      'name': 'Unknown Device',
      'os': 'Unknown OS',
    };
  }
}
