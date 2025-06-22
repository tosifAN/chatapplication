
import 'package:chatapplication/models/user.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/message.dart';
import 'models/group.dart';


class Boxes {
  static Box<User> get userBox => Hive.box<User>("users");
  static Box<Message> get messageBox => Hive.box<Message>("messages");
  static Box<Group> get groupBox => Hive.box<Group>("groups");

  static Future<void> initHive() async {
    await Hive.initFlutter();
  }

  static Map<Box<dynamic>, dynamic Function(dynamic json)> get allBoxes => {
    userBox: (json) => User.fromJson(json),
    messageBox : (json) => Message.fromJson(json),
    groupBox : (json) => Group.fromJson(json),
  };
}