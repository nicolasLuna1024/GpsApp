import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/terrain.dart';
import '../services/terrain_service.dart';

// Eventos del terreno
abstract class TerrainEvent {}

class TerrainLoadUserTerrains extends TerrainEvent {}

class TerrainLoadTeamTerrains extends TerrainEvent {
  final String teamId;
  TerrainLoadTeamTerrains(this.teamId);
}

class TerrainCreate extends TerrainEvent {
  final String name;
  final String? description;
  final List<TerrainPoint> points;
  final String? teamId;

  TerrainCreate({
    required this.name,
    this.description,
    required this.points,
    this.teamId,
  });
}

class TerrainUpdate extends TerrainEvent {
  final String terrainId;
  final String? name;
  final String? description;
  final List<TerrainPoint>? points;

  TerrainUpdate({
    required this.terrainId,
    this.name,
    this.description,
    this.points,
  });
}

class TerrainDelete extends TerrainEvent {
  final String terrainId;
  TerrainDelete(this.terrainId);
}

class TerrainLoadStats extends TerrainEvent {}

class TerrainClearCurrentPoints extends TerrainEvent {}

class TerrainAddPoint extends TerrainEvent {
  final TerrainPoint point;
  TerrainAddPoint(this.point);
}

class TerrainRemoveLastPoint extends TerrainEvent {}

// Estados del terreno
abstract class TerrainState {}

class TerrainInitial extends TerrainState {}

class TerrainLoading extends TerrainState {}

class TerrainLoaded extends TerrainState {
  final List<Terrain> terrains;
  final Map<String, dynamic> stats;
  final List<TerrainPoint> currentPoints;

  TerrainLoaded({
    this.terrains = const [],
    this.stats = const {},
    this.currentPoints = const [],
  });

  TerrainLoaded copyWith({
    List<Terrain>? terrains,
    Map<String, dynamic>? stats,
    List<TerrainPoint>? currentPoints,
  }) {
    return TerrainLoaded(
      terrains: terrains ?? this.terrains,
      stats: stats ?? this.stats,
      currentPoints: currentPoints ?? this.currentPoints,
    );
  }
}

class TerrainSuccess extends TerrainState {
  final String message;
  TerrainSuccess(this.message);
}

class TerrainError extends TerrainState {
  final String message;
  TerrainError(this.message);
}

// BLoC del terreno
class TerrainBloc extends Bloc<TerrainEvent, TerrainState> {
  TerrainBloc() : super(TerrainInitial()) {
    on<TerrainLoadUserTerrains>(_onLoadUserTerrains);
    on<TerrainLoadTeamTerrains>(_onLoadTeamTerrains);
    on<TerrainCreate>(_onCreateTerrain);
    on<TerrainUpdate>(_onUpdateTerrain);
    on<TerrainDelete>(_onDeleteTerrain);
    on<TerrainLoadStats>(_onLoadStats);
    on<TerrainClearCurrentPoints>(_onClearCurrentPoints);
    on<TerrainAddPoint>(_onAddPoint);
    on<TerrainRemoveLastPoint>(_onRemoveLastPoint);
  }

  Future<void> _onLoadUserTerrains(
    TerrainLoadUserTerrains event,
    Emitter<TerrainState> emit,
  ) async {
    try {
      emit(TerrainLoading());

      final terrains = await TerrainService.getUserTerrains();
      final stats = await TerrainService.getTerrainStats();

      final currentState = state is TerrainLoaded
          ? state as TerrainLoaded
          : TerrainLoaded();

      emit(currentState.copyWith(terrains: terrains, stats: stats));
    } catch (e) {
      emit(TerrainError('Error al cargar terrenos: $e'));
    }
  }

  Future<void> _onLoadTeamTerrains(
    TerrainLoadTeamTerrains event,
    Emitter<TerrainState> emit,
  ) async {
    try {
      emit(TerrainLoading());

      final terrains = await TerrainService.getTeamTerrains(event.teamId);

      final currentState = state is TerrainLoaded
          ? state as TerrainLoaded
          : TerrainLoaded();

      emit(currentState.copyWith(terrains: terrains));
    } catch (e) {
      emit(TerrainError('Error al cargar terrenos del equipo: $e'));
    }
  }

