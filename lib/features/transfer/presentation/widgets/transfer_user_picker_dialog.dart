import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:airdash/features/auth/data/services/auth_service.dart';

class TransferUserPickerDialog extends StatefulWidget {
  const TransferUserPickerDialog({super.key});

  @override
  State<TransferUserPickerDialog> createState() => _TransferUserPickerDialogState();
}

class _TransferUserPickerDialogState extends State<TransferUserPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  final String? _currentUserId = AuthService().currentUserUid;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Send to User"),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: "Search by name or email...",
                prefixIcon: Icon(LucideIcons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim().toLowerCase();
                });
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('users')
                  .limit(20) // Limit for safety
                  .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  
                  final users = snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      if (doc.id == _currentUserId) return false;
                      
                      if (_searchQuery.isEmpty) return true;
                      
                      final name = (data['name'] ?? '').toString().toLowerCase();
                      final email = (data['email'] ?? '').toString().toLowerCase();
                      
                      return name.contains(_searchQuery) || email.contains(_searchQuery);
                  }).toList();

                  if (users.isEmpty) {
                     return const Center(child: Text("No users found"));
                  }

                  return ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final data = users[index].data() as Map<String, dynamic>;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: data['photoUrl'] != null ? NetworkImage(data['photoUrl']) : null,
                          child: data['photoUrl'] == null 
                            ? Text((data['name'] ?? 'U')[0].toUpperCase()) 
                            : null,
                        ),
                        title: Text(data['name'] ?? 'Unknown'),
                        subtitle: Text(data['email'] ?? ''),
                        onTap: () {
                           Navigator.pop(context, users[index].id);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
      ],
    );
  }
}
