import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Privacy Policy', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy Policy',
              style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Last updated: December 2025',
              style: GoogleFonts.outfit(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            _buildSection(
              '1. Introduction',
              'Welcome to AirDash ("we," "our," or "us"). We are committed to protecting your personal information and your right to privacy. This Privacy Policy describes how we collect, use, and share your information when you use our mobile application.',
            ),
            _buildSection(
              '2. Information We Collect',
              'We collect personal information that you provide to us, such as name, email address, and profile picture. We also store the files you explicitly upload to our service.',
            ),
            _buildSection(
              '3. How We Use Your Information',
              'We use your information to provide, improve, and administer our Services, communicate with you, for security and fraud prevention, and to comply with law. We do not sell your personal data to third parties.',
            ),
            _buildSection(
              '4. Data Security',
              'We have implemented appropriate technical and organizational security measures designed to protect the security of any personal information we process. However, please also remember that we cannot guarantee that the internet itself is 100% secure.',
            ),
            _buildSection(
              '5. Contact Us',
              'If you have questions or comments about this policy, you may email us at wasikamboh0810@gmail.com.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: GoogleFonts.outfit(fontSize: 15, height: 1.6, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }
}
