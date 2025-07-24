import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/team.dart';
import '../models/user_profile.dart';
import '../services/team_service.dart';

// Eventos del BLoC de Team
abstract class TeamEvent {}

class TeamLoadRequested extends TeamEvent {}

class TeamMembersLoadRequested extends TeamEvent {
  final String? teamId;
  TeamMembersLoadRequested({this.teamId});
}

class TeamSelectRequested extends TeamEvent {
  final String teamId;
  TeamSelectRequested(this.teamId);
}

// Estados del BLoC de Team
abstract class TeamState {}

class TeamInitial extends TeamState {}

class TeamLoading extends TeamState {}

class TeamLoaded extends TeamState {
  final List<Team> teams;
  final Team? selectedTeam;
  final List<UserProfile> members;

  TeamLoaded({
    this.teams = const [],
    this.selectedTeam,
    this.members = const [],
  });

  TeamLoaded copyWith({
    List<Team>? teams,
    Team? selectedTeam,
    List<UserProfile>? members,
    bool clearSelectedTeam = false,
  }) {
    return TeamLoaded(
      teams: teams ?? this.teams,
      selectedTeam: clearSelectedTeam
          ? null
          : selectedTeam ?? this.selectedTeam,
      members: members ?? this.members,
    );
  }
}

class TeamError extends TeamState {
  final String message;

  TeamError(this.message);
}

// BLoC de Team
class TeamBloc extends Bloc<TeamEvent, TeamState> {
  TeamBloc() : super(TeamInitial()) {
    on<TeamLoadRequested>(_onTeamLoadRequested);
    on<TeamMembersLoadRequested>(_onTeamMembersLoadRequested);
    on<TeamSelectRequested>(_onTeamSelectRequested);
  }

  Future<void> _onTeamLoadRequested(
    TeamLoadRequested event,
    Emitter<TeamState> emit,
  ) async {
    emit(TeamLoading());

    try {
      final teams = await TeamService.getUserTeams();

      // Seleccionar el primer equipo por defecto si hay equipos
      final selectedTeam = teams.isNotEmpty ? teams.first : null;
      List<UserProfile> members = [];

      if (selectedTeam != null) {
        members = await TeamService.getTeamMembers(selectedTeam.id);
      }

      emit(
        TeamLoaded(teams: teams, selectedTeam: selectedTeam, members: members),
      );
    } catch (e) {
      emit(TeamError('Error cargando información del equipo: $e'));
    }
  }

  Future<void> _onTeamMembersLoadRequested(
    TeamMembersLoadRequested event,
    Emitter<TeamState> emit,
  ) async {
    if (state is TeamLoaded) {
      final currentState = state as TeamLoaded;

      try {
        final teamId = event.teamId ?? currentState.selectedTeam?.id;
        if (teamId != null) {
          final members = await TeamService.getTeamMembers(teamId);
          emit(currentState.copyWith(members: members));
        }
      } catch (e) {
        emit(TeamError('Error cargando miembros del equipo: $e'));
      }
    }
  }

  Future<void> _onTeamSelectRequested(
    TeamSelectRequested event,
    Emitter<TeamState> emit,
  ) async {
    if (state is TeamLoaded) {
      final currentState = state as TeamLoaded;

      try {
        // Encontrar el equipo seleccionado
        final selectedTeam = currentState.teams.firstWhere(
          (team) => team.id == event.teamId,
        );

        // Cargar miembros del equipo seleccionado
        final members = await TeamService.getTeamMembers(event.teamId);

        emit(
          currentState.copyWith(selectedTeam: selectedTeam, members: members),
        );
      } catch (e) {
        emit(TeamError('Error seleccionando equipo: $e'));
      }
    }
  }
}
