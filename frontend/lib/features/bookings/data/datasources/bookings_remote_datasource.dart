import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:http/http.dart' as http;
import '../../../../core/config/app_config.dart';
import '../../domain/entities/booking_entity.dart';
 
class BookingsException implements Exception {
  const BookingsException(this.message);
  final String message;
  @override
  String toString() => message;
}
 
class BookingsRemoteDatasource {
  BookingsRemoteDatasource({http.Client? client})
      : _client = client ?? http.Client();
 
  final http.Client _client;
  String get _base => AppConfig.baseUrl;
  
  Future<List<BookingEntity>> getMyTours({
    required String token,
    String? status,
  }) async {
    final uri = Uri.parse('$_base/bookings/my-tours').replace(
      queryParameters: status != null ? {'status': status} : null,
    );
 
    if (kDebugMode) debugPrint('[BOOKINGS] GET $uri');
 
    final response = await _client.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 10));
 
    if (kDebugMode) debugPrint('[BOOKINGS] ${response.statusCode}');
 
    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw BookingsException(body['message']?.toString() ?? 'Failed to load trips.');
    }
 
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>;
    return data
        .map((e) => BookingEntity.fromJson(e as Map<String, dynamic>))
        .toList();
  }
  Future<List<BookingEntity>> getGuideBookings({required String token}) async {
    final uri = Uri.parse('$_base/bookings/guide');
    if (kDebugMode) debugPrint('[BOOKINGS] GET $uri');

    final response = await _client.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw BookingsException(
          body['message']?.toString() ?? 'Failed to load reservations.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>;
    return data
        .map((e) => BookingEntity.fromJson(e as Map<String, dynamic>))
        .toList();
  }
  Future<void> cancel({
    required String token,
    required String bookingId,
  }) async {
    final uri = Uri.parse('$_base/bookings/$bookingId/cancel');
    if (kDebugMode) debugPrint('[BOOKINGS] PATCH $uri');

    final response = await _client.patch(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final msg = body['message'];
      throw BookingsException(
          msg is List ? msg.first.toString() : (msg?.toString() ?? 'Cancellation failed.'));
    }
  }
  Future<void> reserve({
    required String token,
    required String tourId,
    required String scheduledDate,
    String? notes,
  }) async {
    final uri = Uri.parse('$_base/bookings/reserve');
    if (kDebugMode) debugPrint('[BOOKINGS] POST $uri');

    final response = await _client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'tourId': tourId,
            'scheduledDate': scheduledDate,
            if (notes != null && notes.isNotEmpty) 'notes': notes,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final msg = body['message'];
      throw BookingsException(
          msg is List ? msg.first.toString() : (msg?.toString() ?? 'Reservation failed.'));
    }
  }
}