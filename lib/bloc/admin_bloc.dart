import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/user_profile.dart';
import '../models/user_location.dart';
import '../services/admin_service.dart';

// Eventos de administración
abstract class AdminEvent {}

class AdminLoadUsers extends AdminEvent {}

class AdminLoadStats extends AdminEvent {}

class AdminLoadTeams extends AdminEvent {}

class AdminLoadActiveLocations extends AdminEvent {}

class AdminRefreshTeams extends AdminEvent {}

class AdminCreateUser extends AdminEvent {
  final String email;
  final String password;
  final String fullName;
  final String role;
  final String? teamId;

  AdminCreateUser({
    required this.email,
    required this.password,
    required this.fullName,
    required this.role,
    this.teamId,
  });
}

class AdminUpdateUser extends AdminEvent {
  final String userId;
  final String? fullName;
  final String? role;
  final String? teamId;
  final bool? isActive;

  AdminUpdateUser({
    required this.userId,
    this.fullName,
    this.role,
    this.teamId,
    this.isActive,
  });
}

class AdminDeactivateUser extends AdminEvent {
  final String userId;
  AdminDeactivateUser(this.userId);
}

class AdminActivateUser extends AdminEvent {
  final String userId;
  AdminActivateUser(this.userId);
}

class AdminCreateTeam extends AdminEvent {
  final String name;
  final String? description;
  final String? leaderId;

  AdminCreateTeam({required this.name, this.description, this.leaderId});
}

class AdminUpdateTeam extends AdminEvent {
  final String teamId;
  final String? name;
  final String? description;
  final String? leaderId;
  final bool? isActive;

  AdminUpdateTeam({
    required this.teamId,
    this.name,
    this.description,
    this.leaderId,
    this.isActive,
  });
}

class AdminDeleteTeam extends AdminEvent {
  final String teamId;
  AdminDeleteTeam(this.teamId);
}

class AdminToggleTeamStatus extends AdminEvent {
  final String teamId;
  final bool isActive;
  AdminToggleTeamStatus(this.teamId, this.isActive);
}

class AdminAddUserToTeam extends AdminEvent {
  final String userId;
  final String teamId;
  AdminAddUserToTeam(this.userId, this.teamId);
}

class AdminRemoveUserFromTeam extends AdminEvent {
  final String userId;
  final String teamId;
  AdminRemoveUserFromTeam(this.userId, this.teamId);
}

class AdminLoadAvailableUsers extends AdminEvent {
  final String teamId;
  AdminLoadAvailableUsers(this.teamId);
}

class AdminLoadTeamMembers extends AdminEvent {
  final String teamId;
  AdminLoadTeamMembers(this.teamId);
}

class AdminLoadUserHistory extends AdminEvent {
  final String userId;
  final DateTime? startDate;
  final DateTime? endDate;

  AdminLoadUserHistory({required this.userId, this.startDate, this.endDate});
}

// Estados de administración
abstract class AdminState {}

class AdminInitial extends AdminState {}

class AdminLoading extends AdminState {}

class AdminLoaded extends AdminState {
  final List<UserProfile> users;
  final Map<String, dynamic> stats;
  final List<Map<String, dynamic>> teams;
  final List<UserLocation> activeLocations;
  final List<UserProfile> availableUsers;
  final List<UserProfile> teamMembers;

  AdminLoaded({
    this.users = const [],
    this.stats = const {},
    this.teams = const [],
    this.activeLocations = const [],
    this.availableUsers = const [],
    this.teamMembers = const [],
  });

  AdminLoaded copyWith({
    List<UserProfile>? users,
    Map<String, dynamic>? stats,
    List<Map<String, dynamic>>? teams,
    List<UserLocation>? activeLocations,
    List<UserProfile>? availableUsers,
    List<UserProfile>? teamMembers,
  }) {
    return AdminLoaded(
      users: users ?? this.users,
      stats: stats ?? this.stats,
      teams: teams ?? this.teams,
      activeLocations: activeLocations ?? this.activeLocations,
      availableUsers: availableUsers ?? this.availableUsers,
      teamMembers: teamMembers ?? this.teamMembers,
    );
  }
}

class AdminUserHistoryLoaded extends AdminState {
  final List<UserLocation> locationHistory;
  final String userId;

  AdminUserHistoryLoaded({required this.locationHistory, required this.userId});
}

class AdminSuccess extends AdminState {
  final String message;
  AdminSuccess(this.message);
}

