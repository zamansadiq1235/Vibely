// ignore_for_file: use_null_aware_elements

import 'package:supabase_flutter/supabase_flutter.dart';

class ShareRemoteDataSource {
  ShareRemoteDataSource(this._client);

  final SupabaseClient _client;

  Future<void> recordShare({
    required String videoId,
    required String shareType,
  }) async {
    final userId = _client.auth.currentUser?.id;
    try {
      await _client.from('video_shares').insert({
        'video_id': videoId,
        if (userId != null) 'user_id': userId,
        'share_type': shareType,
      });
    } catch (_) {
      // Best-effort — see ShareRepository doc comment.
    }
  }
}
