import '../config/supabase_config.dart';
import '../models/user_profile.dart';
import '../models/user_location.dart';
import '../services/auth_service.dart';

class AdminService {
  static final _client = SupabaseConfig.client;

  // Verificar si el usuario actual es administrador
  static Future<bool> isCurrentUserAdmin() async {
    try {
      final user = AuthService.currentUser;
      if (user == null) return false;

      final response = await _client
          .from('user_profiles')
          .select('role')
          .eq('id', user.id)
          .single();

      return response['role'] == 'admin';
    } catch (e) {
      print('Error al verificar rol de admin: $e');
      return false;
    }
  }

  // Obtener todos los usuarios
  static Future<List<UserProfile>> getAllUsers() async {
    try {
      // Primero verificamos si el usuario actual es admin
      final isAdmin = await isCurrentUserAdmin();
      if (!isAdmin) {
        print('Usuario no autorizado para ver todos los usuarios');
        return [];
      }

      // Usamos una función RPC para obtener todos los usuarios como admin
      final response = await _client.rpc('get_all_users_as_admin');

      if (response == null) {
        // Fallback: intentar con consulta directa
        final fallbackResponse = await _client
            .from('user_profiles')
            .select('*')
            .order('created_at', ascending: false);

        return fallbackResponse
            .map<UserProfile>((json) => UserProfile.fromJson(json))
            .toList();
      }

      return (response as List)
          .map<UserProfile>((json) => UserProfile.fromJson(json))
          .toList();
    } catch (e) {
      print('Error al obtener usuarios: $e');
      // Intentar consulta directa como fallback
      try {
        final fallbackResponse = await _client
            .from('user_profiles')
            .select('*')
            .order('created_at', ascending: false);

        return fallbackResponse
            .map<UserProfile>((json) => UserProfile.fromJson(json))
            .toList();
      } catch (fallbackError) {
        print('Error en fallback: $fallbackError');
        return [];
      }
    }
  }

  // Obtener usuarios por equipo
  static Future<List<UserProfile>> getUsersByTeam(String teamId) async {
    try {
      // Primero obtener el equipo con sus miembros
      final teamResponse = await _client
          .from('teams')
          .select('users_id')
          .eq('id', teamId)
          .single();

      final List<dynamic> userIds = teamResponse['users_id'] ?? [];

      if (userIds.isEmpty) return [];

      // Obtener perfiles de los usuarios del equipo
      final response = await _client
          .from('user_profiles')
          .select('*')
          .inFilter('id', userIds)
          .eq('is_active', true)
          .order('full_name', ascending: true);

      return response
          .map<UserProfile>((json) => UserProfile.fromJson(json))
          .toList();
    } catch (e) {
      print('Error al obtener usuarios por equipo: $e');
      return [];
    }
  }

