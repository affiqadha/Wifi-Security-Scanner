import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:android_intent_plus/android_intent.dart';

Future<bool> checkLocationService(BuildContext context) async {
  final locationService = await Permission.location.serviceStatus;

  if (!locationService.isEnabled) {
    // Open device location settings
    final intent = AndroidIntent(
      action: 'android.settings.LOCATION_SOURCE_SETTINGS',
    );
    await intent.launch();

    // Wait briefly then recheck
    await Future.delayed(Duration(seconds: 3));
    final recheck = await Permission.location.serviceStatus;

    if (!recheck.isEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Location is still OFF. Enable it to scan.'))
      );
      return false;
    }
  }

  return true;
}
