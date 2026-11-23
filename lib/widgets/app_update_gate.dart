import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_update_service.dart';
import '../theme/app_theme.dart';

class AppUpdateGate extends StatefulWidget {
  const AppUpdateGate({super.key, required this.child});

  final Widget child;

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdate();
    });
  }

  Future<void> _checkForUpdate() async {
    final service = AppUpdateService();
    try {
      final release = await service.checkForUpdate();
      if (!mounted || release == null) return;

      final shouldOpenDownload = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(
            Icons.system_update_alt_rounded,
            color: AppTheme.primaryBlue,
            size: 32,
          ),
          title: Text('Doctor Care ${release.version} is available'),
          content: Text(
            release.releaseNotes.isEmpty
                ? 'A newer version of Doctor Care is ready to download.'
                : release.releaseNotes,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Get update'),
            ),
          ],
        ),
      );
      if (shouldOpenDownload == true) {
        final opened = await launchUrl(
          release.downloadUrl,
          mode: LaunchMode.externalApplication,
        );
        if (!opened && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open the update download page.'),
            ),
          );
        }
      }
    } catch (error) {
      debugPrint('App update check failed: $error');
    } finally {
      service.close();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