class AdminError extends AdminState {
  final String message;
  AdminError(this.message);
}

class AdminAccessDenied extends AdminState {}

// BLoC de administración
class AdminBloc extends Bloc<AdminEvent, AdminState> {
  AdminBloc() : super(AdminInitial()) {
    on<AdminLoadUsers>(_onLoadUsers);
    on<AdminLoadStats>(_onLoadStats);
    on<AdminLoadTeams>(_onLoadTeams);
    on<AdminLoadActiveLocations>(_onLoadActiveLocations);
    on<AdminCreateUser>(_onCreateUser);
    on<AdminUpdateUser>(_onUpdateUser);
    on<AdminDeactivateUser>(_onDeactivateUser);
    on<AdminActivateUser>(_onActivateUser);
    on<AdminCreateTeam>(_onCreateTeam);
    on<AdminUpdateTeam>(_onUpdateTeam);
    on<AdminDeleteTeam>(_onDeleteTeam);
    on<AdminToggleTeamStatus>(_onToggleTeamStatus);
    on<AdminAddUserToTeam>(_onAddUserToTeam);
    on<AdminRemoveUserFromTeam>(_onRemoveUserFromTeam);
    on<AdminLoadAvailableUsers>(_onLoadAvailableUsers);
    on<AdminLoadTeamMembers>(_onLoadTeamMembers);
    on<AdminLoadUserHistory>(_onLoadUserHistory);  }
  

  Future<void> _onLoadUsers(
    AdminLoadUsers event,
    Emitter<AdminState> emit,
  ) async {
    try {
      // Verificar permisos de admin
      final isAdmin = await AdminService.isCurrentUserAdmin();
      if (!isAdmin) {
        emit(AdminAccessDenied());
        return;
      }

      emit(AdminLoading());

      final users = await AdminService.getAllUsers();
      final currentState = state is AdminLoaded
          ? state as AdminLoaded
          : AdminLoaded();

      emit(currentState.copyWith(users: users));
    } catch (e) {
      emit(AdminError('Error al cargar usuarios: $e'));
    }
  }

  Future<void> _onLoadStats(
    AdminLoadStats event,
    Emitter<AdminState> emit,
  ) async {
    try {
      final isAdmin = await AdminService.isCurrentUserAdmin();
      if (!isAdmin) {
        emit(AdminAccessDenied());
        return;
      }

      final stats = await AdminService.getSystemStats();
      final currentState = state is AdminLoaded
          ? state as AdminLoaded
          : AdminLoaded();

      emit(currentState.copyWith(stats: stats));
    } catch (e) {
      emit(AdminError('Error al cargar estadísticas: $e'));
    }
  }

  Future<void> _onLoadTeams(
    AdminLoadTeams event,
    Emitter<AdminState> emit,
  ) async {
    try {
      final teams = await AdminService.getTeams();

      final currentState = state is AdminLoaded
          ? (state as AdminLoaded)
          : AdminLoaded();

      emit(
        currentState.copyWith(
          teams: List.from(teams),
        ),
      );
    } catch (e) {
      emit(AdminError('Error al cargar equipos: $e'));
    }
  }

  Future<void> _onLoadActiveLocations(
    AdminLoadActiveLocations event,
    Emitter<AdminState> emit,
  ) async {
    try {
      final isAdmin = await AdminService.isCurrentUserAdmin();
      if (!isAdmin) {
        emit(AdminAccessDenied());
        return;
      }

      final locations = await AdminService.getAllActiveLocations();
      final currentState = state is AdminLoaded
          ? state as AdminLoaded
          : AdminLoaded();

      emit(currentState.copyWith(activeLocations: locations));
    } catch (e) {
      emit(AdminError('Error al cargar ubicaciones: $e'));
    }
  }

  Future<void> _onCreateUser(
    AdminCreateUser event,
    Emitter<AdminState> emit,
  ) async {
    try {
      final isAdmin = await AdminService.isCurrentUserAdmin();
      if (!isAdmin) {
        emit(AdminAccessDenied());
        return;
      }

      emit(AdminLoading());

      final success = await AdminService.createUser(
        email: event.email,
        password: event.password,
        fullName: event.fullName,
        role: event.role,
        teamId: event.teamId,
      );

      if (success) {
        // Recargar todos los datos directamente
        final users = await AdminService.getAllUsers();
        final stats = await AdminService.getSystemStats();
        final teams = await AdminService.getTeams();
        final activeLocations = await AdminService.getAllActiveLocations();

        final currentState = state is AdminLoaded
            ? state as AdminLoaded
            : AdminLoaded();

        emit(
          currentState.copyWith(
            users: users,
            stats: stats,
            teams: teams,
            activeLocations: activeLocations,
          ),
        );

        emit(AdminSuccess('Usuario creado exitosamente'));
      } else {
        emit(AdminError('Error al crear usuario'));
      }
    } catch (e) {
      emit(AdminError('Error al crear usuario: $e'));
    }
  }

