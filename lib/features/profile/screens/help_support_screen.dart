import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Help & Support', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Frequently Asked Questions',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const _FaqTile(
            question: 'How do I transfer files?',
            answer: 'To transfer files, go to your dashboard, select the file you want to share, and tap the share icon. You can then choose to share via link or standard share sheet.',
          ),
          const _FaqTile(
            question: 'Is my data secure?',
            answer: 'Yes, AirDash uses secure cloud storage to keep your files safe. Your personal information is also protected according to industry standards.',
          ),
          const _FaqTile(
            question: 'How do I verify my account?',
            answer: 'Go to Settings > Verify Account. If you are not verified, you will see a screen to resend the verification email. Check your inbox and click the link.',
          ),
          const _FaqTile(
            question: 'Can I use AirDash offline?',
            answer: 'AirDash is primarily a cloud-based service, but you can view files you have downloaded to your device offline.',
          ),
          
          const SizedBox(height: 32),
          Text(
            'Contact Us',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(LucideIcons.mail, size: 40, color: Colors.blue),
                const SizedBox(height: 12),
                Text(
                  'Need more help?',
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Email us at wasikamboh0810@gmail.com',
                  style: GoogleFonts.outfit(color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    Clipboard.setData(const ClipboardData(text: 'wasikamboh0810@gmail.com'));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Email copied to clipboard!')),
                    );
                  }, 
                  icon: const Icon(LucideIcons.copy, size: 16),
                  label: const Text('Copy Email'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final String question;
  final String answer;

  const _FaqTile({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Text(question, style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(answer, style: GoogleFonts.outfit(color: Colors.grey[600], height: 1.5)),
          ),
        ],
      ),
    );
  }
}
