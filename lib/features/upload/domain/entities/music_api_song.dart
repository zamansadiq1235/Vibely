import 'dart:core';

/// A song result from the free MusicAPI — `GET /music/api/prepare/{song}`
/// resolves a song id, then `GET /music/api/fetch/{id}` returns the details
/// (title, artist, artwork, duration, YouTube/Spotify links, audio stream).
///
/// Parsed leniently: our third-party reply shape can vary, so every field
/// falls back when a key is missing and the editor never hard-fails on
/// metadata cosmetics. The audio URL is the only piece that matters for the
/// video — and even it falls back to the documented `/audio/{id}` stream
/// endpoint when fetch doesn't return a URL directly.
class MusicApiSong {
  const MusicApiSong({
    required this.id,
    this.title,
    this.artist,
    this.thumbnailUrl,
    this.duration,
    required this.audioUrl,
    this.youtubeUrl,
    this.spotifyUrl,
  });

  final String id;
  final String? title;
  final String? artist;
  final String? thumbnailUrl;
  final Duration? duration;
  final String audioUrl;
  final String? youtubeUrl;
  final String? spotifyUrl;

  factory MusicApiSong.fromJson(
    Map<String, dynamic> json, {
    required String id,
    required String fallbackAudioUrl,
  }) {
    final data = json['data'] is Map
        ? json['data'] as Map<String, dynamic>
        : json;
    return MusicApiSong(
      id: id,
      title: _firstString(data, const ['title','name','song','song_name','track','track_name']),
      artist: _firstString(data, const ['artist','artists','channel','channel_name','author','singer','uploader']),
      thumbnailUrl: _firstString(data, const ['thumbnail','thumbnail_url','thumb','image','image_url','cover','cover_url']),
      duration: _firstDuration(data),
      audioUrl: _firstString(data, const ['audio_url','audio','stream_url','download_url','url']) ?? fallbackAudioUrl,
      youtubeUrl: _firstString(data, const ['youtube_url','youtube','yt_url','youtube_link']),
      spotifyUrl: _firstString(data, const ['spotify_url','spotify','spotify_link']),
    );
  }

  static String? _firstString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
      if (value is num) return value.toString();
    }
    return null;
  }

  static Duration? _firstDuration(Map<String, dynamic> data) {
    for (final key in const ['duration','duration_seconds','length','length_seconds']) {
      final value = data[key];
      if (value is num && value.toInt() > 0) return Duration(seconds: value.toInt());
      if (value is String) {
        final t = value.trim();
        final secs = int.tryParse(t);
        if (secs != null && secs > 0) return Duration(seconds: secs);
        final parts = t.split(':').map(int.tryParse).toList();
        if (parts.length >= 2 && parts.every((p) => p != null)) {
          final minutes = parts[parts.length - 2]!;
          final seconds = parts[parts.length - 1]!;
          return Duration(minutes: minutes, seconds:  seconds);
        }
      }
    }
    return null;
  }
}