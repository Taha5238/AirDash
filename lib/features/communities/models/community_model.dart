import 'package:cloud_firestore/cloud_firestore.dart';

class Community {
  final String id;
  final String name;
  final String description;
  final Map<String, String> memberRoles; // userId -> 'admin', 'editor', 'viewer'
  final List<String> pendingMemberIds;
  final DateTime createdAt;
  final bool isPublic;
  final String createdBy; // Creator's ID

  const Community({
    required this.id,
    required this.name,
    required this.description,
    required this.memberRoles,
    required this.pendingMemberIds,
    required this.createdAt,
    required this.isPublic,
    required this.createdBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'memberRoles': memberRoles,
      'pendingMemberIds': pendingMemberIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'isPublic': isPublic,
      'createdBy': createdBy,
    };
  }

  factory Community.fromMap(Map<String, dynamic> map, String id) {
    return Community(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      memberRoles: Map<String, String>.from(map['memberRoles'] ?? {}),
      pendingMemberIds: List<String>.from(map['pendingMemberIds'] ?? []),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      isPublic: map['isPublic'] ?? true,
      createdBy: map['createdBy'] ?? '',
    );
  }

  // Helpers
  bool isAdmin(String userId) => memberRoles[userId] == 'admin';
  bool isEditor(String userId) => memberRoles[userId] == 'editor';
  bool isMember(String userId) => memberRoles.containsKey(userId);
}
