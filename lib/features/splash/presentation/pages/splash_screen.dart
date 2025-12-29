import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../auth/presentation/pages/login_screen.dart';
import '../../../dashboard/presentation/pages/dashboard_screen.dart';
import '../../../admin/presentation/pages/admin_dashboard.dart';
import '../../../auth/data/services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  final Widget? nextScreen;

  const SplashScreen({super.key, this.nextScreen});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _handleSplash();
  }

  Future<void> _handleSplash() async {
    // Artificial delay for splash branding
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;

    if (widget.nextScreen != null) {
       Navigator.pushReplacement(
         context,
         MaterialPageRoute(builder: (context) => widget.nextScreen!),
       );
    } else {
       // Legacy fallback behavior (if used as home)
       _checkAuth();
    }
  }

  Future<void> _checkAuth() async {
     final user = AuthService().currentUser;
     if (user != null) {
        final role = await AuthService().getUserRole();
        if (mounted) {
          if (role == 'admin') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const AdminDashboard()),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const DashboardScreen()),
            );
          }
        }
     } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
     }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.cloud,
              size: 100,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'AirDash',
              style: GoogleFonts.outfit(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}
