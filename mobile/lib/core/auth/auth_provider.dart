import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../db/app_database.dart';
import 'auth_repository.dart';
import 'models/user_info.dart';
import 'secure_token_storage.dart';

part 'auth_provider.g.dart';

/// Holds the current authentication state.
///
/// - `AsyncData(UserInfo)` — authenticated.
/// - `AsyncData(null)` — unauthenticated.
/// - `AsyncLoading()` — sign-in in progress.
/// - `AsyncError(...)` — sign-in failed.
///
/// The go_router redirect (wired in phase 9) watches this provider.
@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  Future<UserInfo?> build() async {
    final storage = ref.read(secureTokenStorageProvider);
    final token = await storage.getAccessToken();
    if (token == null) return null;

    // Restore user metadata cached in the UserSession table.
    final db = ref.read(appDatabaseProvider);
    final rows = await db.select(db.userSession).get();
    final map = {for (final r in rows) r.key: r.value};
    return UserInfo.fromSessionEntries(map);
  }

  Future<void> signIn() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final user = await ref.read(authRepositoryProvider).signInWithGoogle();
      await _persistUserSession(user);
      return user;
    });
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    final db = ref.read(appDatabaseProvider);
    await db.delete(db.userSession).go();
    state = const AsyncValue.data(null);
  }

  Future<void> _persistUserSession(UserInfo user) async {
    final db = ref.read(appDatabaseProvider);
    await Future.wait(
      user.toSessionEntries().entries.map(
        (e) => db.into(db.userSession).insertOnConflictUpdate(
          UserSessionCompanion.insert(key: e.key, value: e.value),
        ),
      ),
    );
  }
}
