import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';

// Eventos de autenticación
abstract class AuthEvent {}

class AuthStarted extends AuthEvent {}

class AuthSignInRequested extends AuthEvent {
  final String email;
  final String password;
  AuthSignInRequested({required this.email, required this.password});
}

class AuthSignUpRequested extends AuthEvent {
  final String email;
  final String password;
  final String fullName;
  AuthSignUpRequested({
    required this.email,
    required this.password,
    required this.fullName,
  });
}

class AuthSignOutRequested extends AuthEvent {}

class AuthUserChanged extends AuthEvent {
  final User? user;
  AuthUserChanged(this.user);
}

class AuthRefreshProfile extends AuthEvent {}

class AuthCheckUserStatus extends AuthEvent {}

// Estados de autenticación
abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final User user;
  final UserProfile? profile;

  AuthAuthenticated({required this.user, this.profile});
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}

// BLoC de autenticación
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc() : super(AuthInitial()) {
    on<AuthStarted>(_onAuthStarted);
    on<AuthSignInRequested>(_onSignInRequested);
    on<AuthSignUpRequested>(_onSignUpRequested);
    on<AuthSignOutRequested>(_onSignOutRequested);
    on<AuthUserChanged>(_onUserChanged);
    on<AuthRefreshProfile>(_onRefreshProfile);
    on<AuthCheckUserStatus>(_onCheckUserStatus);
  }

  Future<void> _onAuthStarted(
    AuthStarted event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    // Escuchar cambios de estado de autenticación
    AuthService.authStateChanges.listen((authState) {
      add(AuthUserChanged(authState.session?.user));
    });

    // Verificar si ya hay un usuario autenticado
    final currentUser = AuthService.currentUser;
    if (currentUser != null) {
      final profile = await AuthService.getCurrentUserProfile();
      emit(AuthAuthenticated(user: currentUser, profile: profile));
    } else {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onSignInRequested(
    AuthSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      final response = await AuthService.signIn(
        email: event.email,
        password: event.password,
      );

      if (response.user != null) {
        final profile = await AuthService.getCurrentUserProfile();
        emit(AuthAuthenticated(user: response.user!, profile: profile));
      } else {
        emit(AuthError('Error al iniciar sesión'));
      }
    } catch (e) {
      emit(AuthError(_getErrorMessage(e)));
    }
  }

  Future<void> _onSignUpRequested(
    AuthSignUpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      final response = await AuthService.signUp(
        email: event.email,
        password: event.password,
        fullName: event.fullName,
      );

      if (response.user != null) {
        // Esperar un poco para que se cree el perfil
        await Future.delayed(const Duration(seconds: 1));
        final profile = await AuthService.getCurrentUserProfile();
        emit(AuthAuthenticated(user: response.user!, profile: profile));
      } else {
        emit(AuthError('Error al registrar usuario'));
      }
    } catch (e) {
      emit(AuthError(_getErrorMessage(e)));
    }
  }

  Future<void> _onSignOutRequested(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      await AuthService.signOut();
      emit(AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(_getErrorMessage(e)));
    }
  }

  Future<void> _onUserChanged(
    AuthUserChanged event,
    Emitter<AuthState> emit,
  ) async {
    if (event.user != null) {
      final profile = await AuthService.getCurrentUserProfile();
      emit(AuthAuthenticated(user: event.user!, profile: profile));
    } else {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onRefreshProfile(
    AuthRefreshProfile event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final user = AuthService.currentUser;
      if (user != null) {
        final profile = await AuthService.getCurrentUserProfile();
        emit(AuthAuthenticated(user: user, profile: profile));
      }
    } catch (e) {
      emit(AuthError(_getErrorMessage(e)));
    }
  }

  String _getErrorMessage(dynamic error) {
    if (error is AuthException) {
      switch (error.message) {
        case 'Invalid login credentials':
          return 'Credenciales inválidas. Verifica tu email y contraseña.';
        case 'Email not confirmed':
          return 'Email no confirmado. Revisa tu bandeja de entrada.';
        case 'User already registered':
          return 'El usuario ya está registrado.';
        default:
          return error.message;
      }
    }
    return 'Ha ocurrido un error inesperado: $error';
  }

  Future<void> _onCheckUserStatus(
    AuthCheckUserStatus event,
    Emitter<AuthState> emit,
  ) async {
    try {
      // Verificar si el usuario está activo
      final isActive = await AuthService.isCurrentUserActive();

      if (!isActive) {
        // Si no está activo, emitir estado no autenticado
        emit(AuthUnauthenticated());
      }
      // Si está activo, no hacemos nada (mantener estado actual)
    } catch (e) {
      // Si hay error, cerrar sesión
      emit(AuthUnauthenticated());
    }
  }
}
