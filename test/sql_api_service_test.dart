import 'dart:convert';

import 'package:doctor_appointment_app/services/sql_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('SqlApiService configuration', () {
    test('does not fabricate records when no backend is configured', () async {
      final service = SqlApiService(baseUrl: '');

      expect(service.isConfigured, isFalse);
      expect(await service.fetchSqlMedicalRecords(), isEmpty);
    });

    test('requires a public Supabase key before making requests', () {
      expect(
        SqlApiService(baseUrl: 'https://records.example.com/api').isConfigured,
        isFalse,
      );
    });

    test('requires HTTPS except for local development hosts', () {
      expect(
        SqlApiService(
          baseUrl: 'https://records.example.com/api',
          anonKey: 'public-key',
        ).isConfigured,
        isTrue,
      );
      expect(
        SqlApiService(
          baseUrl: 'http://records.example.com/api',
          anonKey: 'public-key',
        ).isConfigured,
        isFalse,
      );
      expect(
        SqlApiService(
          baseUrl: 'http://localhost:8080/api',
          anonKey: 'public-key',
        ).isConfigured,
        isTrue,
      );
      expect(
        SqlApiService(baseUrl: 'https://', anonKey: 'public-key').isConfigured,
        isFalse,
      );
      expect(
        SqlApiService(
          baseUrl: 'https://user@records.example.com/api',
          anonKey: 'public-key',
        ).isConfigured,
        isFalse,
      );
    });

    test(
      'sends Firebase identity and Supabase project key to records API',
      () async {
        final service = SqlApiService(
          baseUrl: 'https://records.example.com/functions/v1/api/',
          anonKey: 'public-anon-key',
          idTokenProvider: () async => 'firebase-id-token',
          client: MockClient((request) async {
            expect(request.url.path, '/functions/v1/api/records');
            expect(request.headers['apikey'], 'public-anon-key');
            expect(
              request.headers['authorization'],
              'Bearer firebase-id-token',
            );
            return http.Response(
              jsonEncode([
                {
                  'id': 'record-1',
                  'diagnosis': 'Annual checkup',
                  'record_date': '2026-11-26',
                },
              ]),
              200,
            );
          }),
        );

        final records = await service.fetchSqlMedicalRecords();

        expect(records.single['diagnosis'], 'Annual checkup');
      },
    );

    test('surfaces API failures instead of silently returning no records', () {
      final service = SqlApiService(
        baseUrl: 'https://records.example.com/api',
        anonKey: 'public-anon-key',
        idTokenProvider: () async => 'firebase-id-token',
        client: MockClient((_) async => http.Response('', 401)),
      );

      expect(service.fetchSqlMedicalRecords(), throwsException);
    });
  });
}
