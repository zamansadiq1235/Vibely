import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/validators.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_text_field.dart';

/// Note: the profile picture picked here is uploaded in the Complete
/// Profile step (Phase 4), once the user has a session and an
/// authenticated Storage client — signUp() alone doesn't yet grant an
/// active session if email confirmation is required.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _username = TextEditingController();
  final _fullName = TextEditingController();
  XFile? _pickedAvatar;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _username.dispose();
    _fullName.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (file != null && mounted) setState(() => _pickedAvatar = file);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authNotifierProvider.notifier)
        .signUpWithEmail(
          email: _email.text.trim(),
          password: _password.text,
          username: _username.text.trim(),
          fullName: _fullName.text.trim(),
        );
    if (!mounted) return;
    final result = ref.read(authNotifierProvider);
    if (result.hasError && mounted) {
      context.showSnack(result.error.toString(), isError: true);
      return;
    }
    if (mounted) {
      context.showSnack('Check your email to verify your account.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _pickAvatar,
                    child: CircleAvatar(
                      radius: 44,
                      backgroundColor: context.colors.surfaceContainerHighest,
                      backgroundImage: _pickedAvatar != null
                          ? FileImage(File(_pickedAvatar!.path))
                          : null,
                      child: _pickedAvatar == null
                          ? Icon(
                              Icons.add_a_photo_rounded,
                              color: context.colors.onSurfaceVariant,
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                AuthTextField(
                  controller: _fullName,
                  label: 'Full name',
                  validator: (v) => Validators.required(v, field: 'Full name'),
                ),
                const SizedBox(height: 14),
                AuthTextField(
                  controller: _username,
                  label: 'Username',
                  validator: Validators.username,
                ),
                const SizedBox(height: 14),
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
                  autofillHints: const [AutofillHints.newPassword],
                ),
                const SizedBox(height: 24),
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
                      : const Text('Sign Up'),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('Already have an account? Log in'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
