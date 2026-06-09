import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CachedJson {
  final dynamic data;
  final DateTime syncedAt;

  const CachedJson({required this.data, required this.syncedAt});
}

class LocalCacheStore {
  LocalCacheStore._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _prefix = 'planora_cache_';

  static Future<void> writeJson(String key, dynamic data) async {
    try {
      await _storage.write(
        key: '$_prefix$key',
        value: jsonEncode({
          'synced_at': DateTime.now().toUtc().toIso8601String(),
          'data': data,
        }),
      );
    } catch (error, stackTrace) {
      debugPrint('Cache write failed for $key: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<CachedJson?> readJson(String key) async {
    try {
      final raw = await _storage.read(key: '$_prefix$key');

      if (raw == null || raw.trim().isEmpty) {
        return null;
      }

      final decoded = jsonDecode(raw);

      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final syncedAt = DateTime.tryParse(
        decoded['synced_at']?.toString() ?? '',
      );

      if (syncedAt == null) {
        return null;
      }

      return CachedJson(data: decoded['data'], syncedAt: syncedAt.toLocal());
    } catch (error, stackTrace) {
      debugPrint('Cache read failed for $key: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  static Future<void> remove(String key) async {
    await _storage.delete(key: '$_prefix$key');
  }
}
