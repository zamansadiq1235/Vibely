import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../data/datasources/music_api_data_source.dart';
import '../../domain/entities/music_track.dart';

// ---------- Dependency injection ----------

final musicApiDataSourceProvider = Provider<MusicApiDataSource>((ref) {
  return MusicApiDataSource(baseUrl: AppConstants.musicApiBaseUrl);
});

// ---------- Real-time search state ----------

class MusicSearchState {
  const MusicSearchState({
    this.query = '',
    this.results = const [],
    this.isLoading = false,
    this.error,
  });

  final String query;
  final List<MusicTrack> results;
  final bool isLoading;
  final String? error;

  MusicSearchState copyWith({
    String? query,
    List<MusicTrack>? results,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return MusicSearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Searches the real-time MusicAPI: prepare(song name/url) -> fetch
/// (song details + audio stream). The API resolves one id per query, so a
/// search returns a single best-match track that the Music step can preview
/// and select. Failures surface as [MusicSearchState.error] so the UI can
/// show a Retry instead of throwing through the wizard.

class MusicSearchNotifier extends Notifier<MusicSearchState> {
  @override
  MusicSearchState build() => const MusicSearchState();

  Future<void> search(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) return;
    state = state.copyWith(query: query, isLoading: true, clearError: true);
    try {
      final dataSource = ref.read(musicApiDataSourceProvider);
      final songId = await dataSource.prepareSong(query);
      final song = await dataSource.fetchSong(songId);
      state = state.copyWith(
        isLoading: false,
        results: [
          MusicTrack(
            id: song.id,
            title: song.title ?? 'Unknown song',
            artist: song.artist ?? 'MusicAPI',
            genre: 'Search',
            previewUrl: song.audioUrl,
            thumbnailUrl: song.thumbnailUrl,
          ),
        ],
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '$e');
    }
  }

  void clear() => state = const MusicSearchState();
}

final musicSearchProvider = NotifierProvider<MusicSearchNotifier, MusicSearchState>(
  MusicSearchNotifier.new,
);