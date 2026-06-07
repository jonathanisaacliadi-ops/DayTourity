import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:http/http.dart' as http;
import '../../../../core/config/app_config.dart';
import '../../domain/entities/pending_guide.dart';

class AdminException implements Exception {
  const AdminException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AdminRemoteDatasource {
  AdminRemoteDatasource({http.Client? client})
      : client = client ?? http.Client();

  final http.Client client;

  String get _base => AppConfig.baseUrl;

  Future<List<PendingGuide>> fetchPendingGuides({required String token}) async {
    final uri = Uri.parse('$_base/users/pending-guides');
    if (kDebugMode) debugPrint('[ADMIN] GET $uri');

    try {
      final response = await client.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (kDebugMode) {
        debugPrint('[ADMIN] ${response.statusCode} ${response.body}');
      }

      if (response.statusCode >= 400) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final message = body['message'];
        throw AdminException(
          message is List
              ? (message.first as String)
              : (message as String? ?? 'Failed to load applications'),
        );
      }

      final list = jsonDecode(response.body) as List<dynamic>;
      return list
          .map((e) => PendingGuide.fromJson(e as Map<String, dynamic>))
          .toList();
    } on SocketException catch (e) {
      throw AdminException('Cannot reach server. Is NestJS running? ($e)');
    }
  }

  Future<void> approveGuide({required String token, required String id}) =>
      _patch('/users/$id/approve-guide', token);

  Future<void> rejectGuide({required String token, required String id}) =>
      _patch('/users/$id/reject-guide', token);

  Future<void> _patch(String path, String token) async {
    final uri = Uri.parse('$_base$path');
    if (kDebugMode) debugPrint('[ADMIN] PATCH $uri');

    try {
      final response = await client.patch(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (kDebugMode) {
        debugPrint('[ADMIN] ${response.statusCode} ${response.body}');
      }

      if (response.statusCode >= 400) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final message = body['message'];
        throw AdminException(
          message is List
              ? (message.first as String)
              : (message as String? ?? 'Action failed'),
        );
      }
    } on SocketException catch (e) {
      throw AdminException('Cannot reach server. Is NestJS running? ($e)');
    }
  }
}
