import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class AnnouncementService {
  /// 1. Home page — Announcements feed
  static Future<Map<String, dynamic>> getAnnouncements({
    int page = 1,
    String? search,
    int? categoryId,
    String? universityId,
    double? minPrice,
    double? maxPrice,
  }) async {
    final queryParams = <String, String>{'page': page.toString()};
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (categoryId != null) queryParams['category'] = categoryId.toString();
    if (universityId != null) queryParams['university'] = universityId.toString();
    if (minPrice != null) queryParams['min_price'] = minPrice.toString();
    if (maxPrice != null) queryParams['max_price'] = maxPrice.toString();

    final uri = Uri.parse('${ApiConfig.baseUrl}/announcements/').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: await ApiConfig.getHeaders());

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load announcements: ${response.body}');
    }
  }

  /// 9. Nearby announcements
  static Future<List<dynamic>> getNearbyAnnouncements(double lat, double lon, {double radius = 50.0}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/announcements/nearby/').replace(queryParameters: {
      'lat': lat.toString(),
      'lon': lon.toString(),
      'radius': radius.toString(),
    });
    final response = await http.get(uri, headers: await ApiConfig.getHeaders());

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load nearby announcements: ${response.body}');
    }
  }

  /// 10. Announcement detail
  static Future<Map<String, dynamic>> getAnnouncementDetails(int id) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/announcements/$id/'),
      headers: await ApiConfig.getHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load announcement details: ${response.body}');
    }
  }

  /// 19. My announcements
  static Future<List<dynamic>> getMyAnnouncements() async {
  final response = await http.get(
    Uri.parse('${ApiConfig.baseUrl}/announcements/my/'),
    headers: await ApiConfig.getHeaders(),
  );

  print('🔍 My announcements status: ${response.statusCode}');
  print('🔍 My announcements body: ${response.body}');

  if (response.statusCode == 200) {
    final decoded = jsonDecode(response.body);
    
    // ✅ Handle both paginated and plain list responses
    if (decoded is List) {
      return decoded;
    } else if (decoded is Map && decoded.containsKey('results')) {
      return decoded['results'] as List<dynamic>;
    } else {
      return [];
    }
  } else {
    throw Exception('Failed to load my announcements: ${response.body}');
  }
}

  /// 16. Update announcement
  static Future<Map<String, dynamic>> updateAnnouncement(
    int id,
    Map<String, String> data,
    List<String>? photoPaths,
  ) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/announcements/$id/update/');
    var request = http.MultipartRequest('PUT', uri)
      ..headers.addAll(await ApiConfig.getHeaders(isMultipart: true))
      ..fields.addAll(data);

    if (photoPaths != null) {
      for (String path in photoPaths) {
        request.files.add(await http.MultipartFile.fromPath('photos', path));
      }
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

print('📥 Response status: ${response.statusCode}');
print('📥 Response body: ${response.body}');


    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update announcement: ${response.body}');
    }
  }

  /// 17. Change status
  static Future<Map<String, dynamic>> changeStatus(int id, String status) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/announcements/$id/status/'),
      headers: await ApiConfig.getHeaders(),
      body: jsonEncode({'status': status}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to change status: ${response.body}');
    }
  }

  /// 18. Archive announcement
  static Future<Map<String, dynamic>> archiveAnnouncement(int id) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/announcements/$id/archive/'),
      headers: await ApiConfig.getHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to archive announcement: ${response.body}');
    }
  }

  /// 15. Create announcement
  static Future<Map<String, dynamic>> createAnnouncement({
    required String title,
    required String description,
    required String price,
    required String categoryId,
    required String universityId,
    required String location,
    String? phoneNumber,
    String? model,
    required List<File> photos,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/announcements/create/'),
    );

    final headers = await ApiConfig.getHeaders(isMultipart: true);
    request.headers.addAll(headers);

    request.fields['title'] = title;
    request.fields['description'] = description;
    request.fields['price'] = price;
    request.fields['category'] = categoryId;
    request.fields['university'] = universityId;
    request.fields['location'] = location;
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
  request.fields['phone_number'] = phoneNumber;
}

    for (final photo in photos) {
      request.files.add(await http.MultipartFile.fromPath('photos', photo.path));
    }

    if (model != null && model.isNotEmpty){
      request.fields['model']=model;
    }

    print('📤 Sending fields: ${request.fields}');
    print('📤 Sending to: ${ApiConfig.baseUrl}/announcements/create');
    print('📤 Photos count: ${photos.length}');

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    print('📥 POST Status: ${response.statusCode}');  // ← ADD THIS
print('📥 POST Body: ${response.body}');     

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create: ${response.body}');
    }
  }

  /// Get comments for an announcement
  static Future<List<dynamic>> getComments(dynamic announcementId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/announcements/$announcementId/comments/'),
      headers: await ApiConfig.getHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load comments: ${response.body}');
    }
  }

  /// Post a comment on an announcement
  static Future<Map<String, dynamic>> createComment(
      dynamic announcementId, String content) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/announcements/$announcementId/comments/'),
      headers: await ApiConfig.getHeaders(),
      body: jsonEncode({'content': content}),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to post comment: ${response.body}');
    }
  }
  /// Rate an announcement
  static Future<void> rateAnnouncement(int announcementId, {int rating = 5}) async {
  final response = await http.post(
    Uri.parse('${ApiConfig.baseUrl}/announcements/$announcementId/reviews/'),
    headers: await ApiConfig.getHeaders(),
    body: jsonEncode({
  'rating': rating,
  'comment': 'rated',
}),
  );

    if (response.statusCode != 201) {
      throw Exception('Failed to rate announcement: ${response.body}');
    }
  }
  /// Report an announcement
static Future<void> reportAnnouncement(int announcementId, String reason) async {
  final response = await http.post(
    Uri.parse('${ApiConfig.baseUrl}/reports/'),
    headers: await ApiConfig.getHeaders(),
    body: jsonEncode({
      'announcement': announcementId,
      'reason': reason,
    }),
  );
  if (response.statusCode != 201) {
    throw Exception('Failed to report: ${response.body}');
  }
}

/// Delete announcement
static Future<void> deleteAnnouncement(int id) async {
  final response = await http.delete(
    Uri.parse('${ApiConfig.baseUrl}/announcements/$id/archive/'),
    headers: await ApiConfig.getHeaders(),
  );
  if (response.statusCode != 200 && response.statusCode != 204) {
    throw Exception('Failed to delete announcement: ${response.body}');
  }
}


}
