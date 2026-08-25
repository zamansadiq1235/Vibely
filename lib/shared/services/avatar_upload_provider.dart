import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/supabase_client_provider.dart';
import 'avatar_upload_service.dart';

final avatarUploadServiceProvider = Provider<AvatarUploadService>((ref) {
  return AvatarUploadService(ref.watch(supabaseClientProvider));
});
