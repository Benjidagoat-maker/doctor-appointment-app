import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service connecting to an external SQL database (MySQL / PostgreSQL / Cloud SQL)
/// via a REST API backend.
class SqlApiService {
  // Replace with your backend URL (e.g. Node.js/Python Cloud Function or Cloud Run connecting to Cloud SQL/Postgres/MySQL)
  static const String defaultBaseUrl = 'https://api.yourdomain.com/api';
  final String baseUrl;

  SqlApiService({this.baseUrl = defaultBaseUrl});

  /// Example: Fetch doctors or medical records from SQL database
  Future<List<Map<String, dynamic>>> fetchSqlMedicalRecords(String patientId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/patients/$patientId/records'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        return [];
      }
    } catch (_) {
      // Graceful fallback when endpoint is offline or demo mode
      return [
        {
          'id': 'rec_101',
          'diagnosis': 'Annual General Health Checkup',
          'doctor': 'Dr. Sarah Connor',
          'date': '2026-10-15',
          'status': 'Completed',
          'source': 'PostgreSQL / Cloud SQL'
        },
        {
          'id': 'rec_102',
          'diagnosis': 'Dental Cleaning & Fluoride Treatment',
          'doctor': 'Dr. Marcus Vance',
          'date': '2026-08-20',
          'status': 'Completed',
          'source': 'MySQL Enterprise'
        }
      ];
    }
  }

  /// Example: Sync an appointment or audit log directly to SQL
  Future<bool> syncAppointmentToSql(Map<String, dynamic> appointmentData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/appointments/sync'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(appointmentData),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }
}

