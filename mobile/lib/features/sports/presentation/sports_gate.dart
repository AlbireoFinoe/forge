import 'package:flutter/material.dart';

import 'sports_setup_screen.dart';

class SportsGate extends StatelessWidget {
  const SportsGate({
    required this.configured,
    required this.onComplete,
    super.key,
  });

  final bool configured;
  final Widget onComplete;

  @override
  Widget build(BuildContext context) {
    if (configured) {
      return onComplete;
    }

    return const SportsSetupScreen();
  }
}
