import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/services/avatar_upload_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_text_field.dart';

/// Shown when AuthStatus is needsProfileCompletion — see the router
/// redirect logic wired up below in this same phase. Once submitted,
/// authNotifierProvider re-resolves state, the redirect sees
/// AuthStatus.authenticated, and go_router pushes the user to Home.
class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullName;
  final _bio = TextEditingController();
  XFile? _pickedAvatar;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final existing = ref.read(authNotifierProvider).asData?.value.profile;
    _fullName = TextEditingController(text: existing?.fullName ?? '');
    _bio.text = existing?.bio ?? '';
  }

  @override
  void dispose() {
    _fullName.dispose();
    _bio.dispose();
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
    final userId = ref.read(authRepositoryProvider).currentUserId;
    if (userId == null) return;

    setState(() => _isSubmitting = true);
    try {
      String? avatarPath;
      if (_pickedAvatar != null) {
        avatarPath = await ref
            .read(avatarUploadServiceProvider)
            .uploadAvatar(userId: userId, file: File(_pickedAvatar!.path));
        if (!mounted) return;
      }
      await ref
          .read(authNotifierProvider.notifier)
          .completeProfile(
            fullName: _fullName.text.trim(),
            bio: _bio.text.trim(),
            avatarPath: avatarPath,
          );
      if (!mounted) return;
      final result = ref.read(authNotifierProvider);
      if (result.hasError && mounted) {
        context.showSnack(result.error.toString(), isError: true);
      }
    } catch (e) {
      if (mounted) context.showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete your profile')),
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
                      radius: 48,
                      backgroundColor: context.colors.surfaceContainerHighest,
                      backgroundImage: _pickedAvatar != null
                          ? FileImage(File(_pickedAvatar!.path))
                          : null,
                      child: _pickedAvatar == null
                          ? Icon(
                              Icons.add_a_photo_rounded,
                              size: 28,
                              color: context.colors.onSurfaceVariant,
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Add a profile picture',
                    style: context.textTheme.labelSmall,
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
                  controller: _bio,
                  label: 'Bio (optional)',
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
                      : const Text('Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
