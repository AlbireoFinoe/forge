import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_session_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({
    required this.email,
    super.key,
  });

  final String email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const CircleAvatar(
            radius: 42,
            child: Icon(
              Icons.person,
              size: 42,
            ),
          ),
          const SizedBox(height: 16),

          Text(
            email,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),

          const SizedBox(height: 32),

          const Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.tune,
                  ),
                  title: Text(
                    'Training Preferences',
                  ),
                  subtitle: Text(
                    'Goals, schedule and equipment',
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                  ),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.sports_mma,
                  ),
                  title: Text(
                    'Sports Activities',
                  ),
                  subtitle: Text(
                    'Boxing, running and other sports',
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          OutlinedButton.icon(
            onPressed: () async {
              await ref
                  .read(
                    authSessionControllerProvider
                        .notifier,
                  )
                  .logout();
            },
            icon: const Icon(
              Icons.logout,
            ),
            label: const Padding(
              padding:
                  EdgeInsets.symmetric(
                vertical: 12,
              ),
              child: Text('Logout'),
            ),
          ),
        ],
      ),
    );
  }
}