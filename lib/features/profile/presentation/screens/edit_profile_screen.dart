import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/network/supabase_client_provider.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/services/avatar_upload_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/widgets/auth_text_field.dart';
import '../providers/profile_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullName;
  late final TextEditingController _userName;
  late final TextEditingController _bio;
  XFile? _pickedAvatar;
  bool _isSubmitting = false;
  bool _initializedFromProfile = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(myProfileProvider);
    _fullName = TextEditingController(text: profile?.fullName ?? '');
    _userName = TextEditingController(text: profile?.username ?? '');
    _bio = TextEditingController(text: profile?.bio ?? '');
    if (profile != null) {
      _initializedFromProfile = true;
    }
  }

  @override
  void dispose() {
    _fullName.dispose();
    _userName.dispose();
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final userId = ref.read(currentUserIdProvider);
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
          .read(profileRepositoryProvider)
          .updateProfile(
            fullName: _fullName.text.trim(),
            userName: _userName.text.trim(),
            bio: _bio.text.trim(),
            avatarPath: avatarPath,
          );
      if (!mounted) return;
      // authNotifierProvider owns the cached "my profile" — refresh it,
      // and refresh this profileProvider(userId) entry too.
      ref.invalidate(authNotifierProvider);
      ref.invalidate(profileProvider(userId));
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) context.showSnack('$e', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(myProfileProvider);
    if (!_initializedFromProfile && profile != null) {
      _fullName.text = profile.fullName;
      _userName.text = profile.username;
      _bio.text = profile.bio;
      _initializedFromProfile = true;
    }

    final existingAvatarUrl = profile?.avatarPath == null
        ? null
        : ref
              .read(supabaseClientProvider)
              .storage
              .from(AppConstants.avatarsBucket)
              .getPublicUrl(profile!.avatarPath!);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _save,
            child: _isSubmitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
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
                                as ImageProvider
                          : (existingAvatarUrl != null
                                ? NetworkImage(existingAvatarUrl)
                                      as ImageProvider
                                : null),
                      child: _pickedAvatar == null && existingAvatarUrl == null
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
                  child: TextButton(
                    onPressed: _pickAvatar,
                    child: const Text('Change photo'),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: AuthTextField(
                    controller: _userName,
                    label: 'Username',
                    validator: Validators.username,
                  ),
                ),
                AuthTextField(
                  controller: _fullName,
                  label: 'Full name',
                  validator: (v) => Validators.required(v, field: 'Full name'),
                ),
                const SizedBox(height: 14),
                AuthTextField(
                  controller: _bio,
                  label: 'Bio',
                  textInputAction: TextInputAction.done,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
