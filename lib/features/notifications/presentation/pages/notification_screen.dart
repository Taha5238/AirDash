import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../data/services/notification_service.dart';
import '../../data/models/notification_model.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationService _service = NotificationService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.checkCheck),
            tooltip: 'Mark all read',
            onPressed: () {
               setState(() {
                 _service.markAllAsRead();
               });
            },
          ),
          IconButton(
            icon: const Icon(LucideIcons.trash2),
            tooltip: 'Clear all',
            onPressed: () {
               showDialog(context: context, builder: (_) => AlertDialog(
                 title: const Text('Clear all?'),
                 actions: [
                   TextButton(onPressed: ()=>Navigator.pop(context), child: const Text('Cancel')),
                   FilledButton(onPressed: () {
                     _service.clearAll();
                     Navigator.pop(context);
                     setState((){});
                   }, child: const Text('Clear')),
                 ],
               ));
            },
          )
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<NotificationModel>('notificationsBox').listenable(),
        builder: (context, Box<NotificationModel> box, _) {
          final notifications = _service.getNotifications();

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(LucideIcons.bellOff, size: 64, color: Colors.grey[300]),
                   const SizedBox(height: 16),
                   Text('No notifications', style: GoogleFonts.outfit(color: Colors.grey, fontSize: 18)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            separatorBuilder: (_,__) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = notifications[index];
              return Dismissible(
                key: Key(item.id),
                direction: DismissDirection.endToStart,
                onDismissed: (_) {
                  item.delete(); // HiveObject delete
                },
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(LucideIcons.trash2, color: Colors.white),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: item.isRead 
                        ? Theme.of(context).cardColor 
                        : Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).dividerColor.withOpacity(0.1),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                       padding: const EdgeInsets.all(10),
                       decoration: BoxDecoration(
                         color: Colors.red.withOpacity(0.1),
                         shape: BoxShape.circle,
                       ),
                       child: const Icon(LucideIcons.alertCircle, color: Colors.red),
                    ),
                    title: Text(
                      item.title,
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(item.body),
                        const SizedBox(height: 8),
                        Text(
                          DateFormat('MMM d, h:mm a').format(item.timestamp),
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    onTap: () {
                      if (!item.isRead) {
                        item.isRead = true;
                        item.save();
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
