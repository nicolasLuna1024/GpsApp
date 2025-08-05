import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import '../models/user_location.dart';
import '../services/location_service.dart';

// Eventos de ubicación
abstract class LocationEvent {}

class LocationStartTracking extends LocationEvent {}

class LocationStopTracking extends LocationEvent {}

class LocationUpdateRequested extends LocationEvent {}

class LocationTeamMembersRequested extends LocationEvent {}

// Evento para cargar miembros de sesión colaborativa
class LocationCollaborativeSessionMembersRequested extends LocationEvent {
  final String sessionId;
  
  LocationCollaborativeSessionMembersRequested(this.sessionId);
}

class LocationPermissionRequested extends LocationEvent {}

//Para el tracking en tiempo real
class LocationPositionUpdated extends LocationEvent {
  final Position currentPosition;

  LocationPositionUpdated(this.currentPosition);
}

//Para el tracking visual sin guardar en BD
class LocationVisualPositionUpdated extends LocationEvent {
  final Position currentPosition;

  LocationVisualPositionUpdated(this.currentPosition);
}

// Estados de ubicación
abstract class LocationState {}

class LocationInitial extends LocationState {}

class LocationLoading extends LocationState {}

class LocationPermissionDenied extends LocationState {
  final String message;
  LocationPermissionDenied(this.message);
}

class LocationTrackingActive extends LocationState {
  final Position currentPosition;
  final List<UserLocation> teamLocations;

  LocationTrackingActive({
    required this.currentPosition,
    this.teamLocations = const [],
  });
}

class LocationUpdated extends LocationState {
  final Position position;
  final List<UserLocation> teamLocations;

  LocationUpdated({required this.position, this.teamLocations = const []});
}

class LocationError extends LocationState {
  final String message;
  LocationError(this.message);
}

class LocationAlwaysPermission extends LocationState {}

class LocationPermissionNotAllowed extends LocationState {}

// BLoC de ubicación
class LocationBloc extends Bloc<LocationEvent, LocationState> {
  //Para el tracking en tiempo real CON ALMACENAJE EN BD
  bool _isTracking = false;

  //Para el tracking visual cuando no está guardando en BD
  StreamSubscription<Position>? _visualTrackingSubscription;

  //Timer para actualizaciones periódicas del estado visual
  Timer? _visualUpdateTimer;

  LocationBloc() : super(LocationInitial()) {
    on<LocationPermissionRequested>(_onPermissionRequested);
    on<LocationStartTracking>(_onStartTracking);
    on<LocationStopTracking>(_onStopTracking);
    on<LocationUpdateRequested>(_onUpdateRequested);
    on<LocationTeamMembersRequested>(_onTeamMembersRequested);
    on<LocationCollaborativeSessionMembersRequested>(
      _onCollaborativeSessionMembersRequested,
    );

    on<LocationPositionUpdated>((event, emit) async {
      // Verificar si hay sesión colaborativa activa
      final activeSessionId = LocationService.getActiveCollaborativeSession();
      
      final teamLocations = activeSessionId != null
          ? await LocationService.getCollaborativeSessionLocations(activeSessionId)
          : await LocationService.getTeamLocations();

      emit(
        LocationTrackingActive(
          currentPosition: event.currentPosition,
          teamLocations: teamLocations,
        ),
      );
    });

    on<LocationVisualPositionUpdated>((event, emit) async {
      // Verificar si hay sesión colaborativa activa
      final activeSessionId = LocationService.getActiveCollaborativeSession();
      
      final teamLocations = activeSessionId != null
          ? await LocationService.getCollaborativeSessionLocations(activeSessionId)
          : await LocationService.getTeamLocations();

      emit(
        LocationUpdated(
          position: event.currentPosition,
          teamLocations: teamLocations,
        ),
      );
    });
  }

