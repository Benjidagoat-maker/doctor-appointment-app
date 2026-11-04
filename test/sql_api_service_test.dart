import 'dart:convert';
import 'package:doctor_appointment_app/services/sql_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const realUrl = 'https://api.example.test/api';

  test('placeholder URL: labelled demo data and NO network traffic', () async {
    var calls = 0;
    final svc = SqlApiService(
      client: MockClient((_) async {
        calls++;
        return http.Response('[]', 200);
      }),
    );
    expect(svc.isConfigured, isFalse);

    final records = await svc.fetchSqlMedicalRecords('u1');
    expect(records, isNotEmpty);
    expect(records.every((r) => '${r['source']}'.contains('DEMO')), isTrue);
    expect(await svc.syncAppointmentToSql({'a': 1}), isFalse);
    expect(calls, 0);
  });

  test('configured: parses a 200 response', () async {
    final svc = SqlApiService(
      baseUrl: realUrl,
      client: MockClient((req) async {
        expect(req.url.path, '/api/patients/u1/records');
        return http.Response(
            jsonEncode([
              {'id': 'r1', 'diagnosis': 'Checkup'}
            ]),
            200);
      }),
    );
    final records = await svc.fetchSqlMedicalRecords('u1');
    expect(records.single['diagnosis'], 'Checkup');
  });

  test('configured: server error / exception returns [] (never fake data)', () async {
    final failing = SqlApiService(
        baseUrl: realUrl, client: MockClient((_) async => http.Response('x', 500)));
    expect(await failing.fetchSqlMedicalRecords('u1'), isEmpty);

    final throwing = SqlApiService(
        baseUrl: realUrl, client: MockClient((_) async => throw Exception('down')));
    expect(await throwing.fetchSqlMedicalRecords('u1'), isEmpty);
  });

  test('sync returns true on 201 and false on failure', () async {
    final ok = SqlApiService(
        baseUrl: realUrl, client: MockClient((_) async => http.Response('', 201)));
    expect(await ok.syncAppointmentToSql({'a': 1}), isTrue);

    final bad = SqlApiService(
        baseUrl: realUrl, client: MockClient((_) async => throw Exception('down')));
    expect(await bad.syncAppointmentToSql({'a': 1}), isFalse);
  });
}
