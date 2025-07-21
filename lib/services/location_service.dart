import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../config/supabase_config.dart';
import '../models/user_location.dart';
import '../services/auth_service.dart';
import 'package:uuid/uuid.dart';

class LocationService {
  static StreamSubscription<Position>? _positionStreamSubscription;
  static Timer? _locationUpdateTimer;
  static const int _updateIntervalSeconds = 30;

  

  static Future<bool> requestLocationPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Los servicios de ubicación están deshabilitados');
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Permisos de ubicación denegados');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        //await Geolocator.openAppSettings();
        return false;
      }

      return true;
    } catch (e) {
      print('Error al solicitar permisos de ubicación para background_locator_2: $e');
      return false;
    }
  }



  // Obtener ubicación actual
  static Future<Position?> getCurrentLocation() async {
    try {
      bool hasPermission = await requestLocationPermission();
      if (!hasPermission) return null;

      Position position = await Geolocator.getCurrentPosition();

      return position;
    } catch (e) {
      print('Error al obtener ubicación actual: $e');
      return null;
    }
  }

  // Iniciar tracking de ubicación en tiempo real
  static Future<void> startLocationTracking() async {
    try {
      bool hasPermission = await requestLocationPermission();
      if (!hasPermission) return;

      // Iniciar stream de ubicación
      _positionStreamSubscription = Geolocator.getPositionStream().listen(
        (Position position) async {
          await _saveLocationToDatabase(position);
        },
        onError: (error) {
          print('Error en tracking de ubicación: $error');
        },
      );

      // Timer para actualizaciones periódicas (backup)
      _locationUpdateTimer = Timer.periodic(
        const Duration(seconds: _updateIntervalSeconds),
        (timer) async {
          Position? position = await getCurrentLocation();
          if (position != null) {
            await _saveLocationToDatabase(position);
          }
        },
      );

      print('Tracking de ubicación iniciado');
    } catch (e) {
      print('Error al iniciar tracking: $e');
    }
  }

  // Detener tracking de ubicación
  static void stopLocationTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;

    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;

    print('Tracking de ubicación detenido');
  }

  // Guardar ubicación en la base de datos
  static Future<void> _saveLocationToDatabase(Position position) async {
    try {
      final user = AuthService.currentUser;
      if (user == null) return;

      final userLocation = UserLocation(
        id: const Uuid().v4(),
        userId: user.id,
        latitude: position.latitude,
        longitude: position.longitude,
        altitude: position.altitude,
        accuracy: position.accuracy,
        heading: position.heading,
        speed: position.speed,
        timestamp: DateTime.now(),
        isActive: true,
      );

      // Primero desactivar ubicaciones anteriores
      await SupabaseConfig.client
          .from('user_locations')
          .update({'is_active': false})
          .eq('user_id', user.id);

      // Insertar nueva ubicación
      await SupabaseConfig.client
          .from('user_locations')
          .insert(userLocation.toJson());

      print('Ubicación guardada: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      print('Error al guardar ubicación: $e');
    }
  }

  // Obtener ubicaciones activas del equipo
  static Future<List<UserLocation>> getTeamLocations() async {
    try {
      final user = AuthService.currentUser;
      if (user == null) return [];

      // Obtener el team_id del usuario actual
      final profileResponse = await SupabaseConfig.client
          .from('user_profiles')
          .select('team_id')
          .eq('id', user.id)
          .single();

      final teamId = profileResponse['team_id'];
      if (teamId == null) return [];

      // Obtener ubicaciones activas del equipo
      final response = await SupabaseConfig.client
          .from('user_locations')
          .select('''
            *,
            user_profiles!inner(full_name, team_id)
          ''')
          .eq('is_active', true)
          .eq('user_profiles.team_id', teamId)
          .order('timestamp', ascending: false);

      return response
          .map<UserLocation>((json) => UserLocation.fromJson(json))
          .toList();
    } catch (e) {
      print('Error al obtener ubicaciones del equipo: $e');
      return [];
    }
  }

  // Obtener historial de ubicaciones de un usuario
  static Future<List<UserLocation>> getUserLocationHistory(
    String userId, {
    int limit = 50,
  }) async {
    try {
      final response = await SupabaseConfig.client
          .from('user_locations')
          .select()
          .eq('user_id', userId)
          .order('timestamp', ascending: false)
          .limit(limit);

      return response
          .map<UserLocation>((json) => UserLocation.fromJson(json))
          .toList();
    } catch (e) {
      print('Error al obtener historial de ubicaciones: $e');
      return [];
    }
  }

  // Calcular distancia entre dos puntos
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  // Generar link de geolocalización
  static String generateLocationLink(double latitude, double longitude) {
    return 'https://www.google.com/maps?q=$latitude,$longitude';
  }

  // Generar link de Google Maps con navegación
  static String generateNavigationLink(double latitude, double longitude) {
    return 'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude';
  }

  // Verificar si está dentro de un área (geofencing básico)
  static bool isWithinArea(
    Position currentPosition,
    double centerLat,
    double centerLon,
    double radiusInMeters,
  ) {
    double distance = calculateDistance(
      currentPosition.latitude,
      currentPosition.longitude,
      centerLat,
      centerLon,
    );
    return distance <= radiusInMeters;
  }
}
