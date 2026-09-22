import 'package:flutter/material.dart';

import '../theme/forge_theme.dart';

class ForgeOnboardingProgress extends StatelessWidget {
  const ForgeOnboardingProgress({
    required this.currentStep,
    this.totalSteps = 6,
    super.key,
  }) : assert(currentStep > 0),
       assert(totalSteps > 0),
       assert(currentStep <= totalSteps);

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'FORGE setup progress',
      value: 'Step $currentStep of $totalSteps',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'SET UP FORGE',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: ForgeColors.textSecondary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9,
                ),
              ),
              const Spacer(),
              Text(
                '$currentStep OF $totalSteps',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: ForgeColors.primary,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.7,
                ),
              ),
            ],
          ),
          const SizedBox(height: ForgeSpacing.md),
          Row(
            children: [
              for (var index = 0; index < totalSteps; index++) ...[
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    height: 4,
                    decoration: BoxDecoration(
                      color: index < currentStep
                          ? ForgeColors.primary
                          : ForgeColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                if (index < totalSteps - 1)
                  const SizedBox(width: ForgeSpacing.xs),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
