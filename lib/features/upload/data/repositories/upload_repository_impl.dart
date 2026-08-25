import '../../domain/entities/upload_draft.dart';
import '../../domain/repositories/upload_repository.dart';
import '../datasources/upload_remote_data_source.dart';

class UploadRepositoryImpl implements UploadRepository {
  UploadRepositoryImpl(this._dataSource);

  final UploadRemoteDataSource _dataSource;

  @override
  Future<String> publish({
    required UploadDraft draft,
    required void Function(double progress) onProgress,
  }) {
    return _dataSource.publish(draft: draft, onProgress: onProgress);
  }

  @override
  void cancel() => _dataSource.cancel();
}
