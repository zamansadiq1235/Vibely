import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/validators.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_text_field.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _isSubmitting = false;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(authNotifierProvider.notifier)
          .sendPasswordResetEmail(_email.text.trim());
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) context.showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _sent ? _buildSentState(context) : _buildForm(context),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Enter the email on your account and we'll send you a link to reset your password.",
            style: context.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          AuthTextField(
            controller: _email,
            label: 'Email',
            keyboardType: TextInputType.emailAddress,
            validator: Validators.email,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Send reset link'),
          ),
        ],
      ),
    );
  }

  Widget _buildSentState(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.mark_email_read_rounded,
          size: 56,
          color: context.colors.primary,
        ),
        const SizedBox(height: 16),
        Text('Check your inbox', style: context.textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'We sent a password reset link to ${_email.text.trim()}.',
          textAlign: TextAlign.center,
          style: context.textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        TextButton(
          onPressed: () => context.pop(),
          child: const Text('Back to login'),
        ),
      ],
    );
  }
}
