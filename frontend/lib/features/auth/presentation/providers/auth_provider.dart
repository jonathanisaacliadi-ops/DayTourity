import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../domain/entities/auth_user.dart';
 
final _secureStorageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  ),
);
 
final _authDatasourceProvider = Provider<AuthRemoteDatasource>(
  (_) => AuthRemoteDatasource(),
);
 
sealed class AuthState {
  const AuthState();
}
 
final class AuthInitial extends AuthState {
  const AuthInitial();
}
 
final class AuthLoading extends AuthState {
  const AuthLoading();
}
 
final class AuthAuthenticated extends AuthState {
  const AuthAuthenticated({required this.user, required this.token});
  final AuthUser user;
  final String token;
}
 
final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}
 
final class AuthError extends AuthState {
  const AuthError(this.message);
  final String message;
}
 
const _tokenKey = 'access_token';
 
class AuthNotifier extends AsyncNotifier<AuthState> {
  late AuthRemoteDatasource _datasource;
  late FlutterSecureStorage _storage;
 
  @override
  Future<AuthState> build() async {
    _datasource = ref.watch(_authDatasourceProvider);
    _storage = ref.watch(_secureStorageProvider);
 
    final token = await _storage.read(key: _tokenKey);
 
    if (token == null) return const AuthUnauthenticated();
 
    try {
      final user = await _datasource.getMe(token: token);
      return AuthAuthenticated(user: user, token: token);
    } catch (_) {
      await _storage.delete(key: _tokenKey);
      return const AuthUnauthenticated();
    }
  }
 
  Future<void> register({
    required String email,
    required String name,
    required String password,
  }) async {
    state = const AsyncData(AuthLoading());
    try {
      final result = await _datasource.register(
        email: email,
        name: name,
        password: password,
      );
      await _storage.write(key: _tokenKey, value: result.token);
      state = AsyncData(
        AuthAuthenticated(user: result.user, token: result.token),
      );
    } on AuthException catch (e) {
      state = AsyncData(AuthError(e.message));
    } catch (e) {
      state = AsyncData(AuthError(e.toString()));
    }
  }
 
  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = const AsyncData(AuthLoading());
    try {
      final result = await _datasource.login(
        email: email,
        password: password,
      );
      await _storage.write(key: _tokenKey, value: result.token);
      state = AsyncData(
        AuthAuthenticated(user: result.user, token: result.token),
      );
    } on AuthException catch (e) {
      state = AsyncData(AuthError(e.message));
    } catch (e) {
      state = AsyncData(AuthError(e.toString()));
    }
  }
 
  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    state = const AsyncData(AuthUnauthenticated());
  }
 
  Future<void> refreshUser() async {
    final current = state.valueOrNull;
    if (current is! AuthAuthenticated) return;
    try {
      final updatedUser = await _datasource.getMe(token: current.token);
      state = AsyncData(
        AuthAuthenticated(user: updatedUser, token: current.token),
      );
    } catch (_) {}
  }
  Future<String?> updatePreferences(PricePreference preference) async {
    final current = state.valueOrNull;
    if (current is! AuthAuthenticated) return 'Silakan login kembali.';

    final prefString = preference.name.toUpperCase();
    try {
      final updatedUser = await _datasource.updatePreferences(
        token: current.token,
        pricePreference: prefString,
      );
      state = AsyncData(
        AuthAuthenticated(user: updatedUser, token: current.token),
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Terjadi kesalahan. Coba lagi.';
    }
  }

  Future<String?> becomeGuide() async {
  final current = state.valueOrNull;
  if (current is! AuthAuthenticated) {
    return 'Silakan login kembali.';
  }

  try {
    await _datasource.becomeGuide(token: current.token);
    await _storage.delete(key: _tokenKey);
    await _storage.write(key: 'guide_upgrade_complete', value: 'true');
    state = const AsyncData(AuthUnauthenticated());
    return null;
  } on AuthException catch (e) {
    return e.message;
  } catch (e) {
    return 'Terjadi kesalahan. Coba lagi.';
  }
}
}
 
final authProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);