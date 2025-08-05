import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/user_profile.dart';

class AuthService {
  static final SupabaseClient _client = SupabaseConfig.client;

  // Obtener el usuario actual
  static User? get currentUser => _client.auth.currentUser;

  // Verificar si el usuario está autenticado
  static bool get isAuthenticated => currentUser != null;

  // Stream para escuchar cambios de autenticación
  static Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;

  // Registrar nuevo usuario
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName
          },
      );

      if (response.user != null) {
        print('Usuario registrado exitosamente: ${response.user!.email}');
      }

      return response;
    } catch (e) {
      print('Error al registrar usuario: $e');
      rethrow;
    }
  }

  // Iniciar sesión
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );


      if (response.user != null) {
        // Verificar si el usuario está activo en nuestra base de datos
        final userProfile = await _client
            .from('user_profiles')
            .select('is_active, full_name, role')
            .eq('id', response.user!.id)
            .single();

        // Si el usuario está desactivado, cerrar sesión inmediatamente
        if (userProfile['is_active'] == false) {
          await _client.auth.signOut();
          throw AuthException(
            'Tu cuenta ha sido desactivada. Contacta al administrador para más información.',
          );
        }

        print('Usuario autenticado: ${response.user!.email}');
      }

      return response;
    } catch (e) {
      print('Error al iniciar sesión: $e');
      rethrow;
    }
  }

  // Cerrar sesión
  static Future<void> signOut() async {
    try {
      await _client.auth.signOut();
      print('Sesión cerrada exitosamente');
    } catch (e) {
      print('Error al cerrar sesión: $e');
      rethrow;
    }
  }

  // Obtener perfil del usuario actual
  static Future<UserProfile?> getCurrentUserProfile() async {
    try {
      if (!isAuthenticated) return null;

      final response = await _client
          .from('user_profiles')
          .select()
          .eq('id', currentUser!.id)
          .single();

      return UserProfile.fromJson(response);
    } catch (e) {
      print('Error al obtener perfil de usuario: $e');
      return null;
    }
  }

  // Actualizar perfil de usuario
  static Future<void> updateUserProfile({
    required String userId,
    String? fullName,
    String? role,
    String? teamId,
  }) async {
    try {
      final updates = <String, dynamic>{};

      if (fullName != null) updates['full_name'] = fullName;
      if (role != null) updates['role'] = role;
      if (teamId != null) updates['team_id'] = teamId;

      if (updates.isNotEmpty) {
        updates['updated_at'] = DateTime.now().toIso8601String();

        await _client.from('user_profiles').update(updates).eq('id', userId);

        print('Perfil actualizado exitosamente');
      }
    } catch (e) {
      print('Error al actualizar perfil: $e');
      rethrow;
    }
  }

  // Resetear contraseña
  static Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
      print('Email de recuperación enviado');
    } catch (e) {
      print('Error al enviar email de recuperación: $e');
      rethrow;
    }
  }

  // Verificar si es admin
  static Future<bool> isAdmin() async {
    try {
      final profile = await getCurrentUserProfile();
      return profile?.role == 'admin';
    } catch (e) {
      print('Error al verificar rol de admin: $e');
      return false;
    }
  }

  // Verificar si el usuario actual está activo
  static Future<bool> isCurrentUserActive() async {
    try {
      if (!isAuthenticated) return false;

      final response = await _client
          .from('user_profiles')
          .select('is_active')
          .eq('id', currentUser!.id)
          .single();

      final isActive = response['is_active'] == true;

      // Si el usuario no está activo, cerrar sesión automáticamente
      if (!isActive) {
        await signOut();
        throw AuthException(
          'Tu cuenta ha sido desactivada. Contacta al administrador.',
        );
      }

      return isActive;
    } catch (e) {
      print('Error al verificar estado del usuario: $e');
      if (e is AuthException) rethrow;
      return false;
    }
  }

  // Obtener usuarios del mismo equipo
  static Future<List<UserProfile>> getTeamMembers() async {
    try {
      if (!isAuthenticated) return [];

      final currentProfile = await getCurrentUserProfile();
      if (currentProfile?.teamId == null) return [];

      final response = await _client
          .from('user_profiles')
          .select()
          .eq('team_id', currentProfile!.teamId!)
          .eq('is_active', true);

      return response
          .map<UserProfile>((json) => UserProfile.fromJson(json))
          .toList();
    } catch (e) {
      print('Error al obtener miembros del equipo: $e');
      return [];
    }
  }
}
