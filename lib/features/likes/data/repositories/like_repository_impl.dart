import '../../domain/repositories/like_repository.dart';
import '../datasources/like_remote_data_source.dart';

class LikeRepositoryImpl implements LikeRepository {
  LikeRepositoryImpl(this._dataSource);

  final LikeRemoteDataSource _dataSource;

  @override
  Future<void> likeVideo(String videoId) => _dataSource.likeVideo(videoId);

  @override
  Future<void> unlikeVideo(String videoId) => _dataSource.unlikeVideo(videoId);
}