  Future<void> _onUpdateUser(
    AdminUpdateUser event,
    Emitter<AdminState> emit,
  ) async {
    try {
      final isAdmin = await AdminService.isCurrentUserAdmin();
      if (!isAdmin) {
        emit(AdminAccessDenied());
        return;
      }

      final success = await AdminService.updateUser(
        userId: event.userId,
        fullName: event.fullName,
        role: event.role,
        teamId: event.teamId,
        isActive: event.isActive,
      );

      if (success) {
        // Recargar todos los datos directamente
        final users = await AdminService.getAllUsers();
        final stats = await AdminService.getSystemStats();
        final teams = await AdminService.getTeams();
        final activeLocations = await AdminService.getAllActiveLocations();

        final currentState = state is AdminLoaded
            ? state as AdminLoaded
            : AdminLoaded();

        emit(
          currentState.copyWith(
            users: users,
            stats: stats,
            teams: teams,
            activeLocations: activeLocations,
          ),
        );

        emit(AdminSuccess('Usuario actualizado exitosamente'));
      } else {
        emit(AdminError('Error al actualizar usuario'));
      }
    } catch (e) {
      emit(AdminError('Error al actualizar usuario: $e'));
    }
  }

  Future<void> _onDeactivateUser(
    AdminDeactivateUser event,
    Emitter<AdminState> emit,
  ) async {
    try {
      final isAdmin = await AdminService.isCurrentUserAdmin();
      if (!isAdmin) {
        emit(AdminAccessDenied());
        return;
      }

      final success = await AdminService.deactivateUser(event.userId);

      if (success) {
        emit(AdminSuccess('Usuario desactivado exitosamente'));
        add(AdminLoadUsers());
      } else {
        emit(AdminError('Error al desactivar usuario'));
      }
    } catch (e) {
      emit(AdminError('Error al desactivar usuario: $e'));
    }
  }

  Future<void> _onActivateUser(
    AdminActivateUser event,
    Emitter<AdminState> emit,
  ) async {
    try {
      final isAdmin = await AdminService.isCurrentUserAdmin();
      if (!isAdmin) {
        emit(AdminAccessDenied());
        return;
      }

      final success = await AdminService.activateUser(event.userId);

      if (success) {
        emit(AdminSuccess('Usuario activado exitosamente'));
        add(AdminLoadUsers());
      } else {
        emit(AdminError('Error al activar usuario'));
      }
    } catch (e) {
      emit(AdminError('Error al activar usuario: $e'));
    }
  }

  Future<void> _onCreateTeam(
    AdminCreateTeam event,
    Emitter<AdminState> emit,
  ) async {
    try {
      emit(AdminLoading());

      final isAdmin = await AdminService.isCurrentUserAdmin();
      if (!isAdmin) {
        emit(AdminAccessDenied());
        return;
      }

      final success = await AdminService.createTeam(
        name: event.name,
        description: event.description,
        leaderId: event.leaderId,
      );

      if (success) {
        emit(AdminSuccess('Equipo creado exitosamente'));
      } else {
        emit(AdminError('Error al crear equipo'));
      }
    } catch (e) {
      emit(AdminError('Error al crear equipo: $e'));
    }
  }

  Future<void> _onUpdateTeam(
    AdminUpdateTeam event,
    Emitter<AdminState> emit,
  ) async {
    try {
      final isAdmin = await AdminService.isCurrentUserAdmin();
      if (!isAdmin) {
        emit(AdminAccessDenied());
        return;
      }

      final success = await AdminService.updateTeam(
        teamId: event.teamId,
        name: event.name,
        description: event.description,
        leaderId: event.leaderId,
        isActive: event.isActive,
      );

      if (success) {
        emit(AdminSuccess('Equipo actualizado exitosamente'));
      } else {
        emit(AdminError('Error al actualizar equipo'));
      }
    } catch (e) {
      emit(AdminError('Error al actualizar equipo: $e'));
    }
  }

