import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/terrain.dart';

class TerrainService {
  static final _supabase = Supabase.instance.client;

  /// Crear un nuevo terreno
  static Future<bool> createTerrain({
    required String name,
    String? description,
    required List<TerrainPoint> points,
    String? teamId,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        //print('Error: Usuario no autenticado');
        throw Exception('Usuario no autenticado');
      }

      if (points.length < 3) {
        /*print(
          'Error: Se necesitan al menos 3 puntos, se recibieron ${points.length}',
        );*/
        throw Exception('Se necesitan al menos 3 puntos para crear un terreno');
      }

      /*print(
        'Creando terreno con ${points.length} puntos para usuario ${user.id}',
      );*/
      //print('Team ID especificado: ${teamId ?? 'null (individual)'}');

      final area = Terrain.calculateArea(points);
      final now = DateTime.now();

      // Convertir puntos a formato JSON
      final pointsJson = points
          .map((p) => {'latitude': p.latitude, 'longitude': p.longitude})
          .toList();

      /*print('Área calculada: $area m²');
      print('Puntos JSON: $pointsJson');*/

      final terrainData = {
        'name': name,
        'description': description,
        'points': pointsJson,
        'area': area,
        'user_id': user.id,
        'team_id': teamId,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'is_active': true,
      };

      //print('Datos del terreno a insertar: $terrainData');

      final response = await _supabase
          .from('terrains')
          .insert(terrainData)
          .select()
          .single();

      //print('Terreno creado exitosamente: $response');
      return true;
    } catch (e) {
      //print('Error detallado al crear terreno: $e');
      //print('Tipo de error: ${e.runtimeType}');
      if (e is PostgrestException) {
        //print('Error de Postgres: ${e.message}');
        //print('Código de error: ${e.code}');
        //print('Detalles: ${e.details}');
      }
      rethrow; // Re-lanzar para que el BLoC pueda capturarlo
    }
  }



  /// Obtener terrenos del usuario actual
  static Future<List<Terrain>> getUserTerrains() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        //print('Error: Usuario no autenticado al obtener terrenos');
        return [];
      }

      //print('Obteniendo terrenos para usuario: ${user.id}');

      final response = await _supabase
          .from('terrains')
          .select()
          .eq('user_id', user.id)
          .eq('is_active', true)
          .order('created_at', ascending: false);
      /*
      print('Respuesta de la base de datos: $response');
      print('Número de terrenos encontrados: ${response.length}');*/

      final terrains = <Terrain>[];

      for (int i = 0; i < response.length; i++) {
        try {
          final json = response[i];
          //print('Procesando terreno $i: ${json['name']}');
          final terrain = Terrain.fromJson(json);
          terrains.add(terrain);
          //print('Terreno $i procesado exitosamente');
        } catch (e) {
          //print('Error al procesar terreno $i: $e');
          //print('Datos del terreno problemático: ${response[i]}');
          // Continuar con el siguiente terreno en lugar de fallar completamente
          continue;
        }
      }

      //print('Terrenos parseados exitosamente: ${terrains.length}');
      for (var terrain in terrains) {
        /*print(
          '- ${terrain.name}: ${terrain.points.length} puntos, área: ${terrain.area}',
        );*/
      }

      return terrains;
    } catch (e) {
      //print('Error al obtener terrenos del usuario: $e');
      //print('Tipo de error: ${e.runtimeType}');
      if (e is PostgrestException) {
        /*print('Error de Postgres: ${e.message}');
        print('Código de error: ${e.code}');
        print('Detalles: ${e.details}');*/
      }
      return [];
    }
  }

  // Obtener terrenos del equipo
  static Future<List<Terrain>> getTeamTerrains(String teamId) async {
    try {
      final response = await _supabase
          .from('terrains')
          .select()
          .eq('team_id', teamId)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      return response.map<Terrain>((json) => Terrain.fromJson(json)).toList();
    } catch (e) {
      //print('Error al obtener terrenos del equipo: $e');
      return [];
    }
  }



  // Obtener todos los terrenos (solo admin)
  static Future<List<Terrain>> getAllTerrains() async {
    try {
      final response = await _supabase
          .from('terrains')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false);

      return response.map<Terrain>((json) => Terrain.fromJson(json)).toList();
    } catch (e) {
      //print('Error al obtener todos los terrenos: $e');
      return [];
    }
  }

  /// Actualizar terreno
  static Future<bool> updateTerrain({
    required String terrainId,
    String? name,
    String? description,
    List<TerrainPoint>? points,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (name != null) updates['name'] = name;
      if (description != null) updates['description'] = description;

      if (points != null) {
        if (points.length < 3) {
          throw Exception(
            'Se necesitan al menos 3 puntos para actualizar un terreno',
          );
        }
        updates['points'] = points.map((point) => point.toJson()).toList();
        updates['area'] = Terrain.calculateArea(points);
      }

      await _supabase.from('terrains').update(updates).eq('id', terrainId);

      return true;
    } catch (e) {
      //print('Error al actualizar terreno: $e');
      return false;
    }
  }

  /// Eliminar terreno (soft delete)
  static Future<bool> deleteTerrain(String terrainId) async {
    try {
      await _supabase
          .from('terrains')
          .update({
            'is_active': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', terrainId);

      return true;
    } catch (e) {
      //print('Error al eliminar terreno: $e');
      return false;
    }
  }

  // ===========================================
  // FUNCIONALIDAD DE EQUIPOS - CLARAMENTE SEPARADA
  // ===========================================

  /// Obtener terrenos de los equipos del usuario (NUEVA FUNCIONALIDAD)
  static Future<List<Map<String, dynamic>>> getUserTeamTerrains() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        //print('Error: Usuario no autenticado al obtener terrenos de equipos');
        return [];
      }

      //print('[EQUIPOS] Obteniendo terrenos de equipos para usuario: ${user.id}');

      // Obtener equipos del usuario usando la función SQL existente
      final userTeamsResponse = await _supabase.rpc('get_user_teams', params: {'user_uuid': user.id});
      final userTeamIds = (userTeamsResponse as List).map((team) => team['team_id'] as String).toList();
      
      //print('[EQUIPOS] Equipos del usuario: $userTeamIds');

      if (userTeamIds.isEmpty) {
        //print('[EQUIPOS] Usuario no pertenece a ningún equipo');
        return [];
      }

      // Obtener terrenos de esos equipos con información del equipo
      final response = await _supabase
          .from('terrains')
          .select('''
            *,
            teams!terrains_team_id_fkey (
              id,
              name
            )
          ''')
          .inFilter('team_id', userTeamIds)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      //print('[EQUIPOS] Terrenos de equipos encontrados: ${response.length}');

      return response.cast<Map<String, dynamic>>();
    } catch (e) {
      //print('[EQUIPOS] Error al obtener terrenos de equipos: $e');
      if (e is PostgrestException) {
        /*print('[EQUIPOS] Error de Postgres: ${e.message}');
        print('[EQUIPOS] Código: ${e.code}, Detalles: ${e.details}');*/
      }
      return [];
    }
  }

  /// Combinar terrenos individuales y de equipos (NUEVA FUNCIONALIDAD)
  static Future<List<Terrain>> getUserAndTeamTerrainsForUI() async {
    try {
      // Obtener terrenos individuales (lógica existente)
      final individualTerrains = await getUserTerrains();
      //print('[COMBINADO] Terrenos individuales: ${individualTerrains.length}');

      // Obtener terrenos de equipos (nueva funcionalidad)
      final teamTerrainsData = await getUserTeamTerrains();
      final teamTerrains = <Terrain>[];

      // Convertir terrenos de equipos a objetos Terrain
      for (final terrainData in teamTerrainsData) {
        try {
          final terrain = Terrain.fromJson(terrainData);
          teamTerrains.add(terrain);
        } catch (e) {
          //print('[COMBINADO] Error procesando terreno de equipo: $e');
          continue;
        }
      }

      //print('[COMBINADO] Terrenos de equipos: ${teamTerrains.length}');

      // NUEVA VALIDACIÓN: Eliminar duplicados priorizando terrenos de equipo
      final teamTerrainIds = teamTerrains.map((t) => t.id).toSet();
      final filteredIndividualTerrains = individualTerrains
          .where((terrain) => !teamTerrainIds.contains(terrain.id))
          .toList();

      //print('[COMBINADO] Terrenos individuales después de filtrar duplicados: ${filteredIndividualTerrains.length}');
      
      if (teamTerrainIds.isNotEmpty) {
        final duplicateCount = individualTerrains.length - filteredIndividualTerrains.length;
        //print('[COMBINADO] Terrenos duplicados eliminados (priorizando versión de equipo): $duplicateCount');
      }

      // Combinar listas sin duplicados
      final allTerrains = [...filteredIndividualTerrains, ...teamTerrains];
      
      // Ordenar por fecha de creación (más recientes primero)
      allTerrains.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      //print('[COMBINADO] Total terrenos combinados (sin duplicados): ${allTerrains.length}');
      return allTerrains;
    } catch (e) {
      //print('[COMBINADO] Error combinando terrenos: $e');
      // En caso de error, devolver solo terrenos individuales
      return await getUserTerrains();
    }
  }

  // ===========================================
  // FIN FUNCIONALIDAD DE EQUIPOS
  // ===========================================

  /// Obtener estadísticas de terrenos (MODIFICADO para incluir equipos)
  static Future<Map<String, dynamic>> getTerrainStats() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return {};

      // Usar la nueva función que combina terrenos individuales y de equipos
      final terrains = await getUserAndTeamTerrainsForUI();

      double totalArea = 0;
      for (final terrain in terrains) {
        totalArea += terrain.area;
      }

      return {
        'total_terrains': terrains.length,
        'total_area': totalArea,
        'average_area': terrains.isNotEmpty ? totalArea / terrains.length : 0,
        'largest_terrain': terrains.isNotEmpty
            ? terrains.reduce((a, b) => a.area > b.area ? a : b).area
            : 0,
      };
    } catch (e) {
      //print('Error al obtener estadísticas: $e');
      return {};
    }
  }
}
