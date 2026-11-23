import 'package:doctor_appointment_app/services/app_update_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppUpdateRelease', () {
    final release = AppUpdateRelease.fromJson({
      'version': '1.2.0',
      'buildNumber': 3,
      'downloadUrl': 'https://example.com/download',
      'releaseNotes': 'New booking improvements.',
    });

    test('compares versions before build numbers', () {
      expect(release.isNewerThan('1.1.9', '99'), isTrue);
      expect(release.isNewerThan('1.2.0', '2'), isTrue);
      expect(release.isNewerThan('1.2.0', '3'), isFalse);
      expect(release.isNewerThan('1.2.1', '1'), isFalse);
    });

    test('rejects a manifest with a non-HTTPS download URL', () {
      expect(
        () => AppUpdateRelease.fromJson({
          'version': '1.2.0',
          'buildNumber': 3,
          'downloadUrl': 'http://example.com/download',
        }),
        throwsFormatException,
      );
    });
  });
}
