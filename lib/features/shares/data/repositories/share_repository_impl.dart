import '../../domain/repositories/share_repository.dart';
import '../datasources/share_remote_data_source.dart';

class ShareRepositoryImpl implements ShareRepository {
  ShareRepositoryImpl(this._dataSource);

  final ShareRemoteDataSource _dataSource;

  @override
  Future<void> recordShare({
    required String videoId,
    required String shareType,
  }) {
    return _dataSource.recordShare(videoId: videoId, shareType: shareType);
  }
}
