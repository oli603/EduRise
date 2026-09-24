import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Client for communicating with the EduRise Coach FastAPI backend.
class CoachApiClient {
  static final CoachApiClient instance = CoachApiClient._internal();
  CoachApiClient._internal();

  factory CoachApiClient() => instance;

  /// Backend base URL.
  /// Default: Android emulator -> 10.0.2.2:8000, Web/Desktop/iOS -> 127.0.0.1:8000
  static String _baseUrl = kIsWeb
      ? 'http://127.0.0.1:8000'
      : (Platform.isAndroid ? 'http://10.0.2.2:8000' : 'http://127.0.0.1:8000');

  static String get baseUrl => _baseUrl;

  static void setBaseUrl(String url) {
    _baseUrl = url.replaceAll(RegExp(r'/+$'), '');
  }

  final http.Client _client = http.Client();

  /// Gets the current Firebase Auth ID token if signed in.
  Future<String?> _getIdToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        return await user.getIdToken();
      }
    } catch (e) {
      debugPrint('Error getting Firebase ID token: $e');
    }
    return null;
  }

  /// Sends a POST request with Auth header, JSON body, and optional Idempotency-Key.
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body, {
    String? idempotencyKey,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    final token = await _getIdToken();

    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      'Idempotency-Key': ?idempotencyKey,
    };

    try {
      final response = await _client
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(timeout);

      return _handleResponse(response);
    } on SocketException catch (e) {
      if (uri.host == '10.0.2.2') {
        try {
          final fallbackUri = Uri.parse('http://127.0.0.1:8000$endpoint');
          final fallbackResponse = await _client
              .post(fallbackUri, headers: headers, body: jsonEncode(body))
              .timeout(timeout);
          _baseUrl = 'http://127.0.0.1:8000';
          return _handleResponse(fallbackResponse);
        } catch (_) {}
      }
      debugPrint('Network error contacting EduRise Coach ($uri): $e');
      throw CoachApiException(
        'Unable to reach EduRise Coach server. Please check your internet connection.',
        statusCode: 0,
      );
    } on TimeoutException {
      throw CoachApiException(
        'The request timed out. Please check your connection and try again.',
        statusCode: 408,
      );
    } catch (e) {
      if (e is CoachApiException) rethrow;
      debugPrint('Unexpected error in CoachApiClient: $e');
      throw CoachApiException('Something went wrong. Please try again later.');
    }
  }

  /// Sends a GET request with Auth header.
  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? queryParams,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    var uri = Uri.parse('$_baseUrl$endpoint');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }

    final token = await _getIdToken();
    final headers = <String, String>{
      if (token != null) 'Authorization': 'Bearer $token',
    };

    try {
      final response = await _client.get(uri, headers: headers).timeout(timeout);
      return _handleResponse(response);
    } on SocketException catch (e) {
      if (uri.host == '10.0.2.2') {
        try {
          var fallbackUri = Uri.parse('http://127.0.0.1:8000$endpoint');
          if (queryParams != null && queryParams.isNotEmpty) {
            fallbackUri = fallbackUri.replace(queryParameters: queryParams);
          }
          final fallbackResponse = await _client.get(fallbackUri, headers: headers).timeout(timeout);
          _baseUrl = 'http://127.0.0.1:8000';
          return _handleResponse(fallbackResponse);
        } catch (_) {}
      }
      debugPrint('Network error contacting EduRise Coach ($uri): $e');
      throw CoachApiException(
        'Unable to reach EduRise Coach server. Please check your connection.',
        statusCode: 0,
      );
    } on TimeoutException {
      throw CoachApiException('Request timed out.', statusCode: 408);
    } catch (e) {
      if (e is CoachApiException) rethrow;
      throw CoachApiException('Failed to complete request.');
    }
  }

  /// Sends a PATCH request with Auth header.
  Future<Map<String, dynamic>> patch(
    String endpoint,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    final token = await _getIdToken();

    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    try {
      final response = await _client
          .patch(uri, headers: headers, body: jsonEncode(body))
          .timeout(timeout);
      return _handleResponse(response);
    } on SocketException {
      throw CoachApiException('Unable to reach server.', statusCode: 0);
    } catch (e) {
      if (e is CoachApiException) rethrow;
      throw CoachApiException('Failed to update report.');
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    Map<String, dynamic> data = {};
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          data = decoded;
        } else if (decoded is List) {
          data = {'items': decoded};
        }
      } catch (_) {
        data = {'raw': response.body};
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    final detail = data['detail'] ?? data['message'] ?? 'An error occurred (${response.statusCode})';
    if (response.statusCode == 429) {
      throw CoachApiException(
        'Daily AI quota or rate limit reached. Please upgrade to Pro or try again tomorrow.',
        statusCode: 429,
      );
    } else if (response.statusCode == 401) {
      throw CoachApiException('Please sign in to access AI Coach features.', statusCode: 401);
    } else if (response.statusCode == 403) {
      throw CoachApiException('Access restricted. Please verify your subscription.', statusCode: 403);
    } else {
      throw CoachApiException(detail.toString(), statusCode: response.statusCode);
    }
  }
}

class CoachApiException implements Exception {
  final String message;
  final int? statusCode;

  CoachApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