  Future<void> _onCreateTerrain(
    TerrainCreate event,
    Emitter<TerrainState> emit,
  ) async {
    try {
      if (event.points.length < 3) {
        emit(
          TerrainError('Se necesitan al menos 3 puntos para crear un terreno'),
        );
        return;
      }

      emit(TerrainLoading());

      final success = await TerrainService.createTerrain(
        name: event.name,
        description: event.description,
        points: event.points,
        teamId: event.teamId,
      );

      if (success) {
        // Emitir éxito
        emit(TerrainSuccess('Terreno creado exitosamente'));

        // Recargar terrenos automáticamente después del éxito
        try {
          await Future.delayed(const Duration(milliseconds: 500));

          final terrains = await TerrainService.getUserTerrains();
          final stats = await TerrainService.getTerrainStats();

          emit(
            TerrainLoaded(
              terrains: terrains,
              stats: stats,
              currentPoints: [], // Limpiar puntos después de guardar
            ),
          );
        } catch (e) {
          print('Error al recargar terrenos: $e');
          emit(TerrainLoaded(currentPoints: [])); // Al menos limpiar puntos
        }
      } else {
        // Mantener el estado actual con los puntos
        final currentState = state is TerrainLoaded
            ? state as TerrainLoaded
            : TerrainLoaded();

        emit(TerrainError('Error al crear terreno'));
        emit(currentState); // Volver al estado anterior
      }
    } catch (e) {
      print('Error detallado al crear terreno: $e');

      // Mantener el estado actual con los puntos
      final currentState = state is TerrainLoaded
          ? state as TerrainLoaded
          : TerrainLoaded();

      emit(TerrainError('Error al crear terreno: ${e.toString()}'));
      emit(currentState); // Volver al estado anterior
    }
  }

  Future<void> _onUpdateTerrain(
    TerrainUpdate event,
    Emitter<TerrainState> emit,
  ) async {
    try {
      final success = await TerrainService.updateTerrain(
        terrainId: event.terrainId,
        name: event.name,
        description: event.description,
        points: event.points,
      );

      if (success) {
        emit(TerrainSuccess('Terreno actualizado exitosamente'));
        add(TerrainLoadUserTerrains());
      } else {
        emit(TerrainError('Error al actualizar terreno'));
      }
    } catch (e) {
      emit(TerrainError('Error al actualizar terreno: $e'));
    }
  }

  Future<void> _onDeleteTerrain(
    TerrainDelete event,
    Emitter<TerrainState> emit,
  ) async {
    try {
      final success = await TerrainService.deleteTerrain(event.terrainId);

      if (success) {
        emit(TerrainSuccess('Terreno eliminado exitosamente'));
        add(TerrainLoadUserTerrains());
      } else {
        emit(TerrainError('Error al eliminar terreno'));
      }
    } catch (e) {
      emit(TerrainError('Error al eliminar terreno: $e'));
    }
  }

  Future<void> _onLoadStats(
    TerrainLoadStats event,
    Emitter<TerrainState> emit,
  ) async {
    try {
      final stats = await TerrainService.getTerrainStats();

      final currentState = state is TerrainLoaded
          ? state as TerrainLoaded
          : TerrainLoaded();

      emit(currentState.copyWith(stats: stats));
    } catch (e) {
      emit(TerrainError('Error al cargar estadísticas: $e'));
    }
  }

  void _onClearCurrentPoints(
    TerrainClearCurrentPoints event,
    Emitter<TerrainState> emit,
  ) {
    // Siempre emitir un estado TerrainLoaded con puntos vacíos
    if (state is TerrainLoaded) {
      final currentState = state as TerrainLoaded;
      emit(currentState.copyWith(currentPoints: []));
    } else {
      // Si no tenemos un estado TerrainLoaded, crear uno nuevo
      emit(TerrainLoaded(currentPoints: []));
    }
  }

  void _onAddPoint(TerrainAddPoint event, Emitter<TerrainState> emit) {
    List<TerrainPoint> currentPoints = [];
    TerrainLoaded currentState;

    if (state is TerrainLoaded) {
      currentState = state as TerrainLoaded;
      currentPoints = List<TerrainPoint>.from(currentState.currentPoints);
    } else {
      currentState = TerrainLoaded();
    }

    currentPoints.add(event.point);
    emit(currentState.copyWith(currentPoints: currentPoints));
  }

  void _onRemoveLastPoint(
    TerrainRemoveLastPoint event,
    Emitter<TerrainState> emit,
  ) {
    if (state is TerrainLoaded) {
      final currentState = state as TerrainLoaded;

      if (currentState.currentPoints.isNotEmpty) {
        final newPoints = List<TerrainPoint>.from(currentState.currentPoints)
          ..removeLast();

        emit(currentState.copyWith(currentPoints: newPoints));
      }
    } else {
      // Si no hay estado TerrainLoaded, crear uno vacío
      emit(TerrainLoaded(currentPoints: []));
    }
  }
}
