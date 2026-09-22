import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/forge_theme.dart';

import '../data/auth_repository.dart';
import 'auth_session_controller.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

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
          .registerAndLogin(
            fullName: _nameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
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
      appBar: AppBar(
        title: const Text(
          'CREATE ACCOUNT',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            ForgeSpacing.xl,
            ForgeSpacing.lg,
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
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: ForgeColors.primary
                            .withValues(
                          alpha: 0.10,
                        ),
                        borderRadius:
                            BorderRadius.circular(
                          ForgeRadius.lg,
                        ),
                      ),
                      child: const Icon(
                        Icons
                            .person_add_alt_1_rounded,
                        color:
                            ForgeColors.primary,
                        size: 27,
                      ),
                    ),

                    const SizedBox(
                      height: ForgeSpacing.xl,
                    ),

                    Text(
                      'JOIN FORGE',
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
                      'Create your account and '
                      'build a training plan around '
                      'your goals, schedule and '
                      'recovery.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(
                            color: ForgeColors
                                .textSecondary,
                            height: 1.4,
                          ),
                    ),

                    const SizedBox(
                      height: ForgeSpacing.xl,
                    ),

                    TextFormField(
                      controller:
                          _nameController,
                      keyboardType:
                          TextInputType.name,
                      textCapitalization:
                          TextCapitalization.words,
                      textInputAction:
                          TextInputAction.next,
                      autofillHints: const [
                        AutofillHints.name,
                      ],
                      decoration:
                          const InputDecoration(
                        labelText: 'Full Name',
                        hintText:
                            'e.g. Albireo Musyaffa Finoe',
                        prefixIcon: Icon(
                          Icons
                              .person_outline_rounded,
                        ),
                      ),
                      validator: (value) {
                        final name =
                            value?.trim() ?? '';

                        if (name.isEmpty) {
                          return 'Name is required.';
                        }

                        final normalized = name
                            .split(
                              RegExp(r'\s+'),
                            )
                            .where(
                              (part) =>
                                  part.isNotEmpty,
                            )
                            .join(' ');

                        if (
                          normalized.length < 2
                        ) {
                          return 'Name must contain at least 2 characters.';
                        }

                        if (
                          normalized.length > 120
                        ) {
                          return 'Name must not exceed 120 characters.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(
                      height: ForgeSpacing.lg,
                    ),

                    TextFormField(
                      controller:
                          _emailController,
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
                          TextInputAction.next,
                      autofillHints: const [
                        AutofillHints.newPassword,
                      ],
                      decoration: InputDecoration(
                        labelText: 'Password',
                        helperText:
                            'Minimum 8 characters',
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

                        if (value.length < 8) {
                          return 'Password must contain at least 8 characters.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(
                      height: ForgeSpacing.lg,
                    ),

                    TextFormField(
                      controller:
                          _confirmPasswordController,
                      obscureText:
                          _obscureConfirmPassword,
                      textInputAction:
                          TextInputAction.done,
                      autofillHints: const [
                        AutofillHints.newPassword,
                      ],
                      onFieldSubmitted: (_) {
                        if (!_isSubmitting) {
                          _submit();
                        }
                      },
                      decoration: InputDecoration(
                        labelText:
                            'Confirm Password',
                        prefixIcon: const Icon(
                          Icons
                              .lock_reset_rounded,
                        ),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword;
                            });
                          },
                          icon: Icon(
                            _obscureConfirmPassword
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
                          return 'Confirm your password.';
                        }

                        if (
                          value !=
                              _passwordController
                                  .text
                        ) {
                          return 'Passwords do not match.';
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
                                'CREATE ACCOUNT',
                              ),
                      ),
                    ),

                    const SizedBox(
                      height: ForgeSpacing.lg,
                    ),

                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account?',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
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
                                  ).pop();
                                },
                          child: const Text(
                            'SIGN IN',
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
