import '../../../auth/domain/entities/app_profile.dart';
import '../../domain/entities/follow_list_item.dart';
import '../../domain/repositories/follow_list_repository.dart';
import '../datasources/follow_list_remote_data_source.dart';

class FollowListRepositoryImpl implements FollowListRepository {
  FollowListRepositoryImpl(this._dataSource);

  final FollowListRemoteDataSource _dataSource;

  Future<List<FollowListItem>> _toItems(
    List<Map<String, dynamic>> rows,
    String profileKey,
  ) async {
    final profileRows = rows
        .map((r) => r[profileKey] as Map<String, dynamic>?)
        .where((p) => p != null)
        .cast<Map<String, dynamic>>()
        .toList();
    if (profileRows.isEmpty) return [];

    final ids = profileRows.map((p) => p['id'] as String).toList();
    final viewerFollowingIds = await _dataSource.fetchViewerFollowingIds(ids);

    return profileRows
        .map(
          (p) => FollowListItem(
            profile: AppProfile.fromMap(p),
            isFollowedByViewer: viewerFollowingIds.contains(p['id']),
          ),
        )
        .toList();
  }

  @override
  Future<List<FollowListItem>> fetchFollowers({
    required String userId,
    required int page,
  }) async {
    final rows = await _dataSource.fetchFollowerRows(
      userId: userId,
      page: page,
    );
    return _toItems(rows, 'follower');
  }

  @override
  Future<List<FollowListItem>> fetchFollowing({
    required String userId,
    required int page,
  }) async {
    final rows = await _dataSource.fetchFollowingRows(
      userId: userId,
      page: page,
    );
    return _toItems(rows, 'following');
  }
}