  // Crear nuevo usuario
  static Future<bool> createUser({
    required String email,
    required String password,
    required String fullName,
    String role = 'topografo',
  }) async {
    try {
      // Crear usuario en auth
      final authResponse = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
      );

      if (authResponse.user != null) {
        // Actualizar perfil con rol
        await _client
            .from('user_profiles')
            .update({
              'role': role,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', authResponse.user!.id);

        return true;
      }
      return false;
    } catch (e) {
      print('Error al crear usuario: $e');
      return false;
    }
  }

  // Actualizar usuario
  static Future<bool> updateUser({
    required String userId,
    String? fullName,
    String? role,
    bool? isActive,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (fullName != null) updates['full_name'] = fullName;
      if (role != null) updates['role'] = role;
      if (isActive != null) updates['is_active'] = isActive;

      await _client.from('user_profiles').update(updates).eq('id', userId);

      return true;
    } catch (e) {
      print('Error al actualizar usuario: $e');
      return false;
    }
  }

  // Desactivar usuario
  static Future<bool> deactivateUser(String userId) async {
    try {
      await _client
          .from('user_profiles')
          .update({
            'is_active': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      return true;
    } catch (e) {
      print('Error al desactivar usuario: $e');
      return false;
    }
  }

  // Activar usuario
  static Future<bool> activateUser(String userId) async {
    try {
      await _client
          .from('user_profiles')
          .update({
            'is_active': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      return true;
    } catch (e) {
      print('Error al activar usuario: $e');
      return false;
    }
  }

  // Obtener ubicaciones de todos los usuarios en tiempo real
  static Future<List<UserLocation>> getAllActiveLocations() async {
    try {
      // Verificar si el usuario actual es admin
      final isAdmin = await isCurrentUserAdmin();
      if (!isAdmin) {
        print('Usuario no autorizado para ver ubicaciones');
        return [];
      }

      // Usar función RPC para obtener ubicaciones activas
      try {
        final response = await _client.rpc('get_active_locations_as_admin');

        if (response != null) {
          return (response as List)
              .map<UserLocation>((json) => UserLocation.fromJson(json))
              .toList();
        }
      } catch (rpcError) {
        print('Error en RPC para ubicaciones, usando fallback: $rpcError');
      }

      // Fallback: consulta directa
      final response = await _client
          .from('user_locations')
          .select('''
            *,
            user_profiles!inner(full_name, role, is_active)
          ''')
          .eq('is_active', true)
          .eq('user_profiles.is_active', true)
          .order('timestamp', ascending: false);

      return response
          .map<UserLocation>((json) => UserLocation.fromJson(json))
          .toList();
    } catch (e) {
      print('Error al obtener ubicaciones activas: $e');
      return [];
    }
  }

  // Obtener estadísticas del sistema
  static Future<Map<String, dynamic>> getSystemStats() async {
    try {
      // Verificar si el usuario actual es admin
      final isAdmin = await isCurrentUserAdmin();
      if (!isAdmin) {
        print('Usuario no autorizado para ver estadísticas');
        return {
          'total_users': 0,
          'active_users': 0,
          'admins': 0,
          'topografos': 0,
          'locations_today': 0,
          'teams_count': 0,
        };
      }

      // Usar función RPC para obtener estadísticas
      final response = await _client.rpc('get_system_stats_as_admin');

      if (response != null) {
        return Map<String, dynamic>.from(response);
      }

      // Fallback: consultas individuales
      final stats = await _getFallbackStats();
      return stats;
    } catch (e) {
      print('Error al obtener estadísticas: $e');
      // Fallback en caso de error
      return await _getFallbackStats();
    }
  }

  // Función helper para estadísticas fallback
  static Future<Map<String, dynamic>> _getFallbackStats() async {
    try {
      // Contar usuarios totales
      final totalUsersResponse = await _client
          .from('user_profiles')
          .select('id')
          .count();

      // Contar usuarios activos
      final activeUsersResponse = await _client
          .from('user_profiles')
          .select('id')
          .eq('is_active', true)
          .count();

      // Contar administradores
      final adminsResponse = await _client
          .from('user_profiles')
          .select('id')
          .eq('role', 'admin')
          .count();

      // Contar topógrafos
      final topografosResponse = await _client
          .from('user_profiles')
          .select('id')
          .eq('role', 'topografo')
          .count();

      // Contar ubicaciones de hoy
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final locationsResponse = await _client
          .from('user_locations')
          .select('id')
          .gte('timestamp', startOfDay.toIso8601String())
          .count();

      // Contar equipos activos
      final teamsResponse = await _client
          .from('teams')
          .select('id')
          .eq('is_active', true)
          .count();

      return {
        'total_users': totalUsersResponse.count,
        'active_users': activeUsersResponse.count,
        'admins': adminsResponse.count,
        'topografos': topografosResponse.count,
        'locations_today': locationsResponse.count,
        'teams_count': teamsResponse.count,
      };
    } catch (e) {
      print('Error en fallback stats: $e');
      return {
        'total_users': 0,
        'active_users': 0,
        'admins': 0,
        'topografos': 0,
        'locations_today': 0,
        'teams_count': 0,
      };
    }
  }

  // Obtener equipos disponibles
  static Future<List<Map<String, dynamic>>> getTeams() async {
    try {
      // Verificar si el usuario actual es admin
      final isAdmin = await isCurrentUserAdmin();
      if (!isAdmin) {
        print('Usuario no autorizado para ver equipos');
        return [];
      }

      // Usar función RPC para obtener equipos
      try {
        final response = await _client.rpc('get_all_teams_as_admin');

        if (response != null) {
          return (response as List)
              .map((team) => Map<String, dynamic>.from(team))
              .toList();
        }
      } catch (rpcError) {
        print('Error en RPC, usando fallback: $rpcError');
      }

      // Fallback: consulta directa
      final response = await _client
          .from('teams')
          .select(
            'id, name, description, leader_id, users_id, is_active, created_at, updated_at',
          )
          .order('name', ascending: true);

      final processedTeams = <Map<String, dynamic>>[];

      for (final team in response) {
        final teamData = Map<String, dynamic>.from(team);

        // Obtener IDs de usuarios desde users_id[]
        final List<dynamic> userIds = teamData['users_id'] ?? [];

        List<UserProfile> members = [];
        String? leaderName;

        if (userIds.isNotEmpty) {
          // Obtener perfiles de esos IDs
          try {
            final membersResponse = await _client
                .from('user_profiles')
                .select('id, full_name, email, role, is_active')
                .inFilter('id', userIds);

            members = membersResponse
                .map<UserProfile>((json) => UserProfile.fromJson(json))
                .toList();
          } catch (e) {
            print('Error obteniendo miembros del equipo ${teamData['id']}: $e');
          }
        }

        // Obtener nombre del líder
        if (teamData['leader_id'] != null) {
          try {
            final leaderResponse = await _client
                .from('user_profiles')
                .select('full_name')
                .eq('id', teamData['leader_id'])
                .single();
            leaderName = leaderResponse['full_name'];
          } catch (e) {
            print('Error obteniendo líder del equipo ${teamData['id']}: $e');
          }
        }

        // Contar miembros activos
        final activeMembersCount = members.where((m) => m.isActive).length;

        // Agregar info calculada
        teamData['members'] = members;
        teamData['leader_name'] = leaderName;
        teamData['member_count'] = activeMembersCount;
        teamData['active_members_count'] = activeMembersCount;

        processedTeams.add(teamData);
      }

      return processedTeams;
    } catch (e) {
      print('Error al obtener equipos: $e');
      return [];
    }
  }

  // Crear nuevo equipo
  static Future<bool> createTeam({
    required String name,
    String? description,
    String? leaderId,
  }) async {
    try {
      // Lista inicial de miembros (incluye líder si existe)
      List<String> initialMembers = [];
      if (leaderId != null && leaderId.isNotEmpty) {
        initialMembers.add(leaderId);
      }

      // Inserta equipo con leader y users_id inicial
      final teamResponse = await _client
          .from('teams')
          .insert({
            'name': name,
            'description': description ?? '',
            'leader_id': leaderId,
            'users_id': initialMembers,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      print("Equipo creado: $teamResponse");
      return true;
    } catch (e) {
      print('Error al crear equipo: $e');
      return false;
    }
  }

  // Obtener historial de ubicaciones de un usuario
  static Future<List<UserLocation>> getUserLocationHistory(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    try {
      var query = _client.from('user_locations').select().eq('user_id', userId);

      if (startDate != null) {
        query = query.gte('timestamp', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('timestamp', endDate.toIso8601String());
      }

      final response = await query
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

  // =================== MÉTODOS DE GESTIÓN DE EQUIPOS ===================

  // Actualizar equipo
  // Actualizar equipo existente
  static Future<bool> updateTeam({
    required String teamId,
    String? name,
    String? description,
    String? leaderId,
    bool? isActive,
  }) async {
    try {
      final Map<String, dynamic> updateData = {};

      if (name != null) updateData['name'] = name;
      if (description != null) updateData['description'] = description;
      if (leaderId != null) updateData['leader_id'] = leaderId;
      if (isActive != null) updateData['is_active'] = isActive;

      updateData['updated_at'] = DateTime.now().toIso8601String();

      // Actualizar datos principales del equipo
      await _client.from('teams').update(updateData).eq('id', teamId);

      // Si hay nuevo líder, lo agregamos a users_id si no está ya
      if (leaderId != null && leaderId.isNotEmpty) {
        final teamResponse = await _client
            .from('teams')
            .select('users_id')
            .eq('id', teamId)
            .single();

        List<dynamic> currentUsers = teamResponse['users_id'] ?? [];

        if (!currentUsers.contains(leaderId)) {
          currentUsers.add(leaderId);

          await _client
              .from('teams')
              .update({'users_id': currentUsers})
              .eq('id', teamId);
        }
      }

      print("Equipo actualizado correctamente");
      return true;
    } catch (e) {
      print('Error al actualizar equipo: $e');
      return false;
    }
  }

  // Eliminar equipo (soft delete)
  static Future<bool> deleteTeam(String teamId) async {
    try {
      // Limpiar leader_id y users_id, marcar inactivo
      await _client
          .from('teams')
          .update({
            'leader_id': null,
            'users_id': [], // Vacía el arreglo
            'is_active': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', teamId);

      print("Equipo eliminado (marcado como inactivo)");
      return true;
    } catch (e) {
      print('Error al eliminar equipo: $e');
      return false;
    }
  }

  // Agregar usuario al equipo
  static Future<bool> addUserToTeam(String userId, String teamId) async {
    try {
      // Obtener array actual
      final teamResponse = await _client
          .from('teams')
          .select('users_id')
          .eq('id', teamId)
          .single();

      List<dynamic> currentUsers = teamResponse['users_id'] ?? [];

      // Agregar solo si no existe
      if (!currentUsers.contains(userId)) {
        currentUsers.add(userId);
      }

      // Actualizar
      await _client
          .from('teams')
          .update({'users_id': currentUsers})
          .eq('id', teamId);

      return true;
    } catch (e) {
      print('Error al agregar usuario al equipo: $e');
      return false;
    }
  }

  // Remover usuario del equipo
  static Future<bool> removeUserFromTeam(String userId, String teamId) async {
    try {
      final teamResponse = await _client
          .from('teams')
          .select('users_id')
          .eq('id', teamId)
          .single();

      // Asegurar que todos sean String para la comparación
      List<String> currentUsers =
          (teamResponse['users_id'] as List<dynamic>? ?? [])
              .map((id) => id.toString())
              .toList();

      // Remover usuario
      currentUsers.remove(userId.toString());

      // Actualizar la lista en Supabase
      await _client
          .from('teams')
          .update({'users_id': currentUsers})
          .eq('id', teamId);

      return true;
    } catch (e) {
      print('Error al remover usuario del equipo: $e');
      return false;
    }
  }

  // Obtener usuarios disponibles
  static Future<List<UserProfile>> getTeamMembers(String teamId) async {
    try {
      final teamResponse = await _client
          .from('teams')
          .select('users_id')
          .eq('id', teamId)
          .single();

      final userIds = (teamResponse['users_id'] as List<dynamic>? ?? []);

      if (userIds.isEmpty) return [];

      final allUsers = await _client
          .from('user_profiles')
          .select('*')
          .order('full_name', ascending: true);

      final teamMembers = allUsers
          .where((u) => userIds.contains(u['id']))
          .map<UserProfile>((json) => UserProfile.fromJson(json))
          .toList();

      return teamMembers;
    } catch (e) {
      print('Error al obtener miembros del equipo: $e');
      return [];
    }
  }

  static Future<List<UserProfile>> getAvailableUsers(String teamId) async {
    try {
      // Traemos el array de usuarios ya en el equipo
      final teamResponse = await _client
          .from('teams')
          .select('users_id')
          .eq('id', teamId)
          .single();

      final userIds = (teamResponse['users_id'] as List<dynamic>? ?? []);

      // Traemos todos los activos
      final allActiveUsers = await _client
          .from('user_profiles')
          .select('*')
          .eq('is_active', true)
          .order('full_name', ascending: true);

      // Filtramos en memoria: quitamos los que ya están en users_id
      final availableUsers = allActiveUsers
          .where((u) => !userIds.contains(u['id']))
          .map<UserProfile>((json) => UserProfile.fromJson(json))
          .toList();

      return availableUsers;
    } catch (e) {
      print('Error al obtener usuarios disponibles: $e');
      return [];
    }
  }

  // Activar/desactivar equipo
  static Future<bool> toggleTeamStatus(String teamId, bool isActive) async {
    try {
      await _client
          .from('teams')
          .update({
            'is_active': isActive,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', teamId);

      return true;
    } catch (e) {
      print('Error al cambiar estado del equipo: $e');
      return false;
    }
  }

  // Obtener usuarios disponibles para ser líderes
  static Future<List<UserProfile>> getAvailableLeaders() async {
    try {
      // Verificar si el usuario actual es admin
      final isAdmin = await isCurrentUserAdmin();
      if (!isAdmin) {
        print('Usuario no autorizado para ver usuarios disponibles');
        return [];
      }

      // Usar función RPC para obtener usuarios disponibles
      try {
        final response = await _client.rpc('get_available_leaders_as_admin');

        if (response != null) {
          return (response as List)
              .map<UserProfile>((json) => UserProfile.fromJson(json))
              .toList();
        }
      } catch (rpcError) {
        print('Error en RPC para líderes, usando fallback: $rpcError');
      }

      // Fallback: consulta directa
      final response = await _client
          .from('user_profiles')
          .select('*')
          .eq('is_active', true)
          .order('full_name', ascending: true);

      return response
          .map<UserProfile>((json) => UserProfile.fromJson(json))
          .toList();
    } catch (e) {
      print('Error al obtener usuarios disponibles para líderes: $e');
      return [];
    }
  }
}