  Future<void> _onPermissionRequested(
    LocationPermissionRequested event,
    Emitter<LocationState> emit,
  ) async {
    emit(LocationLoading());

    try {
      final permission = await Geolocator.checkPermission();

      final hasPermission = await LocationService.requestLocationPermission();

      if (hasPermission && permission != LocationPermission.always) {
        emit(LocationAlwaysPermission());
      } else if (hasPermission && permission == LocationPermission.always) {
        final position = await LocationService.getCurrentLocation();
        if (position != null) {
          // Verificar si hay sesión colaborativa activa
          final activeSessionId = LocationService.getActiveCollaborativeSession();
          
          final teamLocations = activeSessionId != null
              ? await LocationService.getCollaborativeSessionLocations(activeSessionId)
              : await LocationService.getTeamLocations();

          // Iniciar tracking visual automáticamente
          _startVisualTracking();

          emit(
            LocationUpdated(position: position, teamLocations: teamLocations),
          );
        } else {
          emit(LocationError('No se pudo obtener la ubicación actual'));
        }
      } else {
        emit(
          LocationPermissionDenied(
            'Se necesitan permisos de ubicación para usar esta función',
          ),
        );
      }
    } catch (e) {
      emit(LocationError('Error al solicitar permisos: $e'));
    }
  }

  Timer? _dbSaveTimer;
  Timer? _trackingUpdateTimer;

  Future<void> _onStartTracking(
    LocationStartTracking event,
    Emitter<LocationState> emit,
  ) async {
    if (_isTracking) return;

    final permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.always) {
      emit(LocationAlwaysPermission());
      return;
    }

    emit(LocationLoading());

    _isTracking = true;

    // Detener tracking visual ya que ahora usaremos tracking con BD
    _stopVisualTracking();

