import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../auth/data/services/auth_service.dart';
import '../../../auth/presentation/pages/login_screen.dart';
import '../../../../core/theme/theme_controller.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final userName = authService.currentUserName;
    final userEmail = authService.currentUserEmail ?? 'No Email';

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // User Info
        Center(
          child: Column(
            children: [
              Hero(
                tag: 'profile_avatar',
                child: const CircleAvatar(
                  radius: 50,
                  backgroundImage: NetworkImage('https://i.pravatar.cc/300'),
                  child: Icon(LucideIcons.user, size: 40),
                ),
              ),
              const SizedBox(height: 16),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: Column(
                  children: [
                    Text(
                      userName,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      userEmail,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 48),

        // Storage Plan
        _buildAnimatedListItem(
          index: 0,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          LucideIcons.cloud,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Text(
                          'Free Plan',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {},
                        child: const Text('Upgrade'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: 0.75,
                      minHeight: 8,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '45.5 GB used',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '100 GB total',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 32),

        _buildAnimatedListItem(
          index: 1,
          child: const ListTile(
            leading: Icon(LucideIcons.settings),
            title: Text('Settings'),
            trailing: Icon(LucideIcons.chevronRight, size: 20),
          ),
        ),
        _buildAnimatedListItem(
          index: 2,
          child: const ListTile(
            leading: Icon(LucideIcons.lock),
            title: Text('Security'),
            trailing: Icon(LucideIcons.chevronRight, size: 20),
          ),
        ),
        _buildAnimatedListItem(
          index: 3,
          child: ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeController().themeMode,
            builder: (context, themeMode, _) {
              final isDark = themeMode == ThemeMode.dark;
              return ListTile(
                leading: Icon(isDark ? LucideIcons.moon : LucideIcons.sun),
                title: const Text('Dark Mode'),
                trailing: Switch(
                  value: isDark,
                  onChanged: (val) {
                    ThemeController().toggleTheme();
                  },
                ),
              );
            },
          ),
        ),
        const Divider(),
        _buildAnimatedListItem(
          index: 4,
          child: ListTile(
            leading: Icon(
              LucideIcons.logOut,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Log Out',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () async {
              await authService.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedListItem({required int index, required Widget child}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 100)),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
