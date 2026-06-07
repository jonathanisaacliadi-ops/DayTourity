import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:http/http.dart' as http;
import '../../../../core/config/app_config.dart';
import '../../domain/entities/auth_user.dart';

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AuthRemoteDatasource {
  AuthRemoteDatasource({http.Client? client})
      : client = client ?? http.Client();

  final http.Client client;

  String get _base => AppConfig.baseUrl;

  Future<({String token, AuthUser user})> register({
    required String email,
    required String name,
    required String password,
  }) async {
    final response = await _post('/auth/register', {
      'email': email,
      'name': name,
      'password': password,
    });
    return _parseAuthResponse(response);
  }

  Future<({String token, AuthUser user})> login({
    required String email,
    required String password,
  }) async {
    final response = await _post('/auth/login', {
      'email': email,
      'password': password,
    });
    return _parseAuthResponse(response);
  }

  Future<http.Response> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('$_base$path');
    if (kDebugMode) debugPrint('[AUTH] POST $uri');
    try {
      return await client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
    } on SocketException catch (e) {
      throw AuthException('Cannot reach server. Is NestJS running? ($e)');
    } on HandshakeException catch (e) {
      throw AuthException('SSL error: $e');
    } catch (e) {
      throw AuthException('Connection failed: $e');
    }
  }

  ({String token, AuthUser user}) _parseAuthResponse(http.Response response) {
    if (kDebugMode) {
      debugPrint('[AUTH] ${response.statusCode} ${response.body}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 400) {
      final message = body['message'];
      throw AuthException(
        message is List ? (message.first as String) : (message as String),
      );
    }

    return (
      token: body['accessToken'] as String,
      user: AuthUser.fromJson(body['user'] as Map<String, dynamic>),
    );
  }

  Future<AuthUser> getMe({required String token}) async {
    final uri = Uri.parse('$_base/users/me');
    if (kDebugMode) debugPrint('[AUTH] GET $uri');
 
    final response = await client.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 10));
 
    if (kDebugMode) debugPrint('[AUTH] ${response.statusCode} ${response.body}');
 
    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw AuthException(
        body['message']?.toString() ?? 'Failed to fetch user',
      );
    }
 
    return AuthUser.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AuthUser> updatePreferences({
    required String token,
    required String pricePreference,
  }) async {
    final uri = Uri.parse('$_base/users/me/preferences');
    if (kDebugMode) debugPrint('[AUTH] PATCH $uri');

    final response = await client.patch(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'pricePreference': pricePreference}),
    ).timeout(const Duration(seconds: 10));

    if (kDebugMode) debugPrint('[AUTH] ${response.statusCode} ${response.body}');

    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final message = body['message'];
      throw AuthException(
        message is List ? (message.first as String) : (message as String? ?? 'Request failed'),
      );
    }

    return AuthUser.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AuthUser> becomeGuide({required String token}) async {
    final uri = Uri.parse('$_base/users/me/become-guide');
    if (kDebugMode) debugPrint('[AUTH] PATCH $uri');
 
    final response = await client.patch(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 10));
 
    if (kDebugMode) debugPrint('[AUTH] ${response.statusCode} ${response.body}');
 
    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final message = body['message'];
      throw AuthException(
        message is List ? (message.first as String) : (message as String? ?? 'Request failed'),
      );
    }
 
    return AuthUser.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}
