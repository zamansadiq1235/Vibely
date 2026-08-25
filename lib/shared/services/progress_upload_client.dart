import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/errors/app_exception.dart';

/// supabase_flutter's StorageFileApi.upload() doesn't expose per-byte
/// progress, and the spec (§17) requires a visible upload progress bar
/// for potentially large video files — so this talks to Supabase
/// Storage's REST endpoint directly via a streamed multipart-free PUT,
/// counting bytes as they leave the socket.
///
/// One instance is created per upload attempt so `cancel()` unambiguously
/// aborts *that* attempt (retry creates a fresh instance).
class ProgressUploadClient {
  ProgressUploadClient({
    required this.supabaseUrl,
    required this.anonKey,
    required this.accessToken,
  });

  final String supabaseUrl;
  final String anonKey;
  final String accessToken;

  http.Client? _client;
  bool _cancelled = false;

  /// Uploads [file] to `{bucket}/{path}`, calling [onProgress] with a
  /// 0.0-1.0 fraction as bytes are sent. Throws AppException on network
  /// failure, and a plain 'cancelled' AppException if cancel() was
  /// called mid-upload.
  Future<void> uploadFile({
    required String bucket,
    required String path,
    required File file,
    required String contentType,
    required void Function(double progress) onProgress,
  }) async {
    _cancelled = false;
    final client = http.Client();
    _client = client;

    final length = await file.length();
    final uri = Uri.parse('$supabaseUrl/storage/v1/object/$bucket/$path');

    final request = http.StreamedRequest('POST', uri)
      ..headers.addAll({
        'Authorization': 'Bearer $accessToken',
        'apikey': anonKey,
        'Content-Type': contentType,
        'x-upsert': 'true',
      })
      ..contentLength = length;

    var sent = 0;
    file.openRead().listen(
      (chunk) {
        if (_cancelled) return;
        request.sink.add(chunk);
        sent += chunk.length;
        onProgress(length == 0 ? 1.0 : sent / length);
      },
      onDone: () => request.sink.close(),
      onError: (Object e) => request.sink.close(),
      cancelOnError: true,
    );

    try {
      final response = await client.send(request);
      if (_cancelled) {
        throw const AppException('Upload cancelled.', code: 'cancelled');
      }
      if (response.statusCode >= 400) {
        throw AppException.unknown(
          'Upload failed (${response.statusCode}). Please try again.',
        );
      }
    } on AppException {
      rethrow;
    } on SocketException {
      throw AppException.network();
    } on HttpException {
      throw AppException.network();
    } catch (_) {
      if (_cancelled) {
        throw const AppException('Upload cancelled.', code: 'cancelled');
      }
      throw AppException.unknown('Upload failed. Please try again.');
    } finally {
      client.close();
    }
  }

  void cancel() {
    _cancelled = true;
    _client?.close();
  }
}
