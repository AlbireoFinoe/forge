import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_user.dart';
import '../../auth/presentation/auth_session_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({required this.user, super.key});

  final AuthUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FORGE'),
        actions: [
          IconButton(
            onPressed: () {
              ref.read(authSessionControllerProvider.notifier).logout();
            },
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome to FORGE',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Text(user.email),
            const SizedBox(height: 8),
            Text('Role: ${user.role}'),
          ],
        ),
      ),
    );
  }
}
