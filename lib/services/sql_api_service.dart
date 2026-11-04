import 'dart:convert';
import 'package:http/http.dart' as http;

/// Client for an external SQL-backed REST API (MySQL / PostgreSQL / Cloud SQL).
///
/// Configure with: `flutter run --dart-define=SQL_API_URL=https://your.api/api`.
/// While no backend is configured the service NEVER touches the network
/// (the old placeholder domain would have received real patient/user IDs) and
/// returns clearly-labelled demo data instead.
class SqlApiService {
  static const String defaultBaseUrl = String.fromEnvironment(
    'SQL_API_URL',
    defaultValue: 'https://api.yourdomain.com/api',
  );

  final String baseUrl;
  final http.Client _client;

  SqlApiService({this.baseUrl = defaultBaseUrl, http.Client? client})
      : _client = client ?? http.Client();

  bool get isConfigured => !baseUrl.contains('yourdomain.com');

  Future<List<Map<String, dynamic>>> fetchSqlMedicalRecords(
      String patientId) async {
    if (!isConfigured) return _demoRecords;
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/patients/$patientId/records'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) {
      // A configured-but-unreachable backend must not show fake records.
      return [];
    }
  }

  Future<bool> syncAppointmentToSql(Map<String, dynamic> appointmentData) async {
    if (!isConfigured) return false;
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/appointments/sync'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(appointmentData),
          )
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  static const List<Map<String, dynamic>> _demoRecords = [
    {
      'id': 'demo_1',
      'diagnosis': 'Annual General Health Checkup',
      'doctor': 'Demo Doctor A',
      'date': '2026-10-15',
      'status': 'Demo',
      'source': 'DEMO DATA - no SQL backend configured',
    },
    {
      'id': 'demo_2',
      'diagnosis': 'Dental Cleaning & Fluoride Treatment',
      'doctor': 'Demo Doctor B',
      'date': '2026-08-20',
      'status': 'Demo',
      'source': 'DEMO DATA - no SQL backend configured',
    },
  ];
}
