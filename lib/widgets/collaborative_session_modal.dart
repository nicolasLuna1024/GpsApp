import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../bloc/collaborative_session_bloc.dart';
import '../bloc/team_bloc.dart';
import '../models/collaborative_session.dart';
import '../screens/map_screen.dart';
import '../config/supabase_config.dart';
import '../services/location_service.dart';

class CollaborativeSessionModal extends StatefulWidget {
  final bool isCompact; // Nueva propiedad para mostrar versión compacta

  const CollaborativeSessionModal({super.key, this.isCompact = false});

  @override
  State<CollaborativeSessionModal> createState() =>
      _CollaborativeSessionModalState();
}

class _CollaborativeSessionModalState extends State<CollaborativeSessionModal> {
  final TextEditingController _sessionNameController = TextEditingController();
  final TextEditingController _sessionDescriptionController =
      TextEditingController();
  String? _selectedTeamId;

  @override
  void initState() {
    super.initState();
    // Cargar equipos y sesiones al inicializar
    context.read<TeamBloc>().add(TeamLoadRequested());
    context.read<CollaborativeSessionBloc>().add(
      CollaborativeSessionsLoadRequested(),
    );
  }

  @override
  void dispose() {
    _sessionNameController.dispose();
    _sessionDescriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width:
            MediaQuery.of(context).size.width * (widget.isCompact ? 0.85 : 0.9),
        constraints: BoxConstraints(
          maxWidth: widget.isCompact ? 450 : 500,
          maxHeight: widget.isCompact ? 500 : double.infinity,
        ),
        padding: EdgeInsets.all(widget.isCompact ? 20 : 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.group_work,
                    color: Colors.blue[600],
                    size: widget.isCompact ? 24 : 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Sesiones Colaborativas',
                      style: TextStyle(
                        fontSize: widget.isCompact ? 18 : 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),

              SizedBox(height: widget.isCompact ? 16 : 24),

              // Lista de sesiones activas
              _buildActiveSessions(),

              if (!widget.isCompact) ...[
                const SizedBox(height: 24),
                // Divisor
                const Divider(),
                const SizedBox(height: 16),
                // Crear nueva sesión - solo en modo completo
                _buildCreateSessionForm(),
              ] else ...[
                const SizedBox(height: 16),
                // Botón crear nueva sesión - en modo compacto
                _buildCompactCreateButton(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveSessions() {
    return BlocConsumer<CollaborativeSessionBloc, CollaborativeSessionState>(
      listener: (context, state) {
        if (state is CollaborativeSessionError) {
          Fluttertoast.showToast(
            msg: state.message,
            toastLength: Toast.LENGTH_LONG,
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
        } else if (state is CollaborativeSessionOperationSuccess) {
          Fluttertoast.showToast(
            msg: state.message,
            toastLength: Toast.LENGTH_SHORT,
            backgroundColor: Colors.green,
            textColor: Colors.white,
          );

          // 🆕 Si tiene una sesión activa, mostrar diálogo para unirse automáticamente
          if (state.activeSession != null) {
            _showJoinSessionDialog(state.activeSession!);
          }
        } else if (state is CollaborativeSessionJoined) {
          // 🆕 Cuando se une a una sesión, navegar directamente al mapa
          _joinMapSession(state.session);
        }
      },
      builder: (context, state) {
        if (state is CollaborativeSessionLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is CollaborativeSessionLoaded) {
          final sessions = state.sessions;

          if (sessions.isEmpty) {
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No hay sesiones colaborativas activas',
                      style: const TextStyle(color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sesiones Activas',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...sessions.map((session) => _buildSessionCard(session)),
            ],
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildSessionCard(CollaborativeSession session) {
    final isParticipant = session.isParticipant;
    final currentUserId = SupabaseConfig.client.auth.currentUser?.id;
    final isCreator = session.createdBy == currentUserId;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Equipo: ${session.teamName ?? 'Desconocido'}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                      if (session.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          session.description!,
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isParticipant
                            ? Colors.green[100]
                            : Colors.blue[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${session.participantCount} participantes',
                        style: TextStyle(
                          fontSize: 12,
                          color: isParticipant
                              ? Colors.green[800]
                              : Colors.blue[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: Text(
                    'Creado por: ${session.creatorName ?? 'Desconocido'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                if (isParticipant) ...[
                  ElevatedButton.icon(
                    onPressed: () => _joinMapSession(session),
                    icon: const Icon(Icons.map, size: 16),
                    label: const Text('Ir al Mapa'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                  if (isCreator) ...[
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _endSession(session.id),
                      icon: const Icon(Icons.stop, size: 16),
                      label: const Text('Finalizar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                ] else ...[
                  ElevatedButton.icon(
                    onPressed: () => _joinSession(session.id),
                    icon: const Icon(Icons.login, size: 16),
                    label: const Text('Unirse'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateSessionForm() {
    return BlocBuilder<TeamBloc, TeamState>(
      builder: (context, teamState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Crear Nueva Sesión',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Campo de nombre
            TextField(
              controller: _sessionNameController,
              decoration: const InputDecoration(
                labelText: 'Nombre de la sesión',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.edit),
              ),
            ),

            const SizedBox(height: 12),

            // Campo de descripción
            TextField(
              controller: _sessionDescriptionController,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 2,
            ),

            const SizedBox(height: 12),

            // Selector de equipo
            if (teamState is TeamLoaded && teamState.teams.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                value: _selectedTeamId,
                decoration: const InputDecoration(
                  labelText: 'Seleccionar equipo',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.group),
                ),
                items: teamState.teams
                    .map(
                      (team) => DropdownMenuItem<String>(
                        value: team.id,
                        child: Text(team.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedTeamId = value;
                  });
                },
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('No tienes equipos disponibles'),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Botón crear
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _canCreateSession() ? _createSession : null,
                icon: const Icon(Icons.add),
                label: const Text('Crear Sesión Colaborativa'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  bool _canCreateSession() {
    return _sessionNameController.text.trim().isNotEmpty &&
        _selectedTeamId != null;
  }

  void _createSession() {
    if (!_canCreateSession()) return;

    context.read<CollaborativeSessionBloc>().add(
      CollaborativeSessionCreateRequested(
        name: _sessionNameController.text.trim(),
        description: _sessionDescriptionController.text.trim().isEmpty
            ? null
            : _sessionDescriptionController.text.trim(),
        teamId: _selectedTeamId!,
      ),
    );

    // 🆕 No limpiar el formulario aquí - se limpiará después del éxito
    // El formulario se mantendrá hasta que se confirme la creación exitosa
  }

  void _clearForm() {
    _sessionNameController.clear();
    _sessionDescriptionController.clear();
    setState(() {
      _selectedTeamId = null;
    });
  }

  void _joinSession(String sessionId) {
    context.read<CollaborativeSessionBloc>().add(
      CollaborativeSessionJoinRequested(sessionId),
    );
  }

  void _endSession(String sessionId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finalizar Sesión'),
        content: const Text(
          '¿Estás seguro de que quieres finalizar esta sesión colaborativa? '
          'Todos los participantes serán desconectados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              
              // 🆕 Limpiar sesión activa si es la misma que se está finalizando
              final activeSessionId = LocationService.getActiveCollaborativeSession();
              if (activeSessionId == sessionId) {
                LocationService.setActiveCollaborativeSession(null);
                print('🎯 Sesión colaborativa limpiada: $sessionId');
              }
              
              context.read<CollaborativeSessionBloc>().add(
                CollaborativeSessionEndRequested(sessionId),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
  }

  void _joinMapSession(CollaborativeSession session) {
    Navigator.of(context).pop(); // Cerrar el modal

    // 🆕 Configurar la sesión activa en LocationService
    LocationService.setActiveCollaborativeSession(session.id);
    print('🎯 Sesión colaborativa configurada: ${session.id}');

    // Navegar al mapa con la sesión colaborativa
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            // LocationBloc ya está disponible globalmente
            BlocProvider<CollaborativeSessionBloc>.value(
              value: globalCollaborativeSessionBloc,
            ),
          ],
          child: MapScreen(),
        ),
      ),
    );
  }

  Widget _buildCompactCreateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _showCreateSessionDialog,
        icon: const Icon(Icons.add),
        label: const Text('Crear Nueva Sesión'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[600],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  void _showCreateSessionDialog() {
    Navigator.of(context).pop(); // Cerrar modal actual
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (context) => TeamBloc()..add(TeamLoadRequested()),
            ),
            BlocProvider<CollaborativeSessionBloc>.value(
              value: globalCollaborativeSessionBloc,
            ),
          ],
          child: const CollaborativeSessionModal(
            isCompact: false,
          ), // Mostrar versión completa
        );
      },
    );
  }

  // 🆕 Método para mostrar diálogo de confirmación después de crear sesión
  void _showJoinSessionDialog(CollaborativeSession session) {
    showDialog(
      context: context,
      barrierDismissible: false, // No permitir cerrar tocando fuera
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green[600]),
              const SizedBox(width: 12),
              const Expanded(child: Text('¡Sesión Creada!')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('La sesión "${session.name}" ha sido creada exitosamente.'),
              const SizedBox(height: 16),
              const Text(
                '¿Qué te gustaría hacer?',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Cerrar diálogo
                Navigator.of(context).pop(); // Cerrar modal principal
                _clearForm(); // Limpiar formulario al salir
              },
              child: const Text('Volver al Inicio'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Cerrar diálogo
                _clearForm(); // Limpiar formulario antes de ir al mapa
                _joinMapSession(session); // Ir directo al mapa
              },
              icon: const Icon(Icons.map),
              label: const Text('Ir al Mapa'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }
}
