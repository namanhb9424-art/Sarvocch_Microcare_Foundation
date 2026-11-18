import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationResult {
  final double? latitude;
  final double? longitude;
  final bool isRealGps;
  final String? errorMessage;

  LocationResult({
    required this.latitude,
    required this.longitude,
    required this.isRealGps,
    this.errorMessage,
  });
}

class LocationService {
  static final LocationService instance = LocationService._internal();
  LocationService._internal();

  Future<LocationResult> getCurrentCoordinates() async {
    // Desktop platforms and browsers cannot provide production attendance GPS.
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux) {
      return LocationResult(
        latitude: null,
        longitude: null,
        isRealGps: false,
        errorMessage: 'Live device GPS is unavailable on this platform. Attendance was not recorded.',
      );
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationResult(
          latitude: null,
          longitude: null,
          isRealGps: false,
          errorMessage: 'Device location services are disabled. Please enable GPS in device settings.',
        );
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return LocationResult(
            latitude: null,
            longitude: null,
            isRealGps: false,
            errorMessage: 'Location permission denied by user.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationResult(
          latitude: null,
          longitude: null,
          isRealGps: false,
          errorMessage: 'Location permissions are permanently denied. Please enable via Android App Settings.',
        );
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      return LocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
        isRealGps: true,
      );
    } catch (_) {
      debugPrint('Device location could not be acquired.');
      return LocationResult(
        latitude: null,
        longitude: null,
        isRealGps: false,
        errorMessage: 'Error acquiring device GPS.',
      );
    }
  }
}
