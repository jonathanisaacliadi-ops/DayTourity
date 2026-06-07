import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart' if (dart.library.html) 'web_geocoding_stub.dart';

sealed class LocationState {
  const LocationState();
}

final class LocationLoading extends LocationState {
  const LocationLoading();
}

final class LocationDetected extends LocationState {
  const LocationDetected(this.city);
  final String city;
}

final class LocationDenied extends LocationState {
  const LocationDenied();
}

final class LocationError extends LocationState {
  const LocationError(this.message);
  final String message;
}

class LocationNotifier extends AsyncNotifier<LocationState> {
  @override
  Future<LocationState> build() => _detectCity();

  Future<LocationState> _detectCity() async {
    try {
      if (kIsWeb) {
        return await _detectCityWeb();
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return const LocationDenied();

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const LocationDenied();
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final city =
          await _reverseGeocodeMobile(position.latitude, position.longitude);

      return city != null && city.isNotEmpty
          ? LocationDetected(city)
          : const LocationDenied();
    } catch (e) {
      return LocationError(e.toString());
    }
  }

  Future<LocationState> _detectCityWeb() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 15),
        ),
      );

      final city =
          await _reverseGeocodeWeb(position.latitude, position.longitude);

      return city != null && city.isNotEmpty
          ? LocationDetected(city)
          : const LocationDenied();
    } catch (_) {
      return const LocationDenied();
    }
  }

  Future<String?> _reverseGeocodeMobile(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      final p = placemarks.first;
      return p.locality?.isNotEmpty == true
          ? p.locality
          : p.subAdministrativeArea?.isNotEmpty == true
              ? p.subAdministrativeArea
              : p.administrativeArea;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _reverseGeocodeWeb(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json&lat=$lat&lon=$lng&zoom=10&addressdetails=1',
      );
      final res = await http
          .get(uri, headers: {'User-Agent': 'LokaGuide/1.0'})
          .timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final address = body['address'] as Map<String, dynamic>?;
      if (address == null) return null;

      return (address['city'] ??
              address['town'] ??
              address['village'] ??
              address['county'] ??
              address['state']) as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> retry() async {
    state = const AsyncData(LocationLoading());
    state = AsyncData(await _detectCity());
  }

  void setManualCity(String city) {
    state = AsyncData(LocationDetected(city));
  }
}

final locationProvider =
    AsyncNotifierProvider<LocationNotifier, LocationState>(
  LocationNotifier.new,
);
