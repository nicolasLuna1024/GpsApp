import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DebugService {
  static final _supabase = Supabase.instance.client;

  /// Función para verificar el estado actual del usuario
  static Future<Map<String, dynamic>> getCurrentUserDebugInfo() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return {'error': 'No hay usuario autenticado'};
      }

      // Obtener información del perfil
      final profileResponse = await _supabase
          .from('user_profiles')
          .select('*')
          .eq('id', user.id)
          .maybeSingle();

      // Verificar RLS status
      final rlsStatus = await _checkRLSStatus();

      return {
        'user_id': user.id,
        'user_email': user.email,
        'profile_data': profileResponse,
        'rls_status': rlsStatus,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {'error': 'Error al obtener información: $e'};
    }
  }

  static Future<Map<String, dynamic>> _checkRLSStatus() async {
    try {
      // Intentar consultas para verificar RLS
      final userProfilesTest = await _supabase
          .from('user_profiles')
          .select('count')
          .count(CountOption.exact);

      return {
        'user_profiles_accessible': true,
        'count': userProfilesTest.count,
      };
    } catch (e) {
      return {'user_profiles_accessible': false, 'error': e.toString()};
    }
  }

  /// Función para mostrar información de depuración
  static void showDebugDialog(BuildContext context) async {
    final info = await getCurrentUserDebugInfo();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Información de Depuración'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Usuario ID: ${info['user_id'] ?? 'N/A'}'),
              const SizedBox(height: 8),
              Text('Email: ${info['user_email'] ?? 'N/A'}'),
              const SizedBox(height: 8),
              Text('Perfil: ${info['profile_data'] ?? 'N/A'}'),
              const SizedBox(height: 8),
              Text('RLS Status: ${info['rls_status'] ?? 'N/A'}'),
              const SizedBox(height: 8),
              if (info['error'] != null)
                Text(
                  'Error: ${info['error']}',
                  style: const TextStyle(color: Colors.red),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}
