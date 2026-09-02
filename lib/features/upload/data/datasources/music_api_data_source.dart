import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/music_api_song.dart';

/// Thin HTTP client for the free MusicAPI
/// (https://bhindi1.ddns.net/music/api):
///  1. `GET /prepare/{song_name/url}` -> song id (raw YouTube/Spotify
///      URLs are accepted too);
///  2. `GET /fetch/{id}` -> song metadata (title, artist, artwork, duration,
///      YouTube/Spotify links, and the audio stream URL);
///  3. `GET /audio/{id}` -> the audio stream — used as the editor preview/
///      feed `music_url` fallback when fetch doesn't return a URL directly.
///
/// Every call is wrapped so a dead/unreachable MusicAPI degrades the music
/// search tab gracefully instead of breaking the upload wizard,
class MusicApiDataSource {
  MusicApiDataSource({http.Client? client, this.baseUrl = AppConstants.musicApiBaseUrl})
      : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  static const Duration _timeout = Duration(seconds: 25);

  /// `GET /prepare/{query}` — returns the song id for the best match of a
  /// song name or a YouTube/Spotify URL.

  Future<String> prepareSong(String query) async {
    final uri = Uri.parse('$baseUrl/prepare/${Uri.encodeComponent(query.trim())}');
    final body = await _getString(uri);
    final decoded = _tryDecode(body);

    if (decoded is Map) {
      final map = decoded as Map<String, dynamic>;
      final data = map['data'] is Map ? map['data'] as Map<String, dynamic> : map;
      final id = data['song_id'] ?? data['id'];
      if (id != null && id.toString().trim().isNotEmpty) return id.toString().trim();
    }
    if (decoded is String && decoded.trim().isNotEmpty) return decoded.trim();

    // Last resort: a bare plain-text reply. (Some deployments respond
    // with the id alone rather than JSON.)
    for (final line in body.split('\n')) {
      final t = line.trim();
      if (t.isNotEmpty && !t.startsWith('{') && !t.startsWith('[')) return t;
    }
    throw AppException.unknown('Could not find that song. Try a different name or paste a link.');
  }

  /// `GET /fetch/{id}` — returns the full song record (details + audio stream).
  Future<MusicApiSong> fetchSong(String id) async {
    final safeId = Uri.encodeComponent(id);
    final uri = Uri.parse('$baseUrl/fetch/$safeId');
    final body = await _getString(uri);
    final decoded = _tryDecode(body);
    if (decoded is! Map) {
      throw AppException.unknown('Unexpected music response. Try again.');
    }
    return MusicApiSong.fromJson(
      decoded as Map<String, dynamic>,
      id: id,
      fallbackAudioUrl: '$baseUrl/audio/$safeId',
    );
  }

  Future<String> _getString(Uri uri) async {
    try {
      final res = await _client.get(uri).timeout(_timeout);
      if (res.statusCode >= 400) {
        throw AppException.unknown('Music service error (${res.statusCode}).');
      }
      return res.body;
    } on AppException {
      rethrow;
    } on TimeoutException {
      throw AppException.network();
    } catch (_) {
      throw AppException.network();
    }
  }

  /// Tries to decode a JSON body. Returns the decoded value (Map, String,
  /// List, etc.) on success, or `null` if the body isn't valid JSON.
  dynamic _tryDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  void dispose() => _client.close();
}
