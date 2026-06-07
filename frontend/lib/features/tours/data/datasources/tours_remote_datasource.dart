import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/config/app_config.dart';
import '../../domain/entities/tour.dart';

class CreateActivityRequest {
  const CreateActivityRequest({
    required this.name,
    this.description,
    required this.pricingType,
    this.fixedPrice,
    this.minPrice,
    this.maxPrice,
    required this.order,
  });

  final String name;
  final String? description;
  final String pricingType;
  final double? fixedPrice;
  final double? minPrice;
  final double? maxPrice;
  final int order;

  Map<String, dynamic> toJson() => {
        'name': name,
        if (description != null) 'description': description,
        'pricingType': pricingType,
        if (fixedPrice != null) 'fixedPrice': fixedPrice,
        if (minPrice != null) 'minPrice': minPrice,
        if (maxPrice != null) 'maxPrice': maxPrice,
        'order': order,
      };
}

class CreateTourRequest {
  const CreateTourRequest({
    required this.title,
    required this.description,
    required this.city,
    this.basePrice,
    this.coverImageUrl,
    required this.activities,
    this.availableDates,
    this.photoUrls,
  });

  final String title;
  final String description;
  final String city;
  final double? basePrice;
  final String? coverImageUrl;
  final List<CreateActivityRequest> activities;
  final List<String>? availableDates;
  final List<String>? photoUrls;

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'city': city,
        if (basePrice != null) 'basePrice': basePrice,
        if (coverImageUrl != null && coverImageUrl!.isNotEmpty)
          'coverImageUrl': coverImageUrl,
        'activities': activities.map((a) => a.toJson()).toList(),
        if (availableDates != null && availableDates!.isNotEmpty)
          'availableDates': availableDates,
        if (photoUrls != null && photoUrls!.isNotEmpty)
          'photoUrls': photoUrls,
      };
}

class UpdateTourRequest {
  const UpdateTourRequest({
    this.title,
    this.description,
    this.city,
    this.basePrice,
    this.coverImageUrl,
    this.activities,
    this.availableDates,
  });

  final String? title;
  final String? description;
  final String? city;
  final double? basePrice;
  final String? coverImageUrl;
  final List<CreateActivityRequest>? activities;
  final List<String>? availableDates;

  Map<String, dynamic> toJson() => {
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (city != null) 'city': city,
        if (basePrice != null) 'basePrice': basePrice,
        if (coverImageUrl != null) 'coverImageUrl': coverImageUrl,
        if (activities != null)
          'activities': activities!.map((a) => a.toJson()).toList(),
        if (availableDates != null) 'availableDates': availableDates,
      };
}

class ToursRemoteDatasource {
  ToursRemoteDatasource({http.Client? client})
      : client = client ?? http.Client();

  final http.Client client;
  String get baseUrl => AppConfig.baseUrl;

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Future<List<Tour>> getRecommended({
    required String token,
    String? city,
    String? priceCategory,
  }) async {
    final params = <String, String>{};
    if (city != null && city.isNotEmpty) params['city'] = city;
    if (priceCategory != null) params['priceCategory'] = priceCategory;

    final uri = Uri.parse('$baseUrl/tours').replace(queryParameters: params);
    final response = await client.get(uri, headers: _headers(token));

    if (response.statusCode != 200) {
      throw Exception('Failed to load tours: ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final list = body['tours'] as List<dynamic>;
    return list.map((e) => Tour.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Tour> getTourById({
    required String token,
    required String id,
  }) async {
    final uri = Uri.parse('$baseUrl/tours/$id');
    final response = await client.get(uri, headers: _headers(token));

    if (response.statusCode == 404) throw Exception('Tour not found');
    if (response.statusCode != 200) {
      throw Exception('Failed to load tour: ${response.statusCode}');
    }

    return Tour.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Tour> createTour({
    required String token,
    required CreateTourRequest request,
  }) async {
    final uri = Uri.parse('$baseUrl/tours');
    final response = await client.post(
      uri,
      headers: _headers(token),
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode == 403) {
      throw Exception('Only guides can create tours');
    }
    if (response.statusCode != 201) {
      final body = jsonDecode(response.body);
      final msg = body['message'];
      throw Exception(msg is List ? msg.first : msg ?? 'Failed to create tour');
    }

    return Tour.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Tour> updateTour({
    required String token,
    required String id,
    required UpdateTourRequest request,
  }) async {
    final uri = Uri.parse('$baseUrl/tours/$id');
    final response = await client.patch(
      uri,
      headers: _headers(token),
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode == 403) {
      throw Exception('You can only edit your own tours');
    }
    if (response.statusCode == 404) throw Exception('Tour not found');
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      final msg = body['message'];
      throw Exception(msg is List ? msg.first : msg ?? 'Failed to update tour');
    }

    return Tour.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> addPhoto({
    required String token,
    required String tourId,
    required String url,
  }) async {
    final uri = Uri.parse('$baseUrl/tours/$tourId/photos');
    final response = await client.post(
      uri,
      headers: _headers(token),
      body: '{"url":"$url"}',
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to add photo: ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> deletePhoto({
    required String token,
    required String tourId,
    required String photoId,
  }) async {
    final uri = Uri.parse('$baseUrl/tours/$tourId/photos/$photoId');
    final response = await client.delete(
      uri,
      headers: _headers(token),
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete photo: ${response.statusCode}');
    }
  }

  Future<void> deleteTour({required String token, required String id}) async {
    final uri = Uri.parse('$baseUrl/tours/$id');
    final response = await client.delete(uri, headers: _headers(token));

    if (response.statusCode == 403) {
      throw Exception('Not authorised to delete this tour');
    }
    if (response.statusCode == 404) throw Exception('Tour not found');
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete tour: ${response.statusCode}');
    }
  }

  Future<String> uploadImage({
    required String token,
    required XFile file,
  }) async {
    final uploadUri = Uri.parse('${AppConfig.baseUrl}/uploads/image');

    final bytes = await file.readAsBytes();
    final filename = file.name.isNotEmpty ? file.name : 'photo.jpg';
    final contentType = _mimeTypeFromFilename(filename);

    final request = http.MultipartRequest('POST', uploadUri)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
          contentType: contentType,
        ),
      );

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode != 200 && streamed.statusCode != 201) {
      throw Exception('Upload failed (${streamed.statusCode}): $body');
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    return json['url'] as String;
  }
  MediaType _mimeTypeFromFilename(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    final sub = switch (ext) {
      'jpg' || 'jpeg' => 'jpeg',
      'png' => 'png',
      'webp' => 'webp',
      'gif' => 'gif',
      _ => 'jpeg',
    };
    return MediaType('image', sub);
  }
}
