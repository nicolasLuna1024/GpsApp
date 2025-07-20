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
class LocationTrackingInRealTime extends LocationEvent {}














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


























// BLoC de ubicación
class LocationBloc extends Bloc<LocationEvent, LocationState> {
  bool _isTracking = false;

  LocationBloc() : super(LocationInitial()) {
    on<LocationPermissionRequested>(_onPermissionRequested);
    on<LocationStartTracking>(_onStartTracking);
    on<LocationStopTracking>(_onStopTracking);
    on<LocationUpdateRequested>(_onUpdateRequested);
    on<LocationTeamMembersRequested>(_onTeamMembersRequested);


    //Asociación del evento disparado a la función a ejecutar
    //on<LocationTrackingInRealTime>(_trackingInRealTime);
  }

  Future<void> _onPermissionRequested(
    LocationPermissionRequested event,
    Emitter<LocationState> emit,
  ) async {
    emit(LocationLoading());

    try {
      final hasPermission = await LocationService.requestLocationPermission();

      if (hasPermission) {
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

  Future<void> _onStartTracking(
    LocationStartTracking event,
    Emitter<LocationState> emit,
  ) async {
    if (_isTracking) return;

    emit(LocationLoading());

    try {
      final hasPermission = await LocationService.requestLocationPermission();

      if (!hasPermission) {
        emit(
          LocationPermissionDenied(
            'Se necesitan permisos de ubicación para iniciar el tracking',
          ),
        );
        return;
      }

      await LocationService.startLocationTracking();
      _isTracking = true;


      while (_isTracking == true)
      {
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

        await Future.delayed(const Duration(seconds: 5));
      }
    } catch (e) {
      emit(LocationError('Error al iniciar tracking: $e'));
    }
  }

/*
  Future<void> _trackingInRealTime(LocationTrackingInRealTime event, Emitter<LocationState> emit) async
  {
    try
    {
      if (_isTracking) return;
      emit(LocationLoading());

       _isTracking = true;

      final position = await LocationService.getCurrentLocation();
      if (position != null) {
        final teamLocations = await LocationService.getTeamLocations();
        emit(
          LocationTrackingActive(
            currentPosition: position,
            teamLocations: teamLocations,
          ),
        );
      }
    }catch(e)
    {
      emit(LocationError('Error durante el tracking: $e'));
    }
  }*/

  Future<void> _onStopTracking(
    LocationStopTracking event,
    Emitter<LocationState> emit,
  ) async {
    try {
      LocationService.stopLocationTracking();
      _isTracking = false;

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

    //  emit(LocationInitial());
    } catch (e) {
      emit(LocationError('Error al detener tracking: $e'));
    }
  }

  Future<void> _onUpdateRequested(
    LocationUpdateRequested event,
    Emitter<LocationState> emit,
  ) async {
    try {
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
