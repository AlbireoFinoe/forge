import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_user.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/auth_session_controller.dart';
import '../../sports/presentation/sports_setup_screen.dart';
import 'training_setup_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({required this.user, super.key});

  final AuthUser user;

  String? get _displayName {
    final value = user.fullName?.trim();

    if (value == null || value.isEmpty) {
      return null;
    }

    return value;
  }

  String? get _initial {
    final name = _displayName;

    if (name == null || name.isEmpty) {
      return null;
    }

    return name.substring(0, 1).toUpperCase();
  }

  Future<void> _editFullName(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return _EditNameDialog(initialName: _displayName ?? '');
      },
    );

    if (result == null || !context.mounted) {
      return;
    }

    try {
      await ref
          .read(authSessionControllerProvider.notifier)
          .updateFullName(result);

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name updated successfully.')),
      );
    } on AuthException catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayName = _displayName;
    final initial = _initial;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: CircleAvatar(
              radius: 42,
              child: initial == null
                  ? const Icon(Icons.person, size: 42)
                  : Text(
                      initial,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
            ),
          ),

          const SizedBox(height: 16),

          Text(
            displayName ?? 'Set your name',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),

          const SizedBox(height: 4),

          Text(
            user.email,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),

          const SizedBox(height: 32),

          Card(
            child: ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: const Text('Full Name'),
              subtitle: Text(displayName ?? 'Add your account name'),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () {
                _editFullName(context, ref);
              },
            ),
          ),

          const SizedBox(height: 16),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.tune),
                  title: const Text('Training Preferences'),
                  subtitle: const Text('Goals, schedule and equipment'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) {
                          return const TrainingSetupScreen();
                        },
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.sports_mma),
                  title: const Text('Sports Activities'),
                  subtitle: const Text('Boxing, running and other sports'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) {
                          return const SportsSetupScreen(settingsMode: true);
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(authSessionControllerProvider.notifier).logout();
            },
            icon: const Icon(Icons.logout),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Logout'),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditNameDialog extends StatefulWidget {
  const _EditNameDialog({required this.initialName});

  final String initialName;

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }

  String _normalizedName() {
    return _controller.text
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .join(' ');
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    FocusScope.of(context).unfocus();

    Navigator.of(context).pop(_normalizedName());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit name'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          keyboardType: TextInputType.name,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.name],
          decoration: const InputDecoration(
            labelText: 'Full Name',
            hintText: 'e.g. Albireo Musyaffa Finoe',
          ),
          onFieldSubmitted: (_) {
            _submit();
          },
          validator: (value) {
            final normalized = (value ?? '')
                .trim()
                .split(RegExp(r'\s+'))
                .where((part) => part.isNotEmpty)
                .join(' ');

            if (normalized.isEmpty) {
              return 'Name is required.';
            }

            if (normalized.length < 2) {
              return 'Name must contain at least 2 characters.';
            }

            if (normalized.length > 120) {
              return 'Name must not exceed 120 characters.';
            }

            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            FocusScope.of(context).unfocus();

            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
