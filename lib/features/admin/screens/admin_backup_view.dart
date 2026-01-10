import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../files/repositories/supabase_file_service.dart';

class AdminBackupView extends StatefulWidget {
  const AdminBackupView({super.key});

  @override
  State<AdminBackupView> createState() => _AdminBackupViewState();
}

class _AdminBackupViewState extends State<AdminBackupView> {
  final SupabaseFileService _supabaseService = SupabaseFileService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _backups = [];

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabaseService.getAllBackups();
      setState(() {
        _backups = data;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading backups: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteBackup(String id, String path, String uid) async {
    bool? confirm = await showDialog(
      context: context, 
      builder: (context) => AlertDialog(
        title: const Text("Delete Cloud Backup?"),
        content: const Text("This cannot be undone. The file will be removed from Supabase Storage and the Database."),
        actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
            FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true), 
                child: const Text("Delete")
            ),
        ],
      )
    );

    if (confirm != true) return;

    try {
        await _supabaseService.deleteBackup(id, path, uid);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Backup deleted successfully"))
        );
        _loadBackups(); // Refresh
    } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Delete failed: $e"), backgroundColor: Colors.red)
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_backups.isEmpty) {
        return Center(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                    Icon(LucideIcons.cloudOff, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text("No cloud backups found."),
                ]
            )
        );
    }

    return Scaffold(
        appBar: AppBar(
            title: const Text("Cloud Backups"),
            actions: [
                IconButton(icon: const Icon(LucideIcons.refreshCcw), onPressed: _loadBackups)
            ],
        ),
        body: ListView.builder(
            itemCount: _backups.length,
            itemBuilder: (context, index) {
                final item = _backups[index];
                final String name = item['file_name'] ?? 'Unknown';
                final String size = item['file_size'] ?? 'Unknown Size';
                final String uid = item['uid'] ?? 'Unknown User';
                final String date = item['created_at'] != null 
                    ? DateFormat.yMMMd().add_jm().format(DateTime.parse(item['created_at']).toLocal()) 
                    : '';

                return ListTile(
                    leading: const CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: Icon(LucideIcons.cloud, color: Colors.white),
                    ),
                    title: Text(name),
                    subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Text("User ID: $uid", style: const TextStyle(fontSize: 12)),
                            Text("$size • $date", style: const TextStyle(fontSize: 12)),
                        ],
                    ),
                    trailing: IconButton(
                        icon: const Icon(LucideIcons.trash2, color: Colors.red),
                        onPressed: () => _deleteBackup(item['id'], item['storage_path'], item['uid']),
                    ),
                );
            }
        ),
    );
  }
}
