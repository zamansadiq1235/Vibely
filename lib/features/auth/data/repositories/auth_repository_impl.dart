import '../../domain/entities/app_profile.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._dataSource);

  final AuthRemoteDataSource _dataSource;

  @override
  String? get currentUserId => _dataSource.currentUserId;

  @override
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String username,
    required String fullName,
  }) {
    return _dataSource.signUpWithEmail(
      email: email,
      password: password,
      username: username,
      fullName: fullName,
    );
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _dataSource.signInWithEmail(email: email, password: password);
  }

  @override
  Future<void> signInWithGoogle() => _dataSource.signInWithGoogle();

  @override
  Future<void> signInWithFacebook() => _dataSource.signInWithFacebook();

  @override
  Future<void> signOut() => _dataSource.signOut();

  @override
  Future<void> sendPasswordResetEmail(String email) =>
      _dataSource.sendPasswordResetEmail(email);

  @override
  Future<void> resendEmailVerification(String email) =>
      _dataSource.resendEmailVerification(email);

  @override
  Future<AppProfile?> fetchCurrentProfile() async {
    final row = await _dataSource.fetchCurrentProfileRow();
    if (row == null) return null;
    return AppProfile.fromMap(row);
  }

  @override
  Future<void> completeProfile({
    required String fullName,
    required String bio,
    String? avatarPath,
  }) {
    return _dataSource.completeProfile(
      fullName: fullName,
      bio: bio,
      avatarPath: avatarPath,
    );
  }
}
