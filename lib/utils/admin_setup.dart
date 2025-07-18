import 'package:supabase_flutter/supabase_flutter.dart';

class AdminSetup {
  static final _supabase = Supabase.instance.client;

  /// Función temporal para convertir un usuario en administrador
  /// SOLO para desarrollo - eliminar en producción
  static Future<bool> makeUserAdmin(String userId) async {
    try {
      await _supabase
          .from('user_profiles')
          .update({'role': 'admin'})
          .eq('id', userId);

      return true;
    } catch (e) {
      print('Error al convertir usuario en admin: $e');
      return false;
    }
  }

  /// Función para hacer admin al usuario actual
  static Future<bool> makeCurrentUserAdmin() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      return await makeUserAdmin(user.id);
    } catch (e) {
      print('Error: $e');
      return false;
    }
  }

  /// Función para verificar el rol actual
  static Future<String?> getCurrentUserRole() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final response = await _supabase
          .from('user_profiles')
          .select('role')
          .eq('id', user.id)
          .single();

      return response['role'];
    } catch (e) {
      print('Error al obtener rol: $e');
      return null;
    }
  }
}
