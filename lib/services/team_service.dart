import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/team.dart';
import '../models/user_profile.dart';

class TeamService {
  static final _supabase = Supabase.instance.client;

  /// Obtener todos los equipos del usuario actual
  static Future<List<Team>> getUserTeams() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      // Usar la función de base de datos para obtener equipos del usuario
      final teamsData = await _supabase.rpc(
        'get_user_teams',
        params: {'user_uuid': user.id},
      );

      return teamsData.map<Team>((data) => Team.fromJson(data)).toList();
    } catch (e) {
      print('Error obteniendo equipos del usuario: $e');
      return [];
    }
  }

  /// Obtener información del equipo del usuario actual (compatibilidad hacia atrás)
  static Future<Team?> getCurrentUserTeam() async {
    try {
      final teams = await getUserTeams();
      return teams.isNotEmpty ? teams.first : null;
    } catch (e) {
      print('Error obteniendo equipo: $e');
      return null;
    }
  }

  /// Obtener miembros de un equipo específico
  static Future<List<UserProfile>> getTeamMembers([String? teamId]) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      String targetTeamId = teamId ?? '';

      // Si no se especifica teamId, usar el primer equipo del usuario
      if (targetTeamId.isEmpty) {
        final teams = await getUserTeams();
        if (teams.isEmpty) return [];
        targetTeamId = teams.first.id;
      }

      // Usar la función de base de datos para obtener miembros del equipo
      final membersData = await _supabase.rpc(
        'get_team_members',
        params: {'team_uuid': targetTeamId},
      );

      return membersData
          .map<UserProfile>(
            (data) => UserProfile.fromJson({
              'id': data['user_id'],
              'full_name': data['full_name'],
              'email': data['email'],
              'role': data['role'],
              'avatar_url': data['avatar_url'],
              'team_id': targetTeamId,
              'is_active': true,
              'created_at':
                  data['joined_at'] ?? DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            }),
          )
          .toList();
    } catch (e) {
      print('Error obteniendo miembros del equipo: $e');
      return [];
    }
  }
}
