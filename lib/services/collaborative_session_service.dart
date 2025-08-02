import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/collaborative_session.dart';
import '../config/supabase_config.dart';

class CollaborativeSessionService {
  static const String _tableName = 'collaborative_sessions';

  final SupabaseClient _client = SupabaseConfig.client;

  // Obtener sesiones activas de los equipos del usuario
  Future<List<CollaborativeSession>> getUserTeamSessions() async {
    try {
      final response = await _client.rpc('get_user_team_sessions');

      if (response == null) return [];

      return (response as List)
          .map((json) => CollaborativeSession.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Error obteniendo sesiones del equipo: $e');
    }
  }

  // Crear una nueva sesión colaborativa
  Future<String> createSession({
    required String name,
    String? description,
    required String teamId,
  }) async {
    try {
      final response = await _client.rpc(
        'create_collaborative_session',
        params: {
          'session_name': name,
          'session_description': description,
          'team_uuid': teamId,
        },
      );

      if (response == null) {
        throw Exception('Error creando la sesión colaborativa');
      }

      return response as String;
    } catch (e) {
      throw Exception('Error creando sesión colaborativa: $e');
    }
  }

  // Unirse a una sesión colaborativa
  Future<bool> joinSession(String sessionId) async {
    try {
      final response = await _client.rpc(
        'join_collaborative_session',
        params: {'session_uuid': sessionId},
      );

      return response == true;
    } catch (e) {
      throw Exception('Error uniéndose a la sesión: $e');
    }
  }

  // Finalizar una sesión colaborativa
  Future<bool> endSession(String sessionId) async {
    try {
      final response = await _client.rpc(
        'end_collaborative_session',
        params: {'session_uuid': sessionId},
      );

      return response == true;
    } catch (e) {
      throw Exception('Error finalizando la sesión: $e');
    }
  }

  // Obtener los participantes de una sesión específica
  Future<List<String>> getSessionParticipants(String sessionId) async {
    try {
      final response = await _client
          .from(_tableName)
          .select('participants')
          .eq('id', sessionId)
          .eq('is_active', true)
          .single();

      return List<String>.from(response['participants'] ?? []);
    } catch (e) {
      throw Exception('Error obteniendo participantes: $e');
    }
  }

  // Escuchar cambios en las sesiones en tiempo real
  Stream<List<CollaborativeSession>> watchUserTeamSessions() async* {
    // Primero emitir el estado actual
    yield await getUserTeamSessions();

    // Luego escuchar cambios en tiempo real
    await for (final _
        in _client
            .from(_tableName)
            .stream(primaryKey: ['id'])
            .eq('is_active', true)) {
      try {
        yield await getUserTeamSessions();
      } catch (e) {
        // En caso de error, emitir lista vacía
        yield [];
      }
    }
  }

  // Verificar si el usuario ya está en una sesión activa
  Future<bool> isUserInActiveSession() async {
    try {
      final sessions = await getUserTeamSessions();
      return sessions.any((session) => session.isParticipant);
    } catch (e) {
      return false;
    }
  }

  // Obtener la sesión activa del usuario (si existe)
  Future<CollaborativeSession?> getUserActiveSession() async {
    try {
      final sessions = await getUserTeamSessions();
      return sessions.firstWhere(
        (session) => session.isParticipant,
        orElse: () => throw StateError('No active session'),
      );
    } catch (e) {
      return null;
    }
  }
}
