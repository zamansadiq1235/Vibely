import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';

/// Uploads to the `avatars` bucket under `{userId}/avatar.{ext}`, matching
/// the folder-prefix convention the storage RLS policies (migration
/// 0006) check against. Shared because both Complete Profile (Phase 3)
/// and Edit Profile (Phase 4) need it.
class AvatarUploadService {
  AvatarUploadService(this._client);

  final SupabaseClient _client;

  Future<String> uploadAvatar({
    required String userId,
    required File file,
  }) async {
    try {
      final ext = file.path.split('.').last;
      final path = '$userId/avatar.$ext';
      await _client.storage
          .from(AppConstants.avatarsBucket)
          .upload(path, file, fileOptions: const FileOptions(upsert: true));
      return path;
    } catch (_) {
      throw AppException.unknown(
        'Could not upload profile picture. Please try again.',
      );
    }
  }

  String publicUrlFor(String path) {
    return _client.storage.from(AppConstants.avatarsBucket).getPublicUrl(path);
  }
}
