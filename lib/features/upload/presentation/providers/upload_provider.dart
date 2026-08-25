import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/supabase_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/supabase_client_provider.dart';
import '../../data/datasources/upload_remote_data_source.dart';
import '../../data/repositories/upload_repository_impl.dart';
import '../../domain/entities/upload_draft.dart';
import '../../domain/entities/upload_state.dart';
import '../../domain/repositories/upload_repository.dart';

// ---------- Dependency injection ----------

final uploadRemoteDataSourceProvider = Provider<UploadRemoteDataSource>((ref) {
  return UploadRemoteDataSource(
    ref.watch(supabaseClientProvider),
    SupabaseConstants.url,
    SupabaseConstants.anonKey,
  );
});

final uploadRepositoryProvider = Provider<UploadRepository>((ref) {
  return UploadRepositoryImpl(ref.watch(uploadRemoteDataSourceProvider));
});

// ---------- Draft (survives across the multi-step wizard) ----------

class UploadDraftNotifier extends Notifier<UploadDraft> {
  @override
  UploadDraft build() => UploadDraft();

  void update(UploadDraft Function(UploadDraft) updater) {
    state = updater(state);
  }

  void reset() => state = UploadDraft();
}

final uploadDraftProvider = NotifierProvider<UploadDraftNotifier, UploadDraft>(
  UploadDraftNotifier.new,
);

// ---------- Publish state machine ----------

class UploadNotifier extends Notifier<UploadState> {
  @override
  UploadState build() => const UploadIdle();

  Future<void> publish() async {
    final draft = ref.read(uploadDraftProvider);
    if (draft.videoFile == null) {
      state = const UploadFailure('Please select a video first.');
      return;
    }

    state = const UploadInProgress(0, stage: 'Preparing upload...');
    try {
      final videoId = await ref
          .read(uploadRepositoryProvider)
          .publish(
            draft: draft,
            onProgress: (p) {
              state = UploadInProgress(
                p,
                stage: p < 0.9
                    ? 'Uploading video...'
                    : p < 0.97
                    ? 'Uploading thumbnail...'
                    : 'Publishing...',
              );
            },
          );
      state = UploadSuccess(videoId);
      ref.read(uploadDraftProvider.notifier).reset();
    } catch (e) {
      final isCancelled = e is AppException && e.code == 'cancelled';
      state = isCancelled
          ? const UploadCancelled()
          : UploadFailure(e.toString());
    }
  }

  /// Re-runs publish() with the same draft — the draft is left intact
  /// on failure/cancel specifically so retry doesn't force the user to
  /// redo the whole wizard (spec §17: "Handle upload failure, Retry").
  Future<void> retry() => publish();

  void cancel() {
    ref.read(uploadRepositoryProvider).cancel();
  }

  void reset() {
    state = const UploadIdle();
  }
}

final uploadNotifierProvider = NotifierProvider<UploadNotifier, UploadState>(
  UploadNotifier.new,
);
