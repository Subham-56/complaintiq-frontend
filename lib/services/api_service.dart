import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

import '../config/config.dart';
import 'session_service.dart';

class AuthResult {
  const AuthResult({
    required this.token,
    required this.username,
    required this.role,
    required this.userId,
  });

  final String token;
  final String username;
  final String role;
  final int userId;
}

class ApiService {
  static const String baseUrl = Config.baseUrl;
  static const Duration _requestTimeout = Duration(seconds: 30);

  static Future<AuthResult> login(String email, String password) async {
    final response = await http
        .post(
          Uri.parse("$baseUrl/login"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"email": email, "password": password}),
        )
        .timeout(_requestTimeout);

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body["data"] as Map<String, dynamic>;
      return AuthResult(
        token: data["access_token"] as String,
        username: (data["username"] ?? "").toString(),
        role: (data["role"] ?? "user").toString(),
        userId: (data["user_id"] as num).toInt(),
      );
    }
    throw Exception(_extractErrorMessage(response, "Login failed"));
  }

  static Future<String> register({
    required String email,
    required String password,
    required String username,
    String? adminCode,
  }) async {
    final response = await http
        .post(
          Uri.parse("$baseUrl/register"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "email": email,
            "password": password,
            "username": username,
            "admin_code": (adminCode != null && adminCode.isNotEmpty)
                ? adminCode
                : null,
          }),
        )
        .timeout(_requestTimeout);

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body["data"] as Map<String, dynamic>;
      return (data["role"] ?? "user").toString();
    }
    throw Exception(_extractErrorMessage(response, "Registration failed"));
  }

  /// Determines the MIME type for an image being uploaded, falling back to
  /// image/jpeg if detection fails (e.g. missing/ambiguous extension).
  /// This MUST be set explicitly — http.MultipartFile does not infer
  /// content-type from the filename or bytes on its own, and the backend
  /// rejects uploads that don't declare a real image/* content-type.
  static MediaType _resolveImageMediaType(String? filename, Uint8List? bytes) {
    final mimeType =
        lookupMimeType(filename ?? '', headerBytes: bytes) ?? 'image/jpeg';
    final parts = mimeType.split('/');
    if (parts.length == 2) {
      return MediaType(parts[0], parts[1]);
    }
    return MediaType('image', 'jpeg');
  }

  static Future<Map<String, dynamic>> submitComplaint({
    required String description,
    required double latitude,
    required double longitude,
    File? imageFile,
    Uint8List? imageBytes,
    String? imageName,
  }) async {
    final token = await SessionService.requireToken();

    final request = http.MultipartRequest(
      "POST",
      Uri.parse("$baseUrl/complaints"),
    );
    request.headers["Authorization"] = "Bearer $token";
    request.fields["description"] = description;
    request.fields["latitude"] = latitude.toString();
    request.fields["longitude"] = longitude.toString();

    if (kIsWeb && imageBytes != null) {
      final filename = imageName ?? "complaint.jpg";
      request.files.add(
        http.MultipartFile.fromBytes(
          "file",
          imageBytes,
          filename: filename,
          contentType: _resolveImageMediaType(filename, imageBytes),
        ),
      );
    } else if (imageFile != null) {
      final bytes = await imageFile.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          "file",
          bytes,
          filename: imageFile.path.split(Platform.pathSeparator).last,
          contentType: _resolveImageMediaType(imageFile.path, bytes),
        ),
      );
    }

    final streamedResponse = await request.send().timeout(_requestTimeout);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body["data"] as Map<String, dynamic>;
    }
    throw Exception(
      _extractErrorMessage(response, "Failed to submit complaint"),
    );
  }

  static Future<List<dynamic>> getComplaints() async {
    final token = await SessionService.requireToken();
    final response = await http
        .get(
          Uri.parse("$baseUrl/complaints"),
          headers: {"Authorization": "Bearer $token"},
        )
        .timeout(_requestTimeout);
    if (response.statusCode == 200) return _decodeList(response);
    throw Exception(
      _extractErrorMessage(response, "Failed to load complaints"),
    );
  }

  static Future<List<dynamic>> getCommunityFeed() async {
    final token = await SessionService.requireToken();
    final response = await http
        .get(
          Uri.parse("$baseUrl/complaints/feed"),
          headers: {"Authorization": "Bearer $token"},
        )
        .timeout(_requestTimeout);
    if (response.statusCode == 200) return _decodeList(response);
    throw Exception(
      _extractErrorMessage(response, "Failed to load community feed"),
    );
  }

  static Future<List<dynamic>> getAllComplaintsMap() async {
    final token = await SessionService.requireToken();
    final response = await http
        .get(
          Uri.parse("$baseUrl/complaints/all"),
          headers: {"Authorization": "Bearer $token"},
        )
        .timeout(_requestTimeout);
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body["data"] as Map<String, dynamic>;
      return data["complaints"] as List<dynamic>;
    }
    throw Exception(
      _extractErrorMessage(response, "Failed to load complaints"),
    );
  }

  static Future<List<dynamic>> getAllComplaints() async {
    final token = await SessionService.requireToken();
    final response = await http
        .get(
          Uri.parse("$baseUrl/admin/complaints"),
          headers: {"Authorization": "Bearer $token"},
        )
        .timeout(_requestTimeout);
    if (response.statusCode == 200) return _decodeList(response);
    throw Exception(
      _extractErrorMessage(response, "Failed to load admin complaints"),
    );
  }

  static Future<void> updateComplaintStatus({
    required int complaintId,
    required String status,
  }) async {
    final token = await SessionService.requireToken();
    final response = await http
        .put(
          Uri.parse("$baseUrl/admin/complaints/$complaintId"),
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json",
          },
          body: jsonEncode({"status": status}),
        )
        .timeout(_requestTimeout);
    if (response.statusCode != 200) {
      throw Exception(
        _extractErrorMessage(response, "Failed to update status"),
      );
    }
  }

  static Future<Map<String, dynamic>> toggleUpvote(int complaintId) async {
    final token = await SessionService.requireToken();
    final response = await http
        .post(
          Uri.parse("$baseUrl/complaints/$complaintId/upvote"),
          headers: {"Authorization": "Bearer $token"},
        )
        .timeout(_requestTimeout);
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body["data"] as Map<String, dynamic>;
    }
    throw Exception(_extractErrorMessage(response, "Failed to upvote"));
  }

  static Future<Map<String, dynamic>> getAnalytics() async {
    final token = await SessionService.requireToken();
    final response = await http
        .get(
          Uri.parse("$baseUrl/admin/analytics"),
          headers: {"Authorization": "Bearer $token"},
        )
        .timeout(_requestTimeout);
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body["data"] as Map<String, dynamic>;
    }
    throw Exception(_extractErrorMessage(response, "Failed to load analytics"));
  }

  static String _extractErrorMessage(http.Response response, String fallback) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        if (body["detail"] != null) return body["detail"].toString();
        if (body["message"] != null) return body["message"].toString();
        if (body["data"] is Map) {
          final data = body["data"] as Map<String, dynamic>;
          if (data["message"] != null) return data["message"].toString();
        }
      }
    } catch (_) {}
    return fallback;
  }

  static List<dynamic> _decodeList(http.Response response) {
    final body = jsonDecode(response.body);
    if (body is List<dynamic>) return body;
    if (body is Map<String, dynamic>) {
      final data = body["data"];
      if (data == null) return const <dynamic>[];
      if (data is List<dynamic>) return data;
      if (data is Map<String, dynamic> && data["items"] is List<dynamic>) {
        return data["items"] as List<dynamic>;
      }
    }
    throw Exception('Unexpected response format');
  }
}