import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UpgradeScreen extends StatelessWidget {
  const UpgradeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Upgrade Plan', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(LucideIcons.crown, size: 64, color: Colors.amber),
            const SizedBox(height: 16),
            Text(
              'Unlock Full Potential',
              style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Get unlimited storage and priority support.',
              style: GoogleFonts.outfit(color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            
            // Free Tier Card
            _buildPlanCard(
              context,
              title: 'Free Plan',
              price: 'Current',
              features: ['5 GB Cloud Storage', 'Standard Support', 'Ad-supported'],
              isPro: false,
            ),
            
            const SizedBox(height: 16),

            // Pro Tier Card
            _buildPlanCard(
              context,
              title: 'Pro Plan',
              price: '\$9.99 / mo',
              features: ['Unlimited Cloud Storage', 'Priority Support', 'No Ads', 'Early Access Features'],
              isPro: true,
              onTap: () => _contactAdmin(context),
            ),
             
             const SizedBox(height: 32),
             Text(
               'To upgrade, please contact our admin support directly.',
               style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
               textAlign: TextAlign.center,
             ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(BuildContext context, {required String title, required String price, required List<String> features, required bool isPro, VoidCallback? onTap}) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isPro ? Colors.black : colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
        border: isPro ? Border.all(color: Colors.amber, width: 2) : null,
        boxShadow: isPro ? [
          BoxShadow(color: Colors.amber.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))
        ] : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 20, 
                  fontWeight: FontWeight.bold,
                  color: isPro ? Colors.white : colorScheme.onSurface,
                ),
              ),
              if (isPro)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(8)),
                  child: Text('RECOMMENDED', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            price,
            style: GoogleFonts.outfit(
              fontSize: 32, 
              fontWeight: FontWeight.bold,
              color: isPro ? Colors.white : colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 24),
          ...features.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(LucideIcons.checkCircle, size: 18, color: isPro ? Colors.greenAccent : Colors.grey),
                const SizedBox(width: 12),
                Text(
                  f, 
                  style: GoogleFonts.outfit(
                    color: isPro ? Colors.white.withOpacity(0.9) : colorScheme.onSurface.withOpacity(0.8)
                  )
                ),
              ],
            ),
          )),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: isPro ? Colors.amber : Colors.grey[300],
                foregroundColor: isPro ? Colors.black : Colors.grey[600],
                padding: const EdgeInsets.all(16),
              ),
              child: Text(isPro ? 'Contact to Upgrade' : 'Your Current Plan', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _contactAdmin(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    final String subject = Uri.encodeComponent("Upgrade Request: ${user?.email ?? 'User'}");
    final String body = Uri.encodeComponent("I would like to upgrade my account to the Pro Plan.\n\nUser ID: ${user?.uid}\nEmail: ${user?.email}");
    final Uri emailLaunchUri = Uri.parse("mailto:wasikamboh0810@gmail.com?subject=$subject&body=$body");

    try {
      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri);
      } else {
         // Fallback/Error
         if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Could not launch email app. Please email wasikamboh0810@gmail.com')),
           );
         }
      }
    } catch (e) {
       if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Error: $e')),
           );
       }
    }
  }
}
