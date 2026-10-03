import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Checks Firestore `config/app` for a newer APK and installs it.
class Updater {
  static Future<void> check(BuildContext context) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('app')
          .get();
      final data = doc.data();
      if (data == null) return;

      final latest = (data['latestVersion'] as String?) ?? '';
      final url = data['apkUrl'] as String?;
      final notes = data['notes'] as String? ?? '';
      if (latest.isEmpty || url == null) return;

      final info = await PackageInfo.fromPlatform();
      if (_compare(latest, info.version) <= 0) return;
      if (!context.mounted) return;

      final yes = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Update available'),
          content: Text('v$latest is ready.\n\n$notes'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Update'),
            ),
          ],
        ),
      );
      if (yes != true) return;

      final dir = await getExternalStorageDirectory();
      final file = File('${dir!.path}/rallytrack-update.apk');
      await Dio().download(url, file.path);

      // Android package installer picks this up via ACTION_VIEW on the apk.
      await OpenFilex.open(file.path, type: 'application/vnd.android.package-archive');
    } catch (_) {
      // Update checks must never break app startup.
    }
  }

  /// >0 if a is newer than b.
  static int _compare(String a, String b) {
    final pa = a.split('.').map(int.tryParse).toList();
    final pb = b.split('.').map(int.tryParse).toList();
    for (var i = 0; i < 3; i++) {
      final d = (pa[i] ?? 0) - (pb[i] ?? 0);
      if (d != 0) return d;
    }
    return 0;
  }
}
