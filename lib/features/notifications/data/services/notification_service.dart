import 'package:hive_flutter/hive_flutter.dart';
import '../models/notification_model.dart';
import '../../../auth/data/services/auth_service.dart';

class NotificationService {
  static const String _boxName = 'notificationsBox';

  Future<void> init() async {
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(NotificationModelAdapter());
    }
    await Hive.openBox<NotificationModel>(_boxName);
  }

  Box<NotificationModel> get _box => Hive.box<NotificationModel>(_boxName);

  // Get notifications (Reverse chronological)
  List<NotificationModel> getNotifications() {
     final all = _box.values.toList();
     all.sort((a, b) => b.timestamp.compareTo(a.timestamp));
     return all;
  }
  
  // Unread count
  int get unreadCount => _box.values.where((n) => !n.isRead).length;

  // Add Notification
  Future<void> addNotification({required String title, required String body}) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final notification = NotificationModel(
      id: id,
      title: title,
      body: body,
      timestamp: DateTime.now(),
    );
    await _box.put(id, notification);
  }

  // Mark all as read
  Future<void> markAllAsRead() async {
    final unread = _box.values.where((n) => !n.isRead);
    for (var n in unread) {
      n.isRead = true;
      await n.save();
    }
  }

  // Clear All
  Future<void> clearAll() async {
    await _box.clear();
  }
}
