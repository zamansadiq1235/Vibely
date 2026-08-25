abstract class ShareRepository {
  /// Records that [videoId] was shared, via [shareType] ('native',
  /// 'copy_link', etc — spec §14). Best-effort: a failure here shouldn't
  /// block the native share sheet the user already saw/used.
  Future<void> recordShare({
    required String videoId,
    required String shareType,
  });
}
