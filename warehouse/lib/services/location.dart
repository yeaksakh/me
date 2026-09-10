import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Where someone was standing when they clocked in or out, for the attendance
/// record the website keeps beside each punch.
///
/// **Never blocks a punch.** Every failure -- permission refused, location
/// switched off, no fix under a tin roof -- returns null and the clock-in goes
/// through without coordinates. Being late because the phone could not see the
/// sky would be the wrong outcome.
class LocationService {
  const LocationService();

  /// How long to wait for a fix before giving up on it.
  static const _timeout = Duration(seconds: 8);

  /// Overridable so tests can stand in for the platform: under `flutter_test`
  /// there is no location service to answer.
  static Future<({double latitude, double longitude})?> Function() current =
      _fromPlatform;

  static Future<({double latitude, double longitude})?> _fromPlatform() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final fix = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          // A yard does not need the best fix the phone can manage, and asking
          // for one costs seconds at every punch.
          accuracy: LocationAccuracy.medium,
          timeLimit: _timeout,
        ),
      );
      return (latitude: fix.latitude, longitude: fix.longitude);
    } catch (error) {
      debugPrint('No location fix for this punch: $error');
      return null;
    }
  }
}
