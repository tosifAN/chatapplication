import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class HiveService {
  static Future<void> clearOldData() async {
    final appDocumentDir = await getApplicationDocumentsDirectory();
    final boxesToClear = [
      'chat_cache',
      'group_chat_cache',
      'search_cache',
      'recent_chats_cache',
      'user_groups_cache',
      'group_details_cache'
    ];
    await compute(_clearDataInBackground, {
      'dirPath': appDocumentDir.path,
      'boxNames': boxesToClear,
    });
  }
}

Future<void> _clearDataInBackground(Map<String, dynamic> args) async {
  final dirPath = args['dirPath'] as String;
  final boxNames = List<String>.from(args['boxNames'] as List);
  Hive.init(dirPath); 
  final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30)).millisecondsSinceEpoch;

  for (final boxName in boxNames) {
    try {
      final box = await Hive.openBox<Map>(boxName);
      final keysToDelete = <dynamic>[];

      for (final key in box.keys) {
        final data = box.get(key);
        if (data != null && data.containsKey('timestamp')) {
          final timestamp = data['timestamp'] as int;
          if (timestamp < thirtyDaysAgo) {
            keysToDelete.add(key);
          }
        }
      }

      await box.deleteAll(keysToDelete);

      print('----------------------- old data cleared ----------------');
      //await box.close();
    } catch (e) {
      print('Error clearing old data from $boxName: $e');
    }
  }
}