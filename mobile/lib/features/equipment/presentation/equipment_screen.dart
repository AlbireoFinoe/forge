import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/forge_theme.dart';
import '../../../core/widgets/forge_onboarding_progress.dart';

import '../data/equipment_models.dart';
import '../data/equipment_repository.dart';
import 'equipment_controller.dart';

enum _EquipmentMode { fullGym, custom }

class EquipmentScreen extends ConsumerStatefulWidget {
  const EquipmentScreen({
    required this.data,
    this.settingsMode = false,
    super.key,
  });

  final EquipmentSelectionData data;
  final bool settingsMode;

  @override
  ConsumerState<EquipmentScreen> createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends ConsumerState<EquipmentScreen> {
  late final Set<String> _customSelectedCodes;

  _EquipmentMode? _mode;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();

    _customSelectedCodes = {
      for (final code in widget.data.selectedCodes)
        if (code != 'FULL_GYM') code,
    };

    if (widget.data.selectedCodes.contains('FULL_GYM')) {
      _mode = _EquipmentMode.fullGym;
    } else if (_customSelectedCodes.isNotEmpty) {
      _mode = _EquipmentMode.custom;
    }
  }

  void _selectMode(_EquipmentMode mode) {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _mode = mode;
    });
  }

  void _toggleCustomEquipment(EquipmentData equipment, bool selected) {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      if (selected) {
        _customSelectedCodes.add(equipment.code);
      } else {
        _customSelectedCodes.remove(equipment.code);
      }
    });
  }

  bool get _canContinue {
    if (_isSubmitting) {
      return false;
    }

    if (_mode == _EquipmentMode.fullGym) {
      return true;
    }

    if (_mode == _EquipmentMode.custom) {
      return _customSelectedCodes.isNotEmpty;
    }

    return false;
  }

  Set<String> get _selectionToSave {
    if (_mode == _EquipmentMode.fullGym) {
      return {'FULL_GYM'};
    }

    if (_mode == _EquipmentMode.custom) {
      return {..._customSelectedCodes};
    }

    return {};
  }

  Future<void> _continue() async {
    if (!_canContinue) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await ref
          .read(equipmentControllerProvider.notifier)
          .saveSelection(_selectionToSave);

      if (widget.settingsMode && mounted) {
        Navigator.of(context).pop(true);
      }
    } on EquipmentException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong while saving your equipment.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customEquipment = widget.data.catalog
        .where((equipment) => !equipment.isFullGym)
        .toList(growable: false);

    return Scaffold(
      appBar: widget.settingsMode
          ? AppBar(title: const Text('EQUIPMENT'))
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            ForgeSpacing.xl,
            ForgeSpacing.lg,
            ForgeSpacing.xl,
            ForgeSpacing.xxl + MediaQuery.paddingOf(context).bottom,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!widget.settingsMode) ...[
                    const ForgeOnboardingProgress(currentStep: 5),
                    const SizedBox(height: ForgeSpacing.xxl),
                  ],

                  Text(
                    'TRAINING EQUIPMENT',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'Tell FORGE what equipment '
                    'you actually have access to.',
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(color: ForgeColors.textSecondary),
                  ),

                  const SizedBox(height: ForgeSpacing.xl),

                  Text(
                    'TRAINING ENVIRONMENT',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),

                  const SizedBox(height: ForgeSpacing.md),

                  _EquipmentModeCard(
                    title: 'Full Gym',
                    description: 'Access to machines, free weights, cables, benches and standard gym equipment.',
                    icon: Icons.fitness_center_rounded,
                    selected: _mode == _EquipmentMode.fullGym,
                    enabled: !_isSubmitting,
                    onTap: () {
                      _selectMode(_EquipmentMode.fullGym);
                    },
                  ),

                  const SizedBox(height: ForgeSpacing.md),

                  _EquipmentModeCard(
                    title: 'Custom Equipment',
                    description: 'Choose exactly which equipment is available at home or in a limited gym.',
                    icon: Icons.tune_rounded,
                    selected: _mode == _EquipmentMode.custom,
                    enabled: !_isSubmitting,
                    onTap: () {
                      _selectMode(_EquipmentMode.custom);
                    },
                  ),

                  if (_mode == _EquipmentMode.custom) ...[
                    const SizedBox(height: ForgeSpacing.xxl),

                    Row(
                      children: [
                        Text(
                          'AVAILABLE EQUIPMENT',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                        ),

                        const Spacer(),

                        Text(
                          '${_customSelectedCodes.length} SELECTED',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: ForgeColors.textMuted,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),

                    const SizedBox(height: ForgeSpacing.md),

                    if (_customSelectedCodes.isEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(ForgeSpacing.md),
                        decoration: BoxDecoration(
                          color: ForgeColors.warning.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(ForgeRadius.md),
                          border: Border.all(
                            color: ForgeColors.warning.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              size: 18,
                              color: ForgeColors.warning,
                            ),
                            const SizedBox(width: ForgeSpacing.sm),
                            Expanded(
                              child: Text(
                                'Select at least one '
                                'equipment item.',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: ForgeColors.textSecondary,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: ForgeSpacing.md),
                    ],

                    for (
                      var index = 0;
                      index < customEquipment.length;
                      index++
                    ) ...[
                      _EquipmentTile(
                        equipment: customEquipment[index],
                        selected: _customSelectedCodes.contains(
                          customEquipment[index].code,
                        ),
                        enabled: !_isSubmitting,
                        onChanged: (selected) {
                          _toggleCustomEquipment(
                            customEquipment[index],
                            selected,
                          );
                        },
                      ),

                      if (index < customEquipment.length - 1)
                        const SizedBox(height: ForgeSpacing.sm),
                    ],
                  ],

                  const SizedBox(height: ForgeSpacing.xxl),

                  FilledButton(
                    onPressed: _canContinue ? _continue : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              widget.settingsMode ? 'SAVE CHANGES' : 'CONTINUE',
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EquipmentModeCard extends StatelessWidget {
  const _EquipmentModeCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? ForgeColors.primary.withValues(alpha: 0.06)
          : ForgeColors.surface,
      borderRadius: BorderRadius.circular(ForgeRadius.lg),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(ForgeRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(ForgeSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ForgeRadius.lg),
            border: Border.all(
              color: selected ? ForgeColors.primary : ForgeColors.outline,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? ForgeColors.primary.withValues(alpha: 0.12)
                      : ForgeColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(ForgeRadius.md),
                ),
                child: Icon(
                  icon,
                  size: 23,
                  color: selected
                      ? ForgeColors.primary
                      : ForgeColors.textSecondary,
                ),
              ),

              const SizedBox(width: ForgeSpacing.md),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),

                        if (selected)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: ForgeColors.primary.withValues(
                                alpha: 0.10,
                              ),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              'SELECTED',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: ForgeColors.primary,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 9,
                                  ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ForgeColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? ForgeColors.primary : ForgeColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EquipmentTile extends StatelessWidget {
  const _EquipmentTile({
    required this.equipment,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final EquipmentData equipment;
  final bool selected;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: selected
            ? ForgeColors.primary.withValues(alpha: 0.04)
            : ForgeColors.surface,
        borderRadius: BorderRadius.circular(ForgeRadius.md),
        border: Border.all(
          color: selected
              ? ForgeColors.primary.withValues(alpha: 0.35)
              : ForgeColors.outline,
        ),
      ),
      child: CheckboxListTile(
        value: selected,
        onChanged: enabled
            ? (value) {
                onChanged(value ?? false);
              }
            : null,
        activeColor: ForgeColors.primary,
        checkColor: Colors.black,
        title: Text(
          equipment.name,
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        secondary: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: ForgeColors.surfaceRaised,
            borderRadius: BorderRadius.circular(ForgeRadius.sm),
          ),
          child: Icon(
            Icons.fitness_center_rounded,
            size: 20,
            color: selected ? ForgeColors.primary : ForgeColors.textSecondary,
          ),
        ),
        controlAffinity: ListTileControlAffinity.trailing,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: ForgeSpacing.md,
          vertical: 4,
        ),
      ),
    );
  }
}
