import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../config/supabase_config.dart';
import '../models/user_location.dart';
import '../services/auth_service.dart';
import 'package:uuid/uuid.dart';
import 'package:location/location.dart' as loc;

class LocationService {
  static StreamSubscription<Position>? _positionStreamSubscription;
  static Timer? _locationUpdateTimer;
  static const int _updateIntervalSeconds = 30;
  static loc.Location? _backgroundLocation;
  static StreamSubscription<loc.LocationData>? _backgroundLocationSubscription;

  

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

  /// Inicia el tracking en segundo plano usando la librería Location
  static Future<void> startBackgroundLocationTracking() async {
    _backgroundLocation ??= loc.Location();
    bool _serviceEnabled;
    loc.PermissionStatus _permissionGranted;

    _serviceEnabled = await _backgroundLocation!.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await _backgroundLocation!.requestService();
      if (!_serviceEnabled) {
        print('Servicio de ubicación no habilitado para background');
        return;
      }
    }

    _permissionGranted = await _backgroundLocation!.hasPermission();
    if (_permissionGranted == loc.PermissionStatus.denied) {
      _permissionGranted = await _backgroundLocation!.requestPermission();
      if (_permissionGranted != loc.PermissionStatus.granted && _permissionGranted != loc.PermissionStatus.grantedLimited) {
        print('Permiso de ubicación no concedido para background');
        return;
      }
    }

    // Configura para background
    await _backgroundLocation!.enableBackgroundMode(enable: true);
    _backgroundLocation!.changeSettings(
      accuracy:  loc.LocationAccuracy.high,
      interval: 20000, // 20 segundos
      distanceFilter: 0,
    );

    _backgroundLocationSubscription = _backgroundLocation!.onLocationChanged.listen((loc.LocationData data) async {
      if (data.latitude != null && data.longitude != null) {
        // Convierte LocationData a Position-like para reutilizar el guardado
        final position = Position(
          latitude: data.latitude!,
          longitude: data.longitude!,
          timestamp: DateTime.now(),
          accuracy: data.accuracy ?? 0.0,
          altitude: data.altitude ?? 0.0,
          heading: data.heading ?? 0.0,
          speed: data.speed ?? 0.0,
          speedAccuracy: data.speedAccuracy ?? 0.0,
          altitudeAccuracy: data.verticalAccuracy ?? 0.0,
          headingAccuracy: data.headingAccuracy ?? 0.0
        );
        await saveLocationToDatabase(position);
      }
    });
    print('Tracking en segundo plano iniciado');
  }

  /// Detiene el tracking en segundo plano
  static Future<void> stopBackgroundLocationTracking() async {
    await _backgroundLocationSubscription?.cancel();
    _backgroundLocationSubscription = null;
    if (_backgroundLocation != null) {
      await _backgroundLocation!.enableBackgroundMode(enable: false);
    }
    print('Tracking en segundo plano detenido');
  }




  // Exponer el stream de ubicación directamente
  static Stream<Position> get positionStream => Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 1, // Sensibilidad alta (1m mínimo)
    ),
  );


















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

  // Guardar ubicación en la base de datos
  static Future<void> saveLocationToDatabase(Position position) async {
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


      final seleccion = await SupabaseConfig.client
          .from('user_locations')
          .select()
          .eq('user_id', user.id)
          .eq('is_active', true);

      print("Ubicaciones seleccionadas: $seleccion");


      
      // Primero desactivar ubicaciones anteriores
      await SupabaseConfig.client
      .from('user_locations')
      .update({'is_active': false})
      .eq('user_id', user.id)
      .eq('is_active', true);

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
