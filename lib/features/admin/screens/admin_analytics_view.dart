import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

class AdminAnalyticsView extends StatefulWidget {
  const AdminAnalyticsView({super.key});

  @override
  State<AdminAnalyticsView> createState() => _AdminAnalyticsViewState();
}

class _AdminAnalyticsViewState extends State<AdminAnalyticsView> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
     super.initState();
     _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
     _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart);
     _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchStats(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final data = snapshot.data ?? {'users': 0, 'files': 0, 'storage': 0};
        final double totalStorageMB = (data['storage'] as int) / (1024 * 1024);
        
        // Dynamic Capacity: Scale in 100GB chunks
        
        final int chunks = (totalStorageMB / 102400).ceil();
        final double maxStorageMB = (chunks > 1 ? chunks : 1) * 102400.0;
        
        final double remainingMB = maxStorageMB - totalStorageMB;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dashboard',
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              
              // System Health Row
              const _SystemHealthRow(),
              const SizedBox(height: 24),
              
              // Animated Storage Chart
              FadeTransition(
                opacity: _animation,
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(_animation),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                           Colors.blue.shade900,
                           Colors.purple.shade900,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               const Text(
                                 "Total Storage Used",
                                 style: TextStyle(color: Colors.white70, fontSize: 16),
                               ),
                               const SizedBox(height: 8),
                               Text(
                                 _formatSize(data['storage']),
                                 style: GoogleFonts.outfit(
                                   color: Colors.white,
                                   fontSize: 36,
                                   fontWeight: FontWeight.bold,
                                 ),
                               ),
                               const SizedBox(height: 4),
                               Text(
                                 "of ${(maxStorageMB / 1024).toStringAsFixed(0)} GB (First 100 GB Capacity)",
                                 style: const TextStyle(color: Colors.white38, fontSize: 14),
                               ),
                             ],
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: SizedBox(
                            height: 120,
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 0,
                                centerSpaceRadius: 30,
                                sections: [
                                  PieChartSectionData(
                                    color: Colors.white,
                                    value: totalStorageMB,
                                    title: '',
                                    radius: 20,
                                    showTitle: false,
                                  ),
                                  PieChartSectionData(
                                    color: Colors.white.withOpacity(0.1),
                                    value: remainingMB > 0 ? remainingMB : 0,
                                    title: '',
                                    radius: 15,
                                    showTitle: false,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),

              // Stats Cards Grid
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'Registered Users',
                      value: data['users'].toString(),
                      icon: LucideIcons.users,
                      color: Colors.blue,
                      delay: 200,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatCard(
                      title: 'Total Files Uploaded',
                      value: data['files'].toString(),
                      icon: LucideIcons.fileStack, // Using available icon
                      color: Colors.orange,
                      delay: 400,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Recent Activity Section
              Text(
                'Recent Activity',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const _RecentActivityList(),
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _fetchStats() async {
    final userSnap = await FirebaseFirestore.instance.collection('users').count().get();
    
  
    
    final files = await FirebaseFirestore.instance.collection('files').get();
    int totalBytes = 0;
    for (var doc in files.docs) {
      totalBytes += (doc.data()['size'] as num? ?? 0).toInt();
    }

    return {
      'users': userSnap.count,
      'files': files.docs.length,
      'storage': totalBytes,
    };
  }
  
  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final int delay;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.delay = 0,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 800 + delay),
      curve: Curves.easeOutBack,
      builder: (context, val, child) {
        return Transform.scale(
          scale: val,
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SystemHealthRow extends StatelessWidget {
  const _SystemHealthRow();

  Widget _buildStatusPill(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _buildStatusPill('Server Online', Colors.green, LucideIcons.wifi),
        _buildStatusPill('DB Connected', Colors.blue, LucideIcons.database),
        _buildStatusPill('Storage Healthy', Colors.purple, LucideIcons.hardDrive),
      ],
    );
  }
}

class _RecentActivityList extends StatelessWidget {
  const _RecentActivityList();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('files')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final files = snapshot.data!.docs;
        
        if (files.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(child: Text('No recent activity')),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: files.map((doc) {
              return _RecentActivityItem(doc: doc, isLast: doc == files.last);
            }).toList(),
          ),
        );
      },
    );
  }
}

class _RecentActivityItem extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final bool isLast;

  const _RecentActivityItem({required this.doc, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final String? storedName = data['userName'];
    final String userId = data['userId'] ?? '';
    final Timestamp? createdAt = data['createdAt'];

    return FutureBuilder<String>(
      future: storedName != null 
          ? Future.value(storedName) 
          : _fetchUserName(userId),
      builder: (context, snapshot) {
        final userName = snapshot.data ?? 'User'; // Fallback while loading
        
        return Column(
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(LucideIcons.file, color: Colors.blue, size: 20),
              ),
              title: Text(data['name'] ?? 'Unknown File', maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('Uploaded by $userName'),
              trailing: Text(
                createdAt != null 
                    ? DateFormat('MMM d, h:mm a').format(createdAt.toDate()) 
                    : 'Just now', 
                style: const TextStyle(color: Colors.grey, fontSize: 12)
              ),
            ),
            if (!isLast) const Divider(height: 1, indent: 60),
          ],
        );
      }
    );
  }

  Future<String> _fetchUserName(String userId) async {
      if (userId.isEmpty) return 'Unknown User';
      try {
          final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
          if (doc.exists) {
              return doc.data()?['name'] ?? 'Unknown User';
          }
      } catch (e) {
          // ignore error
      }
      return 'Unknown User';
  }
}
