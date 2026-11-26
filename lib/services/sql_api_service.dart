import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Client for an external SQL-backed REST API (MySQL / PostgreSQL / Cloud SQL).
///
/// Configure with `SQL_API_URL`. The API must validate the Firebase bearer
/// token and scope records to the authenticated user; patient IDs are never
/// accepted from the client.
class SqlApiService {
  static const String defaultBaseUrl = String.fromEnvironment(
    'SQL_API_URL',
    defaultValue: 'https://yuddnebxjvulyvrjhugf.supabase.co/functions/v1/api',
  );
  static const String defaultAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  final String baseUrl;
  final String anonKey;
  final http.Client _client;
  final Future<String?> Function()? idTokenProvider;

  SqlApiService({
    this.baseUrl = defaultBaseUrl,
    this.anonKey = defaultAnonKey,
    http.Client? client,
    this.idTokenProvider,
  }) : _client = client ?? http.Client();

  bool get isConfigured {
    final uri = Uri.tryParse(baseUrl);
    return uri != null &&
        uri.hasAuthority &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        !uri.hasQuery &&
        !uri.hasFragment &&
        anonKey.trim().isNotEmpty &&
        (uri.scheme == 'https' ||
            (uri.scheme == 'http' &&
                (uri.host == 'localhost' || uri.host == '127.0.0.1')));
  }

  Future<List<Map<String, dynamic>>> fetchSqlMedicalRecords() async {
    if (!isConfigured) return [];
    final tokenProvider = idTokenProvider;
    final idToken = tokenProvider != null
        ? await tokenProvider()
        : await FirebaseAuth.instance.currentUser?.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Could not authenticate the medical records request.');
    }

    final response = await _client
        .get(
          Uri.parse('${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/records'),
          headers: {
            'Accept': 'application/json',
            'apikey': anonKey,
            'Authorization': 'Bearer $idToken',
          },
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception(
        'Medical records service returned HTTP ${response.statusCode}.',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FormatException('Medical records response must be a list.');
    }
    return decoded.map((record) {
      if (record is! Map) {
        throw const FormatException('Medical record must be an object.');
      }
      return Map<String, dynamic>.from(record);
    }).toList();
  }
}
