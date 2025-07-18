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
        print('Error: Usuario no autenticado');
        throw Exception('Usuario no autenticado');
      }

      if (points.length < 3) {
        print(
          'Error: Se necesitan al menos 3 puntos, se recibieron ${points.length}',
        );
        throw Exception('Se necesitan al menos 3 puntos para crear un terreno');
      }

      print(
        'Creando terreno con ${points.length} puntos para usuario ${user.id}',
      );

      final area = Terrain.calculateArea(points);
      final now = DateTime.now();

      // Convertir puntos a formato JSON
      final pointsJson = points
          .map((p) => {'latitude': p.latitude, 'longitude': p.longitude})
          .toList();

      print('Área calculada: $area m²');
      print('Puntos JSON: $pointsJson');

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

      print('Datos del terreno a insertar: $terrainData');

      final response = await _supabase
          .from('terrains')
          .insert(terrainData)
          .select()
          .single();

      print('Terreno creado exitosamente: $response');
      return true;
    } catch (e) {
      print('Error detallado al crear terreno: $e');
      print('Tipo de error: ${e.runtimeType}');
      if (e is PostgrestException) {
        print('Error de Postgres: ${e.message}');
        print('Código de error: ${e.code}');
        print('Detalles: ${e.details}');
      }
      rethrow; // Re-lanzar para que el BLoC pueda capturarlo
    }
  }

  /// Obtener terrenos del usuario actual
  static Future<List<Terrain>> getUserTerrains() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        print('Error: Usuario no autenticado al obtener terrenos');
        return [];
      }

      print('Obteniendo terrenos para usuario: ${user.id}');

      final response = await _supabase
          .from('terrains')
          .select()
          .eq('user_id', user.id)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      print('Respuesta de la base de datos: $response');
      print('Número de terrenos encontrados: ${response.length}');

      final terrains = <Terrain>[];

      for (int i = 0; i < response.length; i++) {
        try {
          final json = response[i];
          print('Procesando terreno $i: ${json['name']}');
          final terrain = Terrain.fromJson(json);
          terrains.add(terrain);
          print('Terreno $i procesado exitosamente');
        } catch (e) {
          print('Error al procesar terreno $i: $e');
          print('Datos del terreno problemático: ${response[i]}');
          // Continuar con el siguiente terreno en lugar de fallar completamente
          continue;
        }
      }

      print('Terrenos parseados exitosamente: ${terrains.length}');
      for (var terrain in terrains) {
        print(
          '- ${terrain.name}: ${terrain.points.length} puntos, área: ${terrain.area}',
        );
      }

      return terrains;
    } catch (e) {
      print('Error al obtener terrenos del usuario: $e');
      print('Tipo de error: ${e.runtimeType}');
      if (e is PostgrestException) {
        print('Error de Postgres: ${e.message}');
        print('Código de error: ${e.code}');
        print('Detalles: ${e.details}');
      }
      return [];
    }
  }

  /// Obtener terrenos del equipo
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
      print('Error al obtener terrenos del equipo: $e');
      return [];
    }
  }

  /// Obtener todos los terrenos (solo admin)
  static Future<List<Terrain>> getAllTerrains() async {
    try {
      final response = await _supabase
          .from('terrains')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false);

      return response.map<Terrain>((json) => Terrain.fromJson(json)).toList();
    } catch (e) {
      print('Error al obtener todos los terrenos: $e');
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
      print('Error al actualizar terreno: $e');
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
      print('Error al eliminar terreno: $e');
      return false;
    }
  }

  /// Obtener estadísticas de terrenos
  static Future<Map<String, dynamic>> getTerrainStats() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return {};

      final terrains = await getUserTerrains();

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
      print('Error al obtener estadísticas: $e');
      return {};
    }
  }
}
