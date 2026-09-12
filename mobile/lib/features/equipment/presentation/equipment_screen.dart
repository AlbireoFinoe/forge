import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/equipment_models.dart';
import '../data/equipment_repository.dart';
import 'equipment_controller.dart';

enum _EquipmentMode { fullGym, custom }

class EquipmentScreen extends ConsumerStatefulWidget {
  const EquipmentScreen({required this.data, super.key});

  final EquipmentSelectionData data;

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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'What equipment do you have?',
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose the setup that best matches where you train.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 32),

                  _EquipmentModeCard(
                    title: 'Full Gym',
                    description: 'Choose this if you have access to a fully equipped gym with machines, free weights, cables, benches, and other common equipment.',
                    icon: Icons.fitness_center,
                    selected: _mode == _EquipmentMode.fullGym,
                    enabled: !_isSubmitting,
                    onTap: () {
                      _selectMode(_EquipmentMode.fullGym);
                    },
                  ),

                  const SizedBox(height: 16),

                  _EquipmentModeCard(
                    title: 'Custom Equipment',
                    description: 'Choose this if you only have access to specific equipment at home or at a limited gym.',
                    icon: Icons.tune,
                    selected: _mode == _EquipmentMode.custom,
                    enabled: !_isSubmitting,
                    onTap: () {
                      _selectMode(_EquipmentMode.custom);
                    },
                  ),

                  if (_mode == _EquipmentMode.custom) ...[
                    const SizedBox(height: 32),

                    Text(
                      'Select your equipment',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _customSelectedCodes.isEmpty
                          ? 'Select at least one item.'
                          : '${_customSelectedCodes.length} selected',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),

                    const SizedBox(height: 16),

                    for (final equipment in customEquipment)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _EquipmentTile(
                          equipment: equipment,
                          selected: _customSelectedCodes.contains(
                            equipment.code,
                          ),
                          enabled: !_isSubmitting,
                          onChanged: (selected) {
                            _toggleCustomEquipment(equipment, selected);
                          },
                        ),
                      ),
                  ],

                  const SizedBox(height: 32),

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
                          : const Text('Continue'),
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
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: selected
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 28,
                color: selected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
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
    return Card(
      margin: EdgeInsets.zero,
      child: CheckboxListTile(
        value: selected,
        onChanged: enabled
            ? (value) {
                onChanged(value ?? false);
              }
            : null,
        title: Text(equipment.name),
        secondary: const Icon(Icons.fitness_center),
        controlAffinity: ListTileControlAffinity.trailing,
      ),
    );
  }
}
