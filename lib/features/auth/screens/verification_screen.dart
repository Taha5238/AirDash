import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'login_screen.dart';
import 'auth_check.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  bool _isSending = false;
  bool _isChecking = false;

  Future<void> _resendEmail() async {
    setState(() => _isSending = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.sendEmailVerification();
        if (mounted) {
           showDialog(
             context: context,
             builder: (ctx) => AlertDialog(
               title: const Text('Email Sent'),
               content: const Text('We have sent a verification email. \n\nPlease check your Inbox and SPAM folder.'),
               actions: [
                 TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))
               ],
             ),
           );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _checkVerification() async {
    setState(() => _isChecking = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.reload(); // Critical: Reloads user data from Firebase
        if (user.emailVerified) {
          if (mounted) {
             Navigator.of(context).pushReplacement(
               MaterialPageRoute(builder: (_) => const AuthCheck()),
             );
          }
        } else {
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text('Not verified yet. Please check your email.')),
             );
          }
        }
      }
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'your email';

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.mail, size: 80, color: Colors.blue),
            const SizedBox(height: 24),
            Text(
              'Verify your email',
              style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'We sent a verification link to:\n$email',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            Text(
              'Please click the link in the email to continue.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 48),
            
            // Check Status Button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isChecking ? null : _checkVerification,
                icon: _isChecking 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(LucideIcons.refreshCw),
                label: Text(_isChecking ? 'Checking...' : 'I have clicked the link'),
                style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
              ),
            ),
            
            const SizedBox(height: 16),

            // Resend Button
            TextButton(
              onPressed: _isSending ? null : _resendEmail,
              child: Text(_isSending ? 'Sending...' : 'Resend Email'),
            ),

            const SizedBox(height: 32),

            // Logout
            TextButton.icon(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
              icon: const Icon(LucideIcons.logOut, size: 16),
              label: const Text('Back to Login'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
        ),
      ),
    );
  }
}
