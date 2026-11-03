import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationResult {
  final double latitude;
  final double longitude;
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

  /// Default benchmark branch coordinates for desktop development & unit testing
  static const double fallbackLat = 22.7533;
  static const double fallbackLng = 75.8937;

  Future<LocationResult> getCurrentCoordinates() async {
    // Desktop platforms or test runners without native location platform channels
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.macOS || 
        defaultTargetPlatform == TargetPlatform.windows || 
        defaultTargetPlatform == TargetPlatform.linux) {
      return LocationResult(
        latitude: fallbackLat,
        longitude: fallbackLng,
        isRealGps: false,
        errorMessage: 'Desktop environment: using reference branch GPS coordinates.',
      );
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationResult(
          latitude: fallbackLat,
          longitude: fallbackLng,
          isRealGps: false,
          errorMessage: 'Device location services are disabled. Please enable GPS in device settings.',
        );
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return LocationResult(
            latitude: fallbackLat,
            longitude: fallbackLng,
            isRealGps: false,
            errorMessage: 'Location permission denied by user.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationResult(
          latitude: fallbackLat,
          longitude: fallbackLng,
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
    } catch (e) {
      debugPrint('Location acquisition error: $e');
      return LocationResult(
        latitude: fallbackLat,
        longitude: fallbackLng,
        isRealGps: false,
        errorMessage: 'Error acquiring device GPS: $e',
      );
    }
  }
}