    try {
      // Iniciar sin stream automático - solo por timers controlados
      Position? latestPosition;
      
      // Obtener posición inicial
      latestPosition = await LocationService.getCurrentLocation();
      if (latestPosition != null) {
        add(LocationPositionUpdated(latestPosition));
      }

      // Guarda cada 15 segundos capturando la posición actual y enviando a BD
      _dbSaveTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
        if (_isTracking) {
          try {
            final currentPosition = await LocationService.getCurrentLocation();
            if (currentPosition != null) {
              await LocationService.saveLocationToDatabase(currentPosition);
              print(
                'Ubicación capturada y enviada a BD: ${currentPosition.latitude}, ${currentPosition.longitude}',
              );
            }
          } catch (e) {
            print('Error capturando ubicación para BD: $e');
          }
        }
      });

      // Timer para actualizaciones de UI cada 5 segundos (capturar y mostrar ícono)
      _trackingUpdateTimer = Timer.periodic(const Duration(seconds: 5), (
        _,
      ) async {
        if (_isTracking) {
          try {
            // Capturar posición actual y actualizar UI
            final currentPosition = await LocationService.getCurrentLocation();
            if (currentPosition != null) {
              add(LocationPositionUpdated(currentPosition));
            }
          } catch (e) {
            print('Error en actualización periódica de tracking: $e');
          }
        }
      });

      // Iniciar tracking en segundo plano después de un pequeño delay
      Future.delayed(Duration(seconds: 3), () async {
        if (_isTracking) {
          await LocationService.startBackgroundLocationTracking();
        }
      });
    } catch (e) {
      print('Error al iniciar tracking: $e');
      _isTracking = false;
      _dbSaveTimer?.cancel();
      _trackingUpdateTimer?.cancel();
      // Ya no hay positionSubscription que cancelar

      emit(LocationError('Error al iniciar tracking: $e'));

      // Volver al tracking visual
      final position = await LocationService.getCurrentLocation();
      if (position != null) {
        final teamLocations = await LocationService.getTeamLocations();
        _startVisualTracking();
        emit(LocationUpdated(position: position, teamLocations: teamLocations));
      }
    }
  }

  Future<void> _onStopTracking(
    LocationStopTracking event,
    Emitter<LocationState> emit,
  ) async {
    try {
      LocationService.stopLocationTracking();
      _isTracking = false;
      _dbSaveTimer?.cancel();
      _trackingUpdateTimer?.cancel();
      // Ya no hay positionSubscription que cancelar
      // Detener tracking en segundo plano
      await LocationService.stopBackgroundLocationTracking();

      // Limpiar registros de BD del usuario
      await LocationService.deactivateUserLocations();

      var position = await LocationService.getCurrentLocation();
      if (position != null) {
        // Verificar si hay sesión colaborativa activa
        final activeSessionId = LocationService.getActiveCollaborativeSession();
        
        var teamLocations = activeSessionId != null
            ? await LocationService.getCollaborativeSessionLocations(activeSessionId)
            : await LocationService.getTeamLocations();

        // Mantener el tracking visual
        if (_visualTrackingSubscription == null) {
          _startVisualTracking();
        }

        emit(LocationUpdated(position: position, teamLocations: teamLocations));
      }
    } catch (e) {
      emit(LocationError('Error al detener tracking: $e'));
    }
  }

  Future<void> _onUpdateRequested(
    LocationUpdateRequested event,
    Emitter<LocationState> emit,
  ) async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always) {
        emit(LocationAlwaysPermission());
        return;
      }

      final position = await LocationService.getCurrentLocation();
      if (position != null) {
        // Verificar si hay sesión colaborativa activa
        final activeSessionId = LocationService.getActiveCollaborativeSession();
        
        final teamLocations = activeSessionId != null
            ? await LocationService.getCollaborativeSessionLocations(activeSessionId)
            : await LocationService.getTeamLocations();

        // Si no está haciendo tracking con BD, asegurar que el visual esté activo
        if (!_isTracking && _visualTrackingSubscription == null) {
          _startVisualTracking();
        }

        emit(LocationUpdated(position: position, teamLocations: teamLocations));
      }
    } catch (e) {
      emit(LocationError('Error al actualizar ubicación: $e'));
    }
  }

  Future<void> _onTeamMembersRequested(
    LocationTeamMembersRequested event,
    Emitter<LocationState> emit,
  ) async {
    try {
      // Verificar si hay sesión colaborativa activa
      final activeSessionId = LocationService.getActiveCollaborativeSession();
      
      final teamLocations = activeSessionId != null
          ? await LocationService.getCollaborativeSessionLocations(activeSessionId)
          : await LocationService.getTeamLocations();

      if (state is LocationTrackingActive) {
        final currentState = state as LocationTrackingActive;
        emit(
          LocationTrackingActive(
            currentPosition: currentState.currentPosition,
            teamLocations: teamLocations,
          ),
        );
      } else if (state is LocationUpdated) {
        final currentState = state as LocationUpdated;
        emit(
          LocationUpdated(
            position: currentState.position,
            teamLocations: teamLocations,
          ),
        );
      }
    } catch (e) {
      emit(LocationError('Error al obtener ubicaciones del equipo: $e'));
    }
  }

  // Handler para cargar miembros de sesión colaborativa
  Future<void> _onCollaborativeSessionMembersRequested(
    LocationCollaborativeSessionMembersRequested event,
    Emitter<LocationState> emit,
  ) async {
    try {
      final sessionLocations = await LocationService.getCollaborativeSessionLocations(
        event.sessionId,
      );

      if (state is LocationTrackingActive) {
        final currentState = state as LocationTrackingActive;
        emit(
          LocationTrackingActive(
            currentPosition: currentState.currentPosition,
            teamLocations: sessionLocations, // Usar ubicaciones de sesión colaborativa
          ),
        );
      } else if (state is LocationUpdated) {
        final currentState = state as LocationUpdated;
        emit(
          LocationUpdated(
            position: currentState.position,
            teamLocations: sessionLocations, // Usar ubicaciones de sesión colaborativa
          ),
        );
      }
      
      print('Ubicaciones de sesión colaborativa cargadas: ${sessionLocations.length}');
    } catch (e) {
      emit(LocationError('Error al obtener ubicaciones de sesión colaborativa: $e'));
    }
  }

  bool get isTracking => _isTracking;

  // Iniciar tracking visual sin guardar en BD
  void _startVisualTracking() {
    if (_isTracking) return; // No iniciar visual si ya está el tracking con BD

    _visualTrackingSubscription?.cancel();
    _visualUpdateTimer?.cancel();

    // Ya no usar stream automático - solo timer controlado de 5 segundos

    // Timer para actualizaciones visuales cada 5 segundos (sin tracking)
    _visualUpdateTimer = Timer.periodic(Duration(seconds: 5), (_) async {
      if (!_isTracking) {
        try {
          final position = await LocationService.getCurrentLocation();
          if (position != null) {
            add(LocationVisualPositionUpdated(position));
          }
        } catch (e) {
          print('Error en actualización periódica visual: $e');
        }
      }
    });
  }

  // Detener tracking visual
  void _stopVisualTracking() {
    _visualTrackingSubscription?.cancel();
    _visualTrackingSubscription = null;
    _visualUpdateTimer?.cancel();
    _visualUpdateTimer = null;
  }

  @override
  Future<void> close() {
    if (_isTracking) {
      LocationService.stopLocationTracking();
    }
    _dbSaveTimer?.cancel();
    _trackingUpdateTimer?.cancel();
    _stopVisualTracking();
    return super.close();
  }
}
