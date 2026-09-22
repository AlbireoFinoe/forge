import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/forge_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/auth_user.dart';
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
      appBar: AppBar(title: const Text('PROFILE')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          ForgeSpacing.xl,
          ForgeSpacing.lg,
          ForgeSpacing.xl,
          ForgeSpacing.xxl + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Text(
            'PROFILE',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 0.4),
          ),

          const SizedBox(height: 6),

          Text(
            'Manage your FORGE account.',
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: ForgeColors.textSecondary),
          ),

          const SizedBox(height: ForgeSpacing.xl),

          _IdentityCard(
            displayName: displayName,
            initial: initial,
            email: user.email,
            onEdit: () {
              _editFullName(context, ref);
            },
          ),

          const SizedBox(height: ForgeSpacing.xxl),

          const _SectionLabel(label: 'TRAINING'),

          const SizedBox(height: ForgeSpacing.md),

          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.tune_rounded,
                title: 'Training Preferences',
                subtitle: 'Goals, schedule and equipment',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) {
                        return const TrainingSetupScreen();
                      },
                    ),
                  );
                },
              ),
              const _SettingsDivider(),
              _SettingsTile(
                icon: Icons.sports_mma_rounded,
                title: 'Sports Activities',
                subtitle: 'Boxing, running and other sports',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) {
                        return const SportsSetupScreen(settingsMode: true);
                      },
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: ForgeSpacing.xxl),

          const _SectionLabel(label: 'ACCOUNT'),

          const SizedBox(height: ForgeSpacing.md),

          _LogoutCard(
            onLogout: () async {
              await ref.read(authSessionControllerProvider.notifier).logout();
            },
          ),
        ],
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.displayName,
    required this.initial,
    required this.email,
    required this.onEdit,
  });

  final String? displayName;
  final String? initial;
  final String email;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final avatarInitial = initial;

    return Container(
      padding: const EdgeInsets.all(ForgeSpacing.xl),
      decoration: BoxDecoration(
        color: ForgeColors.surfaceRaised,
        borderRadius: BorderRadius.circular(ForgeRadius.lg),
        border: Border.all(color: ForgeColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ForgeColors.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
              border: Border.all(
                color: ForgeColors.primary.withValues(alpha: 0.22),
              ),
            ),
            child: avatarInitial == null
                ? const Icon(
                    Icons.person_rounded,
                    size: 30,
                    color: ForgeColors.primary,
                  )
                : Text(
                    avatarInitial,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: ForgeColors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),

          const SizedBox(width: ForgeSpacing.lg),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName ?? 'Set your name',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),

                const SizedBox(height: 4),

                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: ForgeColors.textSecondary),
                ),

                const SizedBox(height: ForgeSpacing.md),

                GestureDetector(
                  onTap: onEdit,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.edit_rounded,
                        size: 16,
                        color: ForgeColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'EDIT PROFILE',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: ForgeColors.primary,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.8),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ForgeColors.surface,
        borderRadius: BorderRadius.circular(ForgeRadius.lg),
        border: Border.all(color: ForgeColors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(ForgeSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ForgeColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(ForgeRadius.md),
                ),
                child: Icon(icon, size: 22, color: ForgeColors.primary),
              ),

              const SizedBox(width: ForgeSpacing.md),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: ForgeColors.textSecondary),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              const Icon(
                Icons.chevron_right_rounded,
                color: ForgeColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 72);
  }
}

class _LogoutCard extends StatelessWidget {
  const _LogoutCard({required this.onLogout});

  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ForgeSpacing.lg),
      decoration: BoxDecoration(
        color: ForgeColors.surface,
        borderRadius: BorderRadius.circular(ForgeRadius.lg),
        border: Border.all(color: ForgeColors.outline),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ForgeColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(ForgeRadius.md),
            ),
            child: const Icon(
              Icons.logout_rounded,
              color: ForgeColors.error,
              size: 21,
            ),
          ),

          const SizedBox(width: ForgeSpacing.md),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Log out',
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  'Sign out of this device',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: ForgeColors.textSecondary),
                ),
              ],
            ),
          ),

          TextButton(
            onPressed: () {
              onLogout();
            },
            style: TextButton.styleFrom(foregroundColor: ForgeColors.error),
            child: const Text('LOG OUT'),
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
