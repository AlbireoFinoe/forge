import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/forge_theme.dart';

import '../data/auth_repository.dart';
import 'auth_session_controller.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({this.notice, super.key});

  final String? notice;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();

  final _passwordController = TextEditingController();

  bool _isSubmitting = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await ref
          .read(authSessionControllerProvider.notifier)
          .login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
    } on AuthException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Something went wrong.')));
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
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            ForgeSpacing.xl,
            ForgeSpacing.xl,
            ForgeSpacing.xl,
            ForgeSpacing.xxl +
                MediaQuery.paddingOf(context).bottom,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 440,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),

                    const _ForgeAuthBrand(),

                    const SizedBox(
                      height: ForgeSpacing.xxl,
                    ),

                    Text(
                      'WELCOME BACK',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                            fontWeight:
                                FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      'Sign in to continue your '
                      'training.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(
                            color: ForgeColors
                                .textSecondary,
                          ),
                    ),

                    if (widget.notice != null) ...[
                      const SizedBox(
                        height: ForgeSpacing.xl,
                      ),

                      Container(
                        padding: const EdgeInsets.all(
                          ForgeSpacing.lg,
                        ),
                        decoration: BoxDecoration(
                          color: ForgeColors.warning
                              .withValues(
                            alpha: 0.07,
                          ),
                          borderRadius:
                              BorderRadius.circular(
                            ForgeRadius.md,
                          ),
                          border: Border.all(
                            color: ForgeColors.warning
                                .withValues(
                              alpha: 0.20,
                            ),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons
                                  .info_outline_rounded,
                              color:
                                  ForgeColors.warning,
                              size: 20,
                            ),

                            const SizedBox(
                              width:
                                  ForgeSpacing.md,
                            ),

                            Expanded(
                              child: Text(
                                widget.notice!,
                                style:
                                    Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color:
                                              ForgeColors
                                                  .textSecondary,
                                          height: 1.4,
                                        ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(
                      height: ForgeSpacing.xl,
                    ),

                    TextFormField(
                      controller: _emailController,
                      keyboardType:
                          TextInputType.emailAddress,
                      textInputAction:
                          TextInputAction.next,
                      autofillHints: const [
                        AutofillHints.email,
                      ],
                      decoration:
                          const InputDecoration(
                        labelText: 'Email',
                        hintText:
                            'you@example.com',
                        prefixIcon: Icon(
                          Icons
                              .mail_outline_rounded,
                        ),
                      ),
                      validator: (value) {
                        final email =
                            value?.trim() ?? '';

                        if (email.isEmpty) {
                          return 'Email is required.';
                        }

                        if (!email.contains('@')) {
                          return 'Enter a valid email.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(
                      height: ForgeSpacing.lg,
                    ),

                    TextFormField(
                      controller:
                          _passwordController,
                      obscureText:
                          _obscurePassword,
                      textInputAction:
                          TextInputAction.done,
                      autofillHints: const [
                        AutofillHints.password,
                      ],
                      onFieldSubmitted: (_) {
                        if (!_isSubmitting) {
                          _submit();
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(
                          Icons.lock_outline_rounded,
                        ),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _obscurePassword =
                                  !_obscurePassword;
                            });
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons
                                    .visibility_outlined
                                : Icons
                                    .visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (
                          value == null ||
                          value.isEmpty
                        ) {
                          return 'Password is required.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(
                      height: ForgeSpacing.xl,
                    ),

                    FilledButton(
                      onPressed: _isSubmitting
                          ? null
                          : _submit,
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'SIGN IN',
                              ),
                      ),
                    ),

                    const SizedBox(
                      height: ForgeSpacing.xl,
                    ),

                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Text(
                          'New to FORGE?',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: ForgeColors
                                    .textSecondary,
                              ),
                        ),

                        const SizedBox(width: 4),

                        TextButton(
                          onPressed: _isSubmitting
                              ? null
                              : () {
                                  Navigator.of(
                                    context,
                                  ).push(
                                    MaterialPageRoute<
                                        void>(
                                      builder: (_) {
                                        return const RegisterScreen();
                                      },
                                    ),
                                  );
                                },
                          child: const Text(
                            'CREATE ACCOUNT',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

}


class _ForgeAuthBrand
    extends StatelessWidget {
  const _ForgeAuthBrand();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ForgeColors.primary,
                borderRadius:
                    BorderRadius.circular(
                  ForgeRadius.md,
                ),
              ),
              child: const Icon(
                Icons.fitness_center_rounded,
                color: Colors.black,
                size: 25,
              ),
            ),

            const SizedBox(
              width: ForgeSpacing.md,
            ),

            Text(
              'FORGE',
              style: Theme.of(context)
                  .textTheme
                  .displaySmall
                  ?.copyWith(
                    fontWeight:
                        FontWeight.w900,
                    letterSpacing: -1,
                  ),
            ),
          ],
        ),

        const SizedBox(
          height: ForgeSpacing.md,
        ),

        Text(
          'ADAPTIVE TRAINING PLANNER',
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(
                color: ForgeColors.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
        ),

        const SizedBox(height: 5),

        Text(
          'BUILD. TRAIN. ADAPT.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(
                color:
                    ForgeColors.textMuted,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
        ),
      ],
    );
  }
}

