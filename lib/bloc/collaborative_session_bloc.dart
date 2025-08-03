import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/collaborative_session.dart';
import '../services/collaborative_session_service.dart';
import '../services/location_service.dart';

// Eventos del BLoC de Sesiones Colaborativas
abstract class CollaborativeSessionEvent {}

class CollaborativeSessionsLoadRequested extends CollaborativeSessionEvent {}

class CollaborativeSessionCreateRequested extends CollaborativeSessionEvent {
  final String name;
  final String? description;
  final String teamId;

  CollaborativeSessionCreateRequested({
    required this.name,
    this.description,
    required this.teamId,
  });
}

class CollaborativeSessionJoinRequested extends CollaborativeSessionEvent {
  final String sessionId;

  CollaborativeSessionJoinRequested(this.sessionId);
}

class CollaborativeSessionEndRequested extends CollaborativeSessionEvent {
  final String sessionId;

  CollaborativeSessionEndRequested(this.sessionId);
}

class CollaborativeSessionWatchStarted extends CollaborativeSessionEvent {}

class CollaborativeSessionWatchStopped extends CollaborativeSessionEvent {}

// Estados del BLoC de Sesiones Colaborativas
abstract class CollaborativeSessionState {}

class CollaborativeSessionInitial extends CollaborativeSessionState {}

class CollaborativeSessionLoading extends CollaborativeSessionState {}

class CollaborativeSessionLoaded extends CollaborativeSessionState {
  final List<CollaborativeSession> sessions;
  final CollaborativeSession? activeSession;

  CollaborativeSessionLoaded({this.sessions = const [], this.activeSession});
}

class CollaborativeSessionJoined extends CollaborativeSessionState {
  final CollaborativeSession session;

  CollaborativeSessionJoined(this.session);
}

class CollaborativeSessionOperationSuccess extends CollaborativeSessionState {
  final String message;
  final List<CollaborativeSession> sessions;
  final CollaborativeSession? activeSession;

  CollaborativeSessionOperationSuccess({
    required this.message,
    this.sessions = const [],
    this.activeSession,
  });
}

class CollaborativeSessionError extends CollaborativeSessionState {
  final String message;

  CollaborativeSessionError(this.message);
}

class CollaborativeSessionTerminated extends CollaborativeSessionState {
  final String message;
  final List<CollaborativeSession> sessions;

  CollaborativeSessionTerminated({
    required this.message,
    this.sessions = const [],
  });
}

