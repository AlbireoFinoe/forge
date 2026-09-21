import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/forge_theme.dart';
import 'features/auth/presentation/auth_gate.dart';

void main() {
  runApp(const ProviderScope(child: ForgeApp()));
}

class ForgeApp extends StatelessWidget {
  const ForgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FORGE',
      debugShowCheckedModeBanner: false,
      theme: ForgeTheme.dark,
      darkTheme: ForgeTheme.dark,
      themeMode: ThemeMode.dark,
      home: const AuthGate(),
    );
  }
}
