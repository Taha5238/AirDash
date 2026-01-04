import 'package:hive/hive.dart';

part 'notification_model.g.dart';

@HiveType(typeId: 2) // Using typeId 2 (0 and 1 likely taken by FileItem/User)
class NotificationModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String body;

  @HiveField(3)
  final DateTime timestamp;

  @HiveField(4)
  bool isRead;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
  });
}