// 🆕 Global CollaborativeSessionBloc Instance
class CollaborativeSessionBloc
    extends Bloc<CollaborativeSessionEvent, CollaborativeSessionState> {
  final CollaborativeSessionService _sessionService =
      CollaborativeSessionService();

  // Constructor normal
  CollaborativeSessionBloc() : super(CollaborativeSessionInitial()) {
    on<CollaborativeSessionsLoadRequested>(_onSessionsLoadRequested);
    on<CollaborativeSessionCreateRequested>(_onSessionCreateRequested);
    on<CollaborativeSessionJoinRequested>(_onSessionJoinRequested);
    on<CollaborativeSessionEndRequested>(_onSessionEndRequested);
    on<CollaborativeSessionWatchStarted>(_onWatchStarted);
    on<CollaborativeSessionWatchStopped>(_onWatchStopped);
  }

  Future<void> _onSessionsLoadRequested(
    CollaborativeSessionsLoadRequested event,
    Emitter<CollaborativeSessionState> emit,
  ) async {
    try {
      if (isClosed) return;
      emit(CollaborativeSessionLoading());

      final sessions = await _sessionService.getUserTeamSessions();

      if (!isClosed) {
        emit(CollaborativeSessionLoaded(sessions: sessions));
      }
    } catch (e) {
      if (!isClosed) {
        emit(
          CollaborativeSessionError('Error cargando sesiones: ${e.toString()}'),
        );
      }
    }
  }

  Future<void> _onSessionCreateRequested(
    CollaborativeSessionCreateRequested event,
    Emitter<CollaborativeSessionState> emit,
  ) async {
    try {
      if (isClosed) return;
      emit(CollaborativeSessionLoading());

      await _sessionService.createSession(
        name: event.name,
        description: event.description,
        teamId: event.teamId,
      );

      if (!isClosed) {
        final sessions = await _sessionService.getUserTeamSessions();
        final activeSession = await _sessionService.getUserActiveSession();

        emit(
          CollaborativeSessionOperationSuccess(
            message: 'Sesión "${event.name}" creada exitosamente',
            sessions: sessions,
            activeSession: activeSession,
          ),
        );

        if (activeSession != null) {
          // 🆕 Configurar sesión activa en LocationService al crear
          LocationService.setActiveCollaborativeSession(activeSession.id);
          emit(CollaborativeSessionJoined(activeSession));
        }
      }
    } catch (e) {
      if (!isClosed) {
        emit(
          CollaborativeSessionError('Error creando sesión: ${e.toString()}'),
        );
      }
    }
  }

  Future<void> _onSessionJoinRequested(
    CollaborativeSessionJoinRequested event,
    Emitter<CollaborativeSessionState> emit,
  ) async {
    try {
      if (isClosed) return;
      emit(CollaborativeSessionLoading());

      final joinResult = await _sessionService.joinSession(event.sessionId);

      if (!isClosed && joinResult) {
        final sessions = await _sessionService.getUserTeamSessions();
        final activeSession = await _sessionService.getUserActiveSession();

        emit(
          CollaborativeSessionOperationSuccess(
            message: 'Te has unido a la sesión exitosamente',
            sessions: sessions,
            activeSession: activeSession,
          ),
        );

        if (activeSession != null) {
          // 🆕 Configurar sesión activa en LocationService al unirse
          LocationService.setActiveCollaborativeSession(activeSession.id);
          emit(CollaborativeSessionJoined(activeSession));
        }
      } else if (!isClosed) {
        emit(CollaborativeSessionError('No se pudo unir a la sesión'));
      }
    } catch (e) {
      if (!isClosed) {
        emit(
          CollaborativeSessionError(
            'Error uniéndose a la sesión: ${e.toString()}',
          ),
        );
      }
    }
  }

  Future<void> _onSessionEndRequested(
    CollaborativeSessionEndRequested event,
    Emitter<CollaborativeSessionState> emit,
  ) async {
    try {
      if (isClosed) return;
      emit(CollaborativeSessionLoading());

      print('🔄 Intentando finalizar sesión: ${event.sessionId}');

      await _sessionService.endSession(event.sessionId);

      print('✅ Sesión finalizada exitosamente en el servidor');

      if (!isClosed) {
        // 🆕 Limpiar sesión activa si es la que se está finalizando
        final currentActiveSession = LocationService.getActiveCollaborativeSession();
        if (currentActiveSession == event.sessionId) {
          LocationService.setActiveCollaborativeSession(null);
          print('🎯 Sesión activa limpiada: ${event.sessionId}');
        }
        
        // Recargar las sesiones
        final sessions = await _sessionService.getUserTeamSessions();

        emit(
          CollaborativeSessionOperationSuccess(
            message: 'Sesión colaborativa finalizada exitosamente',
            sessions: sessions,
          ),
        );

        emit(
          CollaborativeSessionLoaded(sessions: sessions, activeSession: null),
        );

        print('✅ Estados emitidos correctamente');
      }
    } catch (e) {
      print('❌ Error en _onSessionEndRequested: $e');
      if (!isClosed) {
        emit(
          CollaborativeSessionError(
            'Error finalizando sesión: ${e.toString()}',
          ),
        );
      }
    }
  }

  Future<void> _onWatchStarted(
    CollaborativeSessionWatchStarted event,
    Emitter<CollaborativeSessionState> emit,
  ) async {
    await emit.forEach<List<CollaborativeSession>>(
      _sessionService.watchUserTeamSessions(),
      onData: (sessions) => CollaborativeSessionLoaded(sessions: sessions),
      onError: (error, stackTrace) =>
          CollaborativeSessionError('Error en tiempo real: $error'),
    );
  }

  Future<void> _onWatchStopped(
    CollaborativeSessionWatchStopped event,
    Emitter<CollaborativeSessionState> emit,
  ) async {
    // Detener el watching
    // El método emit.forEach se cancelará automáticamente
  }
}

// 🌟 Global instance
late final CollaborativeSessionBloc globalCollaborativeSessionBloc;

void initializeGlobalCollaborativeSessionBloc() {
  globalCollaborativeSessionBloc = CollaborativeSessionBloc();
}
