import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/admin_bloc.dart';
import '../models/user_profile.dart';

class TeamMembersDialog extends StatefulWidget {
  final Map<String, dynamic> team;

  const TeamMembersDialog({super.key, required this.team});

  @override
  State<TeamMembersDialog> createState() => _TeamMembersDialogState();
}

class _TeamMembersDialogState extends State<TeamMembersDialog>
    with TickerProviderStateMixin {
  late TabController _tabController;
  StreamSubscription<AdminState>? _stateSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Setup state listener
    _setupStateListener();
  }

  void _setupStateListener() {
    final adminBloc = context.read<AdminBloc>();
    _stateSubscription = adminBloc.stream.listen((state) {
      if (!mounted) return;

      if (state is AdminSuccess) {
        _handleSuccess(state.message);
      } else if (state is AdminError) {
        _handleError(state.message);
      }
    });
  }

  void _handleSuccess(String message) {
    if (message.contains('agregado') ||
        message.contains('removido') ||
        message.contains('usuario') && message.contains('equipo')) {
      context.read<AdminBloc>().add(AdminLoadTeams());
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
    }
  }

  void _handleError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $message'), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _stateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Gestionar Miembros del Equipo'),
      content: SizedBox(
        width: double.maxFinite,
        height: 500,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTeamHeader(),
            const SizedBox(height: 16),
            Expanded(
              child: Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    labelColor: Colors.purple,
                    unselectedLabelColor: Colors.grey,
                    tabs: const [
                      Tab(text: 'Miembros Actuales'),
                      Tab(text: 'Agregar Miembros'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildCurrentMembersTab(),
                        _buildAddMembersTab(),
                      ],
                    ),
                  ),
                ],
              ),
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
    );
  }

  Widget _buildTeamHeader() {
    return Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.purple[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.group, color: Colors.purple, size: 30),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.team['name'] ?? 'Sin nombre',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
              if (widget.team['description'] != null)
                Text(
                  widget.team['description'],
                  style: TextStyle(fontSize: 12, color: Colors.purple[700]),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentMembersTab() {
    return BlocBuilder<AdminBloc, AdminState>(
      builder: (context, state) {
        List<UserProfile> teamMembers = [];

        if (state is AdminLoaded) {
          final currentTeam = state.teams.firstWhere(
            (t) => t['id'] == widget.team['id'],
            orElse: () => <String, dynamic>{},
          );

          if (currentTeam['members'] != null) {
            teamMembers = List<UserProfile>.from(currentTeam['members']);
          }
        }

        if (teamMembers.isEmpty) {
          return const Center(child: Text('No hay miembros en este equipo'));
        }

        return ListView.builder(
          itemCount: teamMembers.length,
          itemBuilder: (context, index) {
            final member = teamMembers[index];
            return _buildMemberTile(member, isCurrentMember: true);
          },
        );
      },
    );
  }

  Widget _buildAddMembersTab() {
    return BlocBuilder<AdminBloc, AdminState>(
      builder: (context, state) {
        List<UserProfile> availableUsers = [];

        if (state is AdminLoaded) {
          final currentTeam = state.teams.firstWhere(
            (t) => t['id'] == widget.team['id'],
            orElse: () => <String, dynamic>{},
          );

          List<UserProfile> teamMembers = [];
          if (currentTeam['members'] != null) {
            teamMembers = List<UserProfile>.from(currentTeam['members']);
          }

          final allUsers = state.users;
          final teamMemberIds = teamMembers.map((m) => m.id).toSet();
          availableUsers = allUsers
              .where(
                (user) => !teamMemberIds.contains(user.id) && user.isActive,
              )
              .toList();
        }

        if (availableUsers.isEmpty) {
          return const Center(
            child: Text('No hay usuarios disponibles para agregar'),
          );
        }

        return ListView.builder(
          itemCount: availableUsers.length,
          itemBuilder: (context, index) {
            final user = availableUsers[index];
            return _buildMemberTile(user, isCurrentMember: false);
          },
        );
      },
    );
  }

  Widget _buildMemberTile(UserProfile user, {required bool isCurrentMember}) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: user.role == 'admin' ? Colors.red : Colors.green,
        child: Text(
          user.fullName?.substring(0, 1).toUpperCase() ?? 'U',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        user.fullName ?? 'Sin nombre',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text('${user.role} • ${user.email}'),
      trailing: IconButton(
        icon: Icon(
          isCurrentMember ? Icons.remove_circle : Icons.add_circle,
          color: isCurrentMember ? Colors.red : Colors.green,
        ),
        onPressed: () {
          if (isCurrentMember) {
            _removeUserFromTeam(user.id);
          } else {
            _addUserToTeam(user.id);
          }
        },
      ),
    );
  }

  void _removeUserFromTeam(String userId) {
    context.read<AdminBloc>().add(AdminRemoveUserFromTeam(
      userId,
      widget.team['id'],
    ));
  }

  void _addUserToTeam(String userId) {
    context.read<AdminBloc>().add(
      AdminAddUserToTeam(userId, widget.team['id']),
    );
  }
}
