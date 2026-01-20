import 'package:flutter/material.dart';
import 'verification_screen.dart';

import '../../dashboard/screens/dashboard_screen.dart';
import '../../admin/screens/admin_dashboard.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class AuthCheck extends StatefulWidget {
  const AuthCheck({super.key});

  @override
  State<AuthCheck> createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    
    await Future.delayed(Duration.zero);
    
    if (mounted) {
       final user = AuthService().currentUser;
       if (user != null) {
          // If already logged in, check role and go to dashboard immediately
          final role = await AuthService().getUserRole();
          
          if (mounted) {

             await user.reload();
             final freshUser = AuthService().currentUser;
             
          
             if (freshUser != null && !freshUser.emailVerified) {
                Navigator.pushReplacement(
                  context, 
                  MaterialPageRoute(builder: (_) => const VerificationScreen())
                );
                return;
             }
             
             
             if (freshUser != null && freshUser.emailVerified) {
               AuthService().syncVerificationStatus();
             }

            if (role == 'admin') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const AdminDashboard()),
              );
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const DashboardScreen()),
              );
            }
          }
       } else {
          
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
