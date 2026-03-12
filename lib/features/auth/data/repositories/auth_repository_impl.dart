import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/sync/connectivity_manager.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDatasource remoteDatasource;
  final AuthLocalDatasource localDatasource;
  final ConnectivityManager connectivity;

  AuthRepositoryImpl({
    required this.remoteDatasource,
    required this.localDatasource,
    ConnectivityManager? connectivity,
  }) : connectivity = connectivity ?? ConnectivityManager();

  @override
  Future<Either<Failure, User>> login({
    required String email,
    required String password,
  }) async {
    final isOnline = await connectivity.checkConnectivity();

    if (isOnline) {
      // ── ONLINE: authenticate against Firebase, then cache the session ──
      try {
        final user = await remoteDatasource.login(
          email: email,
          password: password,
        );
        await localDatasource.cacheUser(user);
        return Right(user);
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } catch (e) {
        return Left(ServerFailure(e.toString()));
      }
    } else {
      // ── OFFLINE: validate credentials against the cached session ──
      try {
        final cachedUser = await localDatasource.getCachedUser();

        // Validate that the supplied email matches the cached session.
        // Password cannot be verified offline (it is never stored locally),
        // so we check the email and require a non-empty password as a
        // basic guard against accidental logins.
        if (cachedUser.email.toLowerCase() != email.toLowerCase()) {
          return const Left(
            ServerFailure(
              'Offline login failed: credentials do not match the cached session. '
              'Connect to the internet to sign in with a different account.',
            ),
          );
        }

        if (password.isEmpty) {
          return const Left(ServerFailure('Password is required.'));
        }

        // Re-hydrate FacilityInfo from the cached user so the rest of
        // the app (SyncManager, HieApiService, etc.) works correctly.
        return Right(cachedUser);
      } on CacheException {
        // No cached session at all — must go online first.
        return const Left(
          ServerFailure(
            'No offline session found. Please connect to the internet '
            'and log in at least once before using the app offline.',
          ),
        );
      } catch (e) {
        return Left(ServerFailure(e.toString()));
      }
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      // Sign out from Firebase only if online — local cache is always cleared.
      if (await connectivity.checkConnectivity()) {
        await remoteDatasource.logout();
      }
      await localDatasource.clearCache();
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, User>> getCurrentUser() async {
    // Always try the local cache first (offline-first).
    try {
      final cachedUser = await localDatasource.getCachedUser();
      // If online, refresh silently in the background — don't block the UI.
      if (await connectivity.checkConnectivity()) {
        remoteDatasource.getCurrentUser().then((fresh) {
          localDatasource.cacheUser(fresh);
        }).catchError((_) {/* ignore background refresh errors */});
      }
      return Right(cachedUser);
    } on CacheException {
      // No local session — must fetch from remote.
      try {
        final user = await remoteDatasource.getCurrentUser();
        await localDatasource.cacheUser(user);
        return Right(user);
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } catch (e) {
        return Left(ServerFailure(e.toString()));
      }
    }
  }
}