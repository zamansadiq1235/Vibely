import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/utils/validators.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/social_sign_in_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authNotifierProvider.notifier)
        .signInWithEmail(email: _email.text.trim(), password: _password.text);
    if (!mounted) return;
    final result = ref.read(authNotifierProvider);
    if (result.hasError && mounted) {
      context.showSnack(result.error.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.play_circle_fill_rounded,
                  size: 56,
                  color: context.colors.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  AppConstants.appName,
                  style: context.textTheme.displayLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  AppConstants.appTagline,
                  style: context.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                AuthTextField(
                  controller: _email,
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.email,
                  autofillHints: const [AutofillHints.email],
                ),
                const SizedBox(height: 14),
                AuthTextField(
                  controller: _password,
                  label: 'Password',
                  obscureText: true,
                  validator: Validators.password,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push(RouteNames.forgotPassword),
                    child: const Text('Forgot password?'),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: isLoading ? null : _submit,
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Log In'),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('or', style: context.textTheme.labelSmall),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 20),
                SocialSignInButton(
                  label: 'Continue with Google',
                  icon: Icons.g_mobiledata_rounded,
                  onPressed: isLoading
                      ? null
                      : () => ref
                            .read(authNotifierProvider.notifier)
                            .signInWithGoogle(),
                ),
                const SizedBox(height: 12),
                SocialSignInButton(
                  label: 'Continue with Facebook',
                  icon: Icons.facebook_rounded,
                  onPressed: isLoading
                      ? null
                      : () => ref
                            .read(authNotifierProvider.notifier)
                            .signInWithFacebook(),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account?",
                      style: context.textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: () => context.push(RouteNames.signup),
                      child: const Text('Sign up'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
