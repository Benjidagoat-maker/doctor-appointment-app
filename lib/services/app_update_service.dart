import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class AppUpdateRelease {
  const AppUpdateRelease({
    required this.version,
    required this.buildNumber,
    required this.downloadUrl,
    required this.releaseNotes,
  });

  final String version;
  final int buildNumber;
  final Uri downloadUrl;
  final String releaseNotes;

  factory AppUpdateRelease.fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    final buildNumber = json['buildNumber'];
    final downloadUrl = Uri.tryParse(json['downloadUrl']?.toString() ?? '');
    if (version is! String ||
        !_isValidVersion(version) ||
        buildNumber is! int ||
        buildNumber < 0 ||
        downloadUrl == null ||
        downloadUrl.scheme != 'https' ||
        downloadUrl.host.isEmpty) {
      throw const FormatException('The app update manifest is invalid.');
    }

    return AppUpdateRelease(
      version: version,
      buildNumber: buildNumber,
      downloadUrl: downloadUrl,
      releaseNotes: json['releaseNotes']?.toString() ?? '',
    );
  }

  bool isNewerThan(String installedVersion, String installedBuildNumber) {
    if (!_isValidVersion(installedVersion)) return false;
    final remoteParts = version.split('.').map(int.parse).toList();
    final installedParts = installedVersion.split('.').map(int.parse).toList();
    for (var i = 0; i < remoteParts.length; i++) {
      if (remoteParts[i] != installedParts[i]) {
        return remoteParts[i] > installedParts[i];
      }
    }
    return buildNumber > (int.tryParse(installedBuildNumber) ?? 0);
  }

  static bool _isValidVersion(String value) =>
      RegExp(r'^\d+\.\d+\.\d+$').hasMatch(value);
}

class AppUpdateService {
  AppUpdateService({http.Client? client, Uri? manifestUri})
    : _client = client ?? http.Client(),
      _manifestUri =
          manifestUri ??
          Uri.https('doctor-appointment-2026.web.app', 'app-update.json');

  final http.Client _client;
  final Uri _manifestUri;

  Future<AppUpdateRelease?> checkForUpdate() async {
    final response = await _client
        .get(_manifestUri)
        .timeout(const Duration(seconds: 5));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Update manifest request failed (${response.statusCode}).',
        _manifestUri,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The app update manifest must be an object.');
    }
    final release = AppUpdateRelease.fromJson(decoded);
    final installed = await PackageInfo.fromPlatform();
    return release.isNewerThan(installed.version, installed.buildNumber)
        ? release
        : null;
  }

  void close() => _client.close();
}
