import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class Locator {
  /// Request foreground then background location (required order on Android 11+).
  static Future<bool> ensurePermissions() async {
    final fg = await Permission.locationWhenInUse.request();
    if (!fg.isGranted) return false;
    final bg = await Permission.locationAlways.request();
    if (!bg.isGranted) return false;
    if (!await Geolocator.isLocationServiceEnabled()) {
      await Geolocator.openLocationSettings();
    }
    return true;
  }

  /// High-frequency GPS stream. 2s / 10m throttle keeps Firestore writes cheap.
  static Stream<Position> positions() => Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 10,
        ),
      );
}
