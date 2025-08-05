import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/collaborative_terrain_point.dart';
import '../config/supabase_config.dart';

class CollaborativeTerrainService {
  final SupabaseClient _client = SupabaseConfig.client;

  // Agregar un punto al mapeo colaborativo
  Future<Map<String, dynamic>> addTerrainPoint({
    required String sessionId,
    required double latitude,
    required double longitude,
    double? altitude,
    double? accuracy,
  }) async {
    try {
      final response = await _client.rpc(
        'add_collaborative_terrain_point',
        params: {
          'session_uuid': sessionId,
          'point_lat': latitude,
          'point_lng': longitude,
          'point_alt': altitude,
          'point_accuracy': accuracy,
        },
      );

      if (response == null || response.isEmpty) {
        throw Exception('Error agregando punto al terreno colaborativo');
      }

      final result = response[0];
      return {
        'point_id': result['point_id'],
        'point_number': result['point_number'],
        'total_points': result['total_points'],
      };
    } catch (e) {
      throw Exception('Error agregando punto colaborativo: $e');
    }
  }

  // Obtener puntos de una sesión colaborativa
  Future<List<CollaborativeTerrainPoint>> getSessionTerrainPoints(
    String sessionId,
  ) async {
    try {
      final response = await _client.rpc(
        'get_collaborative_terrain_points',
        params: {'session_uuid': sessionId},
      );

      if (response == null) return [];

      return (response as List)
          .map((json) => CollaborativeTerrainPoint.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Error obteniendo puntos colaborativos: $e');
    }
  }

  // Eliminar el último punto agregado por el usuario actual
  Future<bool> removeLastPoint(String sessionId) async {
    try {
      final response = await _client.rpc(
        'remove_last_collaborative_point',
        params: {'session_uuid': sessionId},
      );

      return response == true;
    } catch (e) {
      throw Exception('Error eliminando último punto: $e');
    }
  }

  // Limpiar todos los puntos de la sesión
  Future<bool> clearAllPoints(String sessionId) async {
    try {
      final response = await _client.rpc(
        'clear_all_collaborative_points',
        params: {'session_uuid': sessionId},
      );

      return response == true;
    } catch (e) {
      throw Exception('Error limpiando puntos colaborativos: $e');
    }
  }

  // Calcular área del terreno colaborativo
  Future<double> calculateTerrainArea(String sessionId) async {
    try {
      final response = await _client.rpc(
        'calculate_collaborative_terrain_area',
        params: {'session_uuid': sessionId},
      );

      return (response as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      throw Exception('Error calculando área colaborativa: $e');
    }
  }

  // Guardar terreno colaborativo finalizado
  Future<String> saveCollaborativeTerrain({
    required String sessionId,
    required String name,
    String? description,
  }) async {
    try {
      final response = await _client.rpc(
        'save_collaborative_terrain',
        params: {
          'session_uuid': sessionId,
          'terrain_name': name,
          'terrain_description': description,
        },
      );

      if (response == null) {
        throw Exception('Error guardando terreno colaborativo');
      }

      return response as String;
    } catch (e) {
      throw Exception('Error guardando terreno colaborativo: $e');
    }
  }

  // Escuchar cambios en tiempo real de puntos colaborativos
  Stream<List<CollaborativeTerrainPoint>> watchSessionTerrainPoints(
    String sessionId,
  ) {
    // Stream simplificado - solo filtrar por sesión
    return _client
        .from('collaborative_terrain_points')
        .stream(primaryKey: ['id'])
        .map((data) {
          print('Stream recibido: ${data.length} registros totales');
          
          // Filtrar datos de esta sesión
          final filteredData = data
              .where((json) => 
                  json['collaborative_session_id'] == sessionId && 
                  json['is_active'] == true
              )
              .toList();
              
          print('Datos filtrados para sesión $sessionId: ${filteredData.length} puntos');
          
          // Ordenar por número de punto
          filteredData.sort((a, b) => (a['point_number'] as int).compareTo(b['point_number'] as int));

          // Convertir a objetos CollaborativeTerrainPoint
          return filteredData
              .map((json) => CollaborativeTerrainPoint.fromJson({
                    'point_id': json['id'],
                    'collaborative_session_id': json['collaborative_session_id'],
                    'user_id': json['user_id'],
                    'user_full_name': 'Usuario', // Se actualizará con polling
                    'point_number': json['point_number'],
                    'latitude': json['latitude'],
                    'longitude': json['longitude'],
                    'altitude': json['altitude'],
                    'accuracy': json['accuracy'],
                    'created_at': json['created_at'],
                    'is_active': json['is_active'],
                  }))
              .toList();
        });
  }

  // Obtener estadísticas de la sesión colaborativa
  Future<Map<String, dynamic>> getSessionStats(String sessionId) async {
    try {
      final points = await getSessionTerrainPoints(sessionId);
      final area = await calculateTerrainArea(sessionId);

      // Contar contribuciones por usuario
      final userContributions = <String, int>{};
      for (final point in points) {
        userContributions[point.userFullName] = 
            (userContributions[point.userFullName] ?? 0) + 1;
      }

      return {
        'total_points': points.length,
        'calculated_area': area,
        'user_contributions': userContributions,
        'can_save': points.length >= 3,
        'last_updated': points.isNotEmpty 
            ? points.map((p) => p.createdAt).reduce((a, b) => a.isAfter(b) ? a : b)
            : null,
      };
    } catch (e) {
      throw Exception('Error obteniendo estadísticas de sesión: $e');
    }
  }
}