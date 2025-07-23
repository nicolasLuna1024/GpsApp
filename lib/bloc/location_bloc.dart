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

class LocationPermissionRequested extends LocationEvent {}


//Para el tracking en tiempo real
class LocationPositionUpdated extends LocationEvent {
  final currentPosition;

  LocationPositionUpdated(this.currentPosition);
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

  //Para el tracking en tiempo real SIN ALMACENAJE EN BD
  StreamSubscription<Position>? _positionSubscription;


  LocationBloc() : super(LocationInitial()) {
    on<LocationPermissionRequested>(_onPermissionRequested);
    on<LocationStartTracking>(_onStartTracking);
    on<LocationStopTracking>(_onStopTracking);
    on<LocationUpdateRequested>(_onUpdateRequested);
    on<LocationTeamMembersRequested>(_onTeamMembersRequested);


    on<LocationPositionUpdated>((event, emit) async {
      final teamLocations = await LocationService.getTeamLocations();

      emit(LocationTrackingActive(
        currentPosition: event.currentPosition,
        teamLocations: teamLocations,
      ));
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
      }
      else if (hasPermission && permission == LocationPermission.always) {
        final position = await LocationService.getCurrentLocation();
        if (position != null) {
          final teamLocations = await LocationService.getTeamLocations();
          emit(
            LocationTrackingActive(
              currentPosition: position,
              teamLocations: teamLocations,
            ),
          );
        } else {
          emit(LocationError('No se pudo obtener la ubicación actual'));
        }
      } 
      else {
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

  Future<void> _onStartTracking(
    LocationStartTracking event,
    Emitter<LocationState> emit,
  ) async {
    if (_isTracking) return;

    final permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.always)
    {
      emit(LocationAlwaysPermission());
      return;
    }

    emit(LocationLoading());

    /*
    final hasPermission = await LocationService.requestLocationPermission();
    if (!hasPermission) {
      emit(LocationPermissionDenied(
          'Se necesitan permisos de ubicación para iniciar el tracking'));
      return;
    }*/

    _isTracking = true;

    Position? latestPosition;

    _positionSubscription = LocationService.positionStream.listen(
      (position) {
        latestPosition = position;
        add(LocationPositionUpdated(position));
      },
      onError: (error) {
        emit(LocationError(error.toString()));
      },
    );

    // Guarda cada 20 segundos la ubicación actual
    _dbSaveTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      if (latestPosition != null) {
        await LocationService.saveLocationToDatabase(latestPosition!);
      }
    });
  }


  Future<void> _onStopTracking(
    LocationStopTracking event,
    Emitter<LocationState> emit,
  ) async {
    try {
      LocationService.stopLocationTracking();
      _isTracking = false;
      _dbSaveTimer?.cancel();
      await _positionSubscription?.cancel();
      _positionSubscription = null;
      var position = await LocationService.getCurrentLocation();
      if (position != null) {
        var teamLocations = await LocationService.getTeamLocations();
        emit(
          LocationTrackingActive(
            currentPosition: position,
            teamLocations: teamLocations,
          ),
        );
      }

    //emit(LocationInitial());
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
      if (permission != LocationPermission.always)
      {
        emit(LocationAlwaysPermission());
        return;
      }

      final position = await LocationService.getCurrentLocation();
      if (position != null) {
        final teamLocations = await LocationService.getTeamLocations();
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
      final teamLocations = await LocationService.getTeamLocations();

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

  bool get isTracking => _isTracking;

  @override
  Future<void> close() {
    if (_isTracking) {
      LocationService.stopLocationTracking();
    }
    return super.close();
  }
}