  Future<void> _onDeleteTeam(
    AdminDeleteTeam event,
    Emitter<AdminState> emit,
  ) async {
    try {
      final isAdmin = await AdminService.isCurrentUserAdmin();
      if (!isAdmin) {
        emit(AdminAccessDenied());
        return;
      }

      final success = await AdminService.deleteTeam(event.teamId);

      if (success) {
        emit(AdminSuccess('Equipo eliminado exitosamente'));
      } else {
        emit(AdminError('Error al eliminar equipo'));
      }
    } catch (e) {
      emit(AdminError('Error al eliminar equipo: $e'));
    }
  }

  Future<void> _onToggleTeamStatus(
    AdminToggleTeamStatus event,
    Emitter<AdminState> emit,
  ) async {
    try {
      final isAdmin = await AdminService.isCurrentUserAdmin();
      if (!isAdmin) {
        emit(AdminAccessDenied());
        return;
      }

      final success = await AdminService.toggleTeamStatus(
        event.teamId,
        event.isActive,
      );

      if (success) {
        emit(AdminSuccess('Estado del equipo actualizado exitosamente'));
      } else {
        emit(AdminError('Error al cambiar estado del equipo'));
      }
    } catch (e) {
      emit(AdminError('Error al cambiar estado del equipo: $e'));
    }
  }

  Future<void> _onAddUserToTeam(
    AdminAddUserToTeam event,
    Emitter<AdminState> emit,
  ) async {
    try {
      emit(AdminLoading());
      final success = await AdminService.addUserToTeam(
        event.userId,
        event.teamId,
      );

      if (success) {
        emit(AdminSuccess('Usuario agregado al equipo correctamente.'));
      } else {
        emit(AdminError('No se pudo agregar el usuario.'));
      }
    } catch (e) {
      emit(AdminError('Error al agregar usuario: $e'));
    }
  }

  Future<void> _onRemoveUserFromTeam(
    AdminRemoveUserFromTeam event,
    Emitter<AdminState> emit,
  ) async {
    try {
      final isAdmin = await AdminService.isCurrentUserAdmin();
      if (!isAdmin) {
        emit(AdminAccessDenied());
        return;
      }

      final success = await AdminService.removeUserFromTeam(
        event.userId,
        event.teamId,
      );

      if (success) {
        emit(AdminSuccess('Usuario removido del equipo exitosamente'));
      } else {
        emit(AdminError('Error al remover usuario del equipo'));
      }
    } catch (e) {
      emit(AdminError('Error al remover usuario: $e'));
    }
  }

  Future<void> _onLoadAvailableUsers(
    AdminLoadAvailableUsers event,
    Emitter<AdminState> emit,
  ) async {
    try {
      final isAdmin = await AdminService.isCurrentUserAdmin();
      if (!isAdmin) {
        emit(AdminAccessDenied());
        return;
      }

      final availableUsers = await AdminService.getAvailableUsers(event.teamId);
      final currentState = state is AdminLoaded
          ? state as AdminLoaded
          : AdminLoaded();

      emit(currentState.copyWith(availableUsers: availableUsers));
    } catch (e) {
      emit(AdminError('Error al cargar usuarios disponibles: $e'));
    }
  }

  Future<void> _onLoadTeamMembers(
    AdminLoadTeamMembers event,
    Emitter<AdminState> emit,
  ) async {
    try {
      final isAdmin = await AdminService.isCurrentUserAdmin();
      if (!isAdmin) {
        emit(AdminAccessDenied());
        return;
      }

      final teamMembers = await AdminService.getTeamMembers(event.teamId);

      final currentState = state is AdminLoaded
          ? state as AdminLoaded
          : AdminLoaded();

      emit(currentState.copyWith(teamMembers: teamMembers));
    } catch (e) {
      emit(AdminError('Error al cargar miembros del equipo: $e'));
    }
  }

  Future<void> _onLoadUserHistory(
    AdminLoadUserHistory event,
    Emitter<AdminState> emit,
  ) async {
    try {
      final isAdmin = await AdminService.isCurrentUserAdmin();
      if (!isAdmin) {
        emit(AdminAccessDenied());
        return;
      }

      emit(AdminLoading());

      final history = await AdminService.getUserLocationHistory(
        event.userId,
        startDate: event.startDate,
        endDate: event.endDate,
      );

      emit(
        AdminUserHistoryLoaded(locationHistory: history, userId: event.userId),
      );
    } catch (e) {
      emit(AdminError('Error al cargar historial: $e'));
    }
  }
}
