import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'muscle_priority_controller.dart';
import 'muscle_priority_screen.dart';

class MusclePriorityGate extends ConsumerWidget {
  const MusclePriorityGate({required this.onComplete, super.key});

  final Widget onComplete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muscles = ref.watch(musclePriorityControllerProvider);

    return muscles.when(
      loading: () {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
      error: (error, stackTrace) {
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, size: 48),
                  const SizedBox(height: 16),
                  const Text('Could not load your muscle priorities.'),
                  const SizedBox(height: 8),
                  Text(error.toString(), textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {
                      ref
                          .read(musclePriorityControllerProvider.notifier)
                          .refresh();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      data: (data) {
        if (!data.isConfigured) {
          return MusclePriorityScreen(data: data);
        }

        return onComplete;
      },
    );
  }
}
