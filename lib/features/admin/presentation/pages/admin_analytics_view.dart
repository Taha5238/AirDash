import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

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
        final double maxStorageMB = 500.0; // Assume 500MB limit for demo
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
                               const Text(
                                 "of 500 MB (Estimated Limit)",
                                 style: TextStyle(color: Colors.white38, fontSize: 14),
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
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _fetchStats() async {
    final userSnap = await FirebaseFirestore.instance.collection('users').count().get();
    
    // Aggregation for Total Files & Storage
    // Ideally user 'stats' documents, but iterating 'users' with stored stats is better than iterating all files
    // For now, we iterate 'files' collection as done previously, OR iterate users if we trust the new counters.
    // To match the new logic: Let's sum up storageUsed from all users (if we ran a migration).
    // BUT since we just added the logic, old users won't have the field.
    // So we STICK to the old method (iterating files) for accuracy until migration script is run.
    
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
