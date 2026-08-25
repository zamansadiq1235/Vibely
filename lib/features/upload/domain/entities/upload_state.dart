sealed class UploadState {
  const UploadState();
}

class UploadIdle extends UploadState {
  const UploadIdle();
}

class UploadInProgress extends UploadState {
  const UploadInProgress(this.progress, {this.stage = 'Uploading video...'});

  /// 0.0 - 1.0
  final double progress;
  final String stage;
}

class UploadSuccess extends UploadState {
  const UploadSuccess(this.videoId);
  final String videoId;
}

class UploadFailure extends UploadState {
  const UploadFailure(this.message);
  final String message;
}

class UploadCancelled extends UploadState {
  const UploadCancelled();
}
