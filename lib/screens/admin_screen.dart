import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../bloc/admin_bloc.dart';
import '../models/user_profile.dart';
import '../models/user_location.dart';
import '../widgets/team_members_dialog.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    // Cargar datos iniciales
    context.read<AdminBloc>()
      ..add(AdminLoadUsers())
      ..add(AdminLoadStats())
      ..add(AdminLoadTeams())
      ..add(AdminLoadActiveLocations());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Panel de Administración',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.red[600],
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
            Tab(icon: Icon(Icons.people), text: 'Usuarios'),
            Tab(icon: Icon(Icons.location_on), text: 'Ubicaciones'),
            Tab(icon: Icon(Icons.group), text: 'Equipos'),
          ],
        ),
      ),
      body: BlocListener<AdminBloc, AdminState>(
        listener: (context, state) {
          if (state is AdminAccessDenied) {
            Fluttertoast.showToast(
              msg: 'No tienes permisos de administrador',
              toastLength: Toast.LENGTH_LONG,
              gravity: ToastGravity.BOTTOM,
              backgroundColor: Colors.red,
              textColor: Colors.white,
            );
            Navigator.of(context).pop();
          } else if (state is AdminError) {
            Fluttertoast.showToast(
              msg: state.message,
              toastLength: Toast.LENGTH_LONG,
              gravity: ToastGravity.BOTTOM,
              backgroundColor: Colors.red,
              textColor: Colors.white,
            );
          } else if (state is AdminSuccess) {
            Fluttertoast.showToast(
              msg: state.message,
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
              backgroundColor: Colors.green,
              textColor: Colors.white,
            );
            context.read<AdminBloc>().add(AdminLoadTeams());
            context.read<AdminBloc>().add(AdminLoadUsers());
            context.read<AdminBloc>().add(AdminLoadStats());
            context.read<AdminBloc>().add(AdminLoadActiveLocations());
          }
        },
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildDashboardTab(),
            _buildUsersTab(),
            _buildLocationsTab(),
            _buildTeamsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardTab() {
    return BlocBuilder<AdminBloc, AdminState>(
      builder: (context, state) {
        if (state is AdminLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        Map<String, dynamic> stats = {};
        if (state is AdminLoaded) {
          stats = state.stats;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Estadísticas del Sistema',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),

              // Tarjetas de estadísticas
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildStatCard(
                    'Usuarios Totales',
                    '${stats['total_users'] ?? 0}',
                    Icons.people,
                    Colors.blue,
                  ),
                  _buildStatCard(
                    'Usuarios Activos',
                    '${stats['active_users'] ?? 0}',
                    Icons.people_alt,
                    Colors.green,
                  ),
                  _buildStatCard(
                    'Administradores',
                    '${stats['admins'] ?? 0}',
                    Icons.admin_panel_settings,
                    Colors.orange,
                  ),
                  _buildStatCard(
                    'Topógrafos',
                    '${stats['topografos'] ?? 0}',
                    Icons.map,
                    Colors.purple,
                  ),
                  _buildStatCard(
                    'Ubicaciones Hoy',
                    '${stats['locations_today'] ?? 0}',
                    Icons.location_on,
                    Colors.red,
                  ),
                  _buildStatCard(
                    'Sistema',
                    'Activo',
                    Icons.check_circle,
                    Colors.teal,
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Botones de acción rápida
              const Text(
                'Acciones Rápidas',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showCreateUserDialog(context),
                      icon: const Icon(Icons.person_add),
                      label: const Text('Nuevo Usuario'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showCreateTeamDialog(context),
                      icon: const Icon(Icons.group_add),
                      label: const Text('Nuevo Equipo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUsersTab() {
    return BlocBuilder<AdminBloc, AdminState>(
      builder: (context, state) {
        if (state is AdminLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        List<UserProfile> users = [];
        if (state is AdminLoaded) {
          users = state.users;
        }

        return Column(
          children: [
            // Header con botón de agregar
            Container(
              padding: const EdgeInsets.all(16.0),
              color: Colors.grey[100],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Usuarios (${users.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateUserDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Lista de usuarios
            Expanded(
              child: users.isEmpty
                  ? const Center(
                      child: Text(
                        'No hay usuarios registrados',
                        style: TextStyle(fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        return _buildUserCard(user);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLocationsTab() {
    return BlocBuilder<AdminBloc, AdminState>(
      builder: (context, state) {
        if (state is AdminLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        List<UserLocation> locations = [];
        if (state is AdminLoaded) {
          locations = state.activeLocations;
        }

        return Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16.0),
              color: Colors.grey[100],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ubicaciones Activas (${locations.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      context.read<AdminBloc>().add(AdminLoadActiveLocations());
                    },
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),

            // Lista de ubicaciones
            Expanded(
              child: locations.isEmpty
                  ? const Center(
                      child: Text(
                        'No hay ubicaciones activas',
                        style: TextStyle(fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      itemCount: locations.length,
                      itemBuilder: (context, index) {
                        final location = locations[index];
                        return _buildLocationCard(location);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTeamsTab() {
    return BlocBuilder<AdminBloc, AdminState>(
      builder: (context, state) {
        if (state is AdminLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        List<Map<String, dynamic>> teams = [];
        if (state is AdminLoaded) {
          teams = state.teams;
        }

        return Column(
          children: [
            // Header con botón de agregar
            Container(
              padding: const EdgeInsets.all(16.0),
              color: Colors.grey[100],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Equipos (${teams.length})',
                    style: const TextStyle(
                      fontSize: 18,

                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateTeamDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Lista de equipos
            Expanded(
              child: teams.isEmpty
                  ? const Center(
                      child: Text(
                        'No hay equipos registrados',
                        style: TextStyle(fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      itemCount: teams.length,
                      itemBuilder: (context, index) {
                        final team = teams[index];
                        return _buildTeamCard(team);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(UserProfile user) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: user.isActive ? Colors.green : Colors.red,
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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.email),
            Text(
              'Rol: ${user.role} • ${user.isActive ? 'Activo' : 'Inactivo'}',
              style: TextStyle(
                color: user.isActive ? Colors.green : Colors.red,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleUserAction(value, user),
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('Editar')),
            PopupMenuItem(
              value: user.isActive ? 'deactivate' : 'activate',
              child: Text(user.isActive ? 'Desactivar' : 'Activar'),
            ),
            const PopupMenuItem(value: 'history', child: Text('Ver Historial')),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard(UserLocation location) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.blue,
          child: Icon(Icons.location_on, color: Colors.white),
        ),
        title: Text('Usuario: ${location.userId}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Lat: ${location.latitude.toStringAsFixed(6)}'),
            Text('Lng: ${location.longitude.toStringAsFixed(6)}'),
            Text(_formatDateTime(location.timestamp)),
          ],
        ),
        trailing: Text(
          '${location.accuracy?.toStringAsFixed(1) ?? 'N/A'}m',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
      ),
    );
  }

  Widget _buildTeamCard(Map<String, dynamic> team) {
    final members = (team['users_id'] as List?) ?? [];
    final activeMembersCount = team['active_members_count'] ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: team['is_active'] == true
              ? Colors.purple
              : Colors.grey,
          child: Icon(Icons.group, color: Colors.white),
        ),
        title: Text(
          team['name'] ?? 'Sin nombre',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (team['description'] != null) Text(team['description']),
            Text('Miembros activos: $activeMembersCount/${members.length}'),
            Text(
              'Estado: ${team['is_active'] == true ? 'Activo' : 'Inactivo'}',
              style: TextStyle(
                fontSize: 12,
                color: team['is_active'] == true ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleTeamAction(value, team),
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'view', child: Text('Ver Detalles')),
            const PopupMenuItem(value: 'edit', child: Text('Editar')),
            const PopupMenuItem(
              value: 'manage',
              child: Text('Gestionar Miembros'),
            ),
            PopupMenuItem(
              value: team['is_active'] == true ? 'deactivate' : 'activate',
              child: Text(team['is_active'] == true ? 'Desactivar' : 'Activar'),
            ),
            const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
          ],
        ),
        onTap: () => _showTeamDetails(context, team),
      ),
    );
  }

  void _handleUserAction(String action, UserProfile user) {
    switch (action) {
      case 'edit':
        _showEditUserDialog(context, user);
        break;
      case 'deactivate':
        context.read<AdminBloc>().add(AdminDeactivateUser(user.id));
        break;
      case 'activate':
        context.read<AdminBloc>().add(AdminActivateUser(user.id));
        break;
      case 'history':
        // Implementar vista de historial
        break;
    }
  }

  void _handleTeamAction(String action, Map<String, dynamic> team) {
    switch (action) {
      case 'view':
        _showTeamDetails(context, team);
        break;
      case 'edit':
        _showEditTeamDialog(context, team);
        break;
      case 'manage':
        _showManageTeamMembersDialog(context, team);
        break;
      case 'activate':
        context.read<AdminBloc>().add(AdminToggleTeamStatus(team['id'], true));
        break;
      case 'deactivate':
        context.read<AdminBloc>().add(AdminToggleTeamStatus(team['id'], false));
        break;
      case 'delete':
        _showDeleteTeamDialog(context, team);
        break;
    }
  }

  void _showCreateUserDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final fullNameController = TextEditingController();
    String selectedRole = 'topografo';
    String? selectedTeamId;

    // Obtener el BLoC del contexto actual
    final adminBloc = context.read<AdminBloc>();

    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: adminBloc,
        child: BlocListener<AdminBloc, AdminState>(
          listener: (context, state) {
            if (state is AdminSuccess) {
              // Limpiar controladores antes de cerrar
              emailController.dispose();
              passwordController.dispose();
              fullNameController.dispose();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.green,
                ),
              );
            } else if (state is AdminError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: StatefulBuilder(
            builder: (context, setState) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.person_add, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Crear Nuevo Usuario'),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Nombre completo
                        TextFormField(
                          controller: fullNameController,
                          decoration: const InputDecoration(
                            labelText: 'Nombre Completo',
                            prefixIcon: Icon(Icons.person),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'El nombre es requerido';
                            }
                            if (value.trim().length < 2) {
                              return 'El nombre debe tener al menos 2 caracteres';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Email
                        TextFormField(
                          controller: emailController,
                          decoration: const InputDecoration(
                            labelText: 'Correo Electrónico',
                            prefixIcon: Icon(Icons.email),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'El email es requerido';
                            }
                            if (!RegExp(
                              r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                            ).hasMatch(value)) {
                              return 'Ingresa un email válido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Contraseña
                        TextFormField(
                          controller: passwordController,
                          decoration: const InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: Icon(Icons.lock),
                            border: OutlineInputBorder(),
                          ),
                          obscureText: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'La contraseña es requerida';
                            }
                            if (value.length < 6) {
                              return 'La contraseña debe tener al menos 6 caracteres';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Rol
                        DropdownButtonFormField<String>(
                          value: selectedRole,
                          decoration: const InputDecoration(
                            labelText: 'Rol del Usuario',
                            prefixIcon: Icon(Icons.admin_panel_settings),
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'topografo',
                              child: Row(
                                children: [
                                  Icon(Icons.location_on, color: Colors.green),
                                  SizedBox(width: 8),
                                  Text('Topógrafo'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'admin',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.admin_panel_settings,
                                    color: Colors.red,
                                  ),
                                  SizedBox(width: 8),
                                  Text('Administrador'),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              selectedRole = value!;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Selecciona un rol';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Información adicional
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.info,
                                    color: Colors.blue,
                                    size: 16,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Información sobre roles:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                '• Topógrafo: Puede mapear terrenos y ver sus propios datos',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue,
                                ),
                              ),
                              const Text(
                                '• Administrador: Acceso completo al sistema',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    emailController.dispose();
                    passwordController.dispose();
                    fullNameController.dispose();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      context.read<AdminBloc>().add(
                        AdminCreateUser(
                          email: emailController.text.trim(),
                          password: passwordController.text,
                          fullName: fullNameController.text.trim(),
                          role: selectedRole,
                          teamId: selectedTeamId,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Crear Usuario'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditUserDialog(BuildContext context, UserProfile user) {
    final formKey = GlobalKey<FormState>();
    final fullNameController = TextEditingController(text: user.fullName ?? '');
    String selectedRole = user.role;

    // Obtener el BLoC del contexto actual
    final adminBloc = context.read<AdminBloc>();

    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: adminBloc,
        child: BlocListener<AdminBloc, AdminState>(
          listener: (context, state) {
            if (state is AdminSuccess) {
              // Limpiar controladores antes de cerrar
              fullNameController.dispose();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.green,
                ),
              );
            } else if (state is AdminError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: StatefulBuilder(
            builder: (context, setState) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.edit, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Editar Usuario'),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Información del usuario
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.info,
                                    color: Colors.grey,
                                    size: 16,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Información del usuario:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Email: ${user.email}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                'ID: ${user.id}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                'Estado: ${user.isActive ? 'Activo' : 'Inactivo'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: user.isActive
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Nombre completo
                        TextFormField(
                          controller: fullNameController,
                          decoration: const InputDecoration(
                            labelText: 'Nombre Completo',
                            prefixIcon: Icon(Icons.person),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'El nombre es requerido';
                            }
                            if (value.trim().length < 2) {
                              return 'El nombre debe tener al menos 2 caracteres';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Rol
                        DropdownButtonFormField<String>(
                          value: selectedRole,
                          decoration: const InputDecoration(
                            labelText: 'Rol del Usuario',
                            prefixIcon: Icon(Icons.admin_panel_settings),
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'topografo',
                              child: Row(
                                children: [
                                  Icon(Icons.location_on, color: Colors.green),
                                  SizedBox(width: 8),
                                  Text('Topógrafo'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'admin',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.admin_panel_settings,
                                    color: Colors.red,
                                  ),
                                  SizedBox(width: 8),
                                  Text('Administrador'),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              selectedRole = value!;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Selecciona un rol';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Información sobre los cambios
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange[200]!),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.warning,
                                    color: Colors.orange,
                                    size: 16,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Nota importante:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Text(
                                '• Los cambios se aplicarán inmediatamente',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange,
                                ),
                              ),
                              Text(
                                '• El email del usuario no se puede modificar',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange,
                                ),
                              ),
                              Text(
                                '• Cambiar el rol afectará los permisos del usuario',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    fullNameController.dispose();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      // Solo actualizar si hay cambios
                      bool hasChanges = false;
                      String? newFullName;
                      String? newRole;

                      if (fullNameController.text.trim() !=
                          (user.fullName ?? '')) {
                        newFullName = fullNameController.text.trim();
                        hasChanges = true;
                      }

                      if (selectedRole != user.role) {
                        newRole = selectedRole;
                        hasChanges = true;
                      }

                      if (hasChanges) {
                        context.read<AdminBloc>().add(
                          AdminUpdateUser(
                            userId: user.id,
                            fullName: newFullName,
                            role: newRole,
                          ),
                        );
                      } else {
                        fullNameController.dispose();
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No hay cambios para guardar'),
                            backgroundColor: Colors.blue,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Guardar Cambios'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCreateTeamDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    String? selectedLeaderId;

    // Obtener el BLoC del contexto actual
    final adminBloc = context.read<AdminBloc>();

    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: adminBloc,
        child: BlocListener<AdminBloc, AdminState>(
          listener: (context, state) {
            if (state is AdminSuccess) {
              Navigator.of(dialogContext).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.green,
                ),
              );
              context.read<AdminBloc>().add(AdminLoadTeams());
              context.read<AdminBloc>().add(AdminLoadUsers());
            } else if (state is AdminError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: BlocBuilder<AdminBloc, AdminState>(
            builder: (context, state) {
              List<UserProfile> users = [];
              if (state is AdminLoaded) {
                users = state.users.where((user) => user.isActive).toList();
              }

              if (selectedLeaderId != null &&
                  !users.any((u) => u.id == selectedLeaderId)) {
                selectedLeaderId = null;
              }

              return StatefulBuilder(
                builder: (context, setState) => AlertDialog(
                  title: const Row(
                    children: [
                      Icon(Icons.group_add, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Crear Nuevo Equipo'),
                    ],
                  ),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: Form(
                      key: formKey,
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Nombre del equipo
                            TextFormField(
                              controller: nameController,
                              decoration: const InputDecoration(
                                labelText: 'Nombre del Equipo',
                                prefixIcon: Icon(Icons.group),
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'El nombre del equipo es requerido';
                                }
                                if (value.trim().length < 3) {
                                  return 'El nombre debe tener al menos 3 caracteres';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Descripción
                            TextFormField(
                              controller: descriptionController,
                              decoration: const InputDecoration(
                                labelText: 'Descripción (Opcional)',
                                prefixIcon: Icon(Icons.description),
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 3,
                              validator: (value) {
                                if (value != null &&
                                    value.trim().isNotEmpty &&
                                    value.trim().length < 10) {
                                  return 'La descripción debe tener al menos 10 caracteres';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Líder del equipo
                            DropdownButtonFormField<String>(
                              value: selectedLeaderId,
                              decoration: const InputDecoration(
                                labelText: 'Líder del Equipo (Opcional)',
                                prefixIcon: Icon(Icons.person_pin),
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('Sin líder asignado'),
                                ),
                                ...users.map(
                                  (user) => DropdownMenuItem<String>(
                                    value: user.id,
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 12,
                                          backgroundColor: user.role == 'admin'
                                              ? Colors.red
                                              : Colors.green,
                                          child: Text(
                                            user.fullName
                                                    ?.substring(0, 1)
                                                    .toUpperCase() ??
                                                'U',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        SizedBox(
                                          child: Text(
                                            user.fullName ?? 'Sin nombre',
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  selectedLeaderId = value;
                                });
                              },
                            ),
                            const SizedBox(height: 16),

                            // Información adicional
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green[200]!),
                              ),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.info,
                                        color: Colors.green,
                                        size: 16,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Sobre los equipos:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    '• Los equipos permiten agrupar usuarios para proyectos',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green,
                                    ),
                                  ),
                                  Text(
                                    '• El líder puede gestionar los terrenos del equipo',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green,
                                    ),
                                  ),
                                  Text(
                                    '• Los miembros pueden ser asignados posteriormente',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                      },
                      child: const Text('Cancelar'),
                    ),
                    BlocBuilder<AdminBloc, AdminState>(
                      builder: (context, state) {
                        final isLoading = state is AdminLoading;

                        return ElevatedButton(
                          onPressed: isLoading
                              ? null
                              : () {
                                  if (formKey.currentState!.validate()) {
                                    // Desactivamos el botón manualmente desde aquí
                                    context.read<AdminBloc>().add(
                                      AdminCreateTeam(
                                        name: nameController.text.trim(),
                                        description:
                                            descriptionController.text
                                                .trim()
                                                .isEmpty
                                            ? null
                                            : descriptionController.text.trim(),
                                        leaderId: selectedLeaderId,
                                      ),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isLoading
                                ? Colors.grey
                                : Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Crear Equipo'),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showTeamDetails(BuildContext context, Map<String, dynamic> team) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.group, color: Colors.purple),
            SizedBox(width: 8),
            Text(team['name'] ?? 'Sin nombre'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (team['description'] != null) ...[
              Text(
                'Descripción:',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(team['description']!),
              const SizedBox(height: 12),
            ],
            Text(
              'Estado: ${team['is_active'] == true ? 'Activo' : 'Inactivo'}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: team['is_active'] == true ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text('ID: ${team['id']}'),
            if (team['created_at'] != null)
              Text(
                'Creado: ${_formatDateTime(DateTime.parse(team['created_at']))}',
              ),
            if (team['updated_at'] != null)
              Text(
                'Actualizado: ${_formatDateTime(DateTime.parse(team['updated_at']))}',
              ),
          ],
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

  void _showEditTeamDialog(BuildContext context, Map<String, dynamic> team) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: team['name'] ?? '');
    final descriptionController = TextEditingController(
      text: team['description'] ?? '',
    );
    String? selectedLeaderId = team['leader_id'];

    final adminBloc = context.read<AdminBloc>();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => BlocProvider.value(
        value: adminBloc,
        child: StatefulBuilder(
          builder: (context, setState) {
            return BlocListener<AdminBloc, AdminState>(
              listener: (context, state) {
                if (state is AdminSuccess) {
                  setState(() => isSaving = false);

                  Future.delayed(const Duration(milliseconds: 100), () {
                    Navigator.of(context).pop();
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: Colors.green,
                    ),
                  );

                  context.read<AdminBloc>().add(AdminLoadTeams());
                  context.read<AdminBloc>().add(AdminLoadUsers());
                } else if (state is AdminError) {
                  setState(() => isSaving = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: BlocBuilder<AdminBloc, AdminState>(
                builder: (context, state) {
                  List<UserProfile> users = [];
                  if (state is AdminLoaded) {
                    users = state.users.where((u) => u.isActive).toList();
                  }

                  if (selectedLeaderId != null &&
                      !users.any((u) => u.id == selectedLeaderId)) {
                    selectedLeaderId = null;
                  }

                  return AlertDialog(
                    title: const Row(
                      children: [
                        Icon(Icons.edit, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Editar Equipo'),
                      ],
                    ),
                    content: Form(
                      key: formKey,
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextFormField(
                              controller: nameController,
                              decoration: const InputDecoration(
                                labelText: 'Nombre del Equipo',
                                prefixIcon: Icon(Icons.group),
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Este campo es obligatorio';
                                }
                                if (value.trim().length < 3) {
                                  return 'Mínimo 3 caracteres';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: descriptionController,
                              decoration: const InputDecoration(
                                labelText: 'Descripción (opcional)',
                                prefixIcon: Icon(Icons.description),
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 3,
                              validator: (value) {
                                if (value != null &&
                                    value.trim().isNotEmpty &&
                                    value.trim().length < 10) {
                                  return 'Mínimo 10 caracteres';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: selectedLeaderId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Líder del equipo (opcional)',
                                prefixIcon: Icon(Icons.person),
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('Sin líder asignado'),
                                ),
                                ...users.map(
                                  (user) => DropdownMenuItem(
                                    value: user.id,
                                    child: Text(user.fullName ?? 'Usuario'),
                                  ),
                                ),
                              ],
                              onChanged: (value) => setState(() {
                                selectedLeaderId = value;
                              }),
                            ),
                          ],
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text('Cancelar'),
                      ),
                      ElevatedButton.icon(
                        icon: isSaving
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: const Text('Guardar Cambios'),
                        onPressed: isSaving
                            ? null
                            : () {
                                if (formKey.currentState!.validate()) {
                                  bool hasChanges = false;

                                  final newName = nameController.text.trim();
                                  final newDesc =
                                      descriptionController.text.trim().isEmpty
                                      ? null
                                      : descriptionController.text.trim();

                                  if (newName != (team['name'] ?? '')) {
                                    hasChanges = true;
                                  }
                                  if ((team['description'] ?? '') !=
                                      (newDesc ?? '')) {
                                    hasChanges = true;
                                  }
                                  if (selectedLeaderId != team['leader_id']) {
                                    hasChanges = true;
                                  }

                                  if (hasChanges) {
                                    setState(() => isSaving = true);
                                    context.read<AdminBloc>().add(
                                      AdminUpdateTeam(
                                        teamId: team['id'],
                                        name: newName,
                                        description: newDesc,
                                        leaderId: selectedLeaderId,
                                      ),
                                    );
                                  } else {
                                    Navigator.of(context).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'No hay cambios para guardar',
                                        ),
                                        backgroundColor: Colors.blue,
                                      ),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  void _showDeleteTeamDialog(BuildContext context, Map<String, dynamic> team) {
    // Obtener el BLoC del contexto actual
    final adminBloc = context.read<AdminBloc>();

    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: adminBloc,
        child: BlocListener<AdminBloc, AdminState>(
          listener: (context, state) {
            if (state is AdminSuccess) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.green,
                ),
              );
              context.read<AdminBloc>().add(AdminLoadTeams());
              context.read<AdminBloc>().add(AdminLoadUsers());
            } else if (state is AdminError) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning, color: Colors.red),
                SizedBox(width: 8),
                Text('Eliminar Equipo'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¿Estás seguro de que quieres eliminar este equipo?',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nombre: ${team['name'] ?? 'Sin nombre'}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (team['description'] != null)
                        Text('Descripción: ${team['description']}'),
                      Text('ID: ${team['id']}'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning, color: Colors.red, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Advertencia:',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        '• Todos los miembros serán removidos del equipo',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                      Text(
                        '• Esta acción no se puede deshacer',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  context.read<AdminBloc>().add(AdminDeleteTeam(team['id']));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _refreshTeamsAndUsers(BuildContext context, String teamId) {
    final adminBloc = context.read<AdminBloc>();

    adminBloc.add(AdminLoadTeamMembers(teamId));
    adminBloc.add(AdminLoadAvailableUsers(teamId));

    Future.delayed(const Duration(milliseconds: 150), () {
      adminBloc.add(AdminLoadTeams());
    });
  }

  void _showManageTeamMembersDialog(
    BuildContext context,
    Map<String, dynamic> team,
  ) {
    final adminBloc = context.read<AdminBloc>();

    // 🔹 Cargar datos al abrir el modal
    adminBloc.add(AdminLoadAvailableUsers(team['id']));
    adminBloc.add(AdminLoadTeamMembers(team['id']));

    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: adminBloc,
        child: BlocListener<AdminBloc, AdminState>(
          listener: (context, state) {
            if (state is AdminSuccess) {
              // Recargar listas cuando hay cambios exitosos
              adminBloc.add(AdminLoadAvailableUsers(team['id']));
              adminBloc.add(AdminLoadTeamMembers(team['id']));
              adminBloc.add(AdminLoadTeams());
              context.read<AdminBloc>().add(AdminLoadUsers());

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.green,
                ),
              );
              _refreshTeamsAndUsers(context, team['id']);
            }
          },
          child: BlocBuilder<AdminBloc, AdminState>(
            builder: (context, state) {
              // Variables desde el Bloc
              List<UserProfile> availableUsers = [];
              List<UserProfile> teamMembers = [];
              bool isProcessing = false;

              if (state is AdminLoading) {
                isProcessing = true;
              }
              if (state is AdminLoaded) {
                availableUsers = state.availableUsers;
                teamMembers = state.teamMembers;
              }

              return AlertDialog(
                title: Row(
                  children: [
                    Icon(Icons.group_work, color: Colors.purple),
                    SizedBox(width: 8),
                    Text('Gestionar Miembros'),
                  ],
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  height: 400,
                  child: Column(
                    children: [
                      // 🔹 Información del equipo
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.purple[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.purple[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.group, color: Colors.purple),
                            SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    team['name'] ?? 'Sin nombre',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.purple,
                                    ),
                                  ),
                                  if (team['description'] != null)
                                    Text(
                                      team['description'],
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.purple[700],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 🔹 Pestañas
                      Expanded(
                        child: DefaultTabController(
                          length: 2,
                          child: Column(
                            children: [
                              const TabBar(
                                labelColor: Colors.purple,
                                unselectedLabelColor: Colors.grey,
                                tabs: [
                                  Tab(text: 'Miembros Actuales'),
                                  Tab(text: 'Agregar Miembros'),
                                ],
                              ),
                              Expanded(
                                child: TabBarView(
                                  children: [
                                    // 🔹 Miembros actuales
                                    teamMembers.isEmpty
                                        ? const Center(
                                            child: Text(
                                              'No hay miembros en este equipo',
                                            ),
                                          )
                                        : ListView.builder(
                                            itemCount: teamMembers.length,
                                            itemBuilder: (context, index) {
                                              final member = teamMembers[index];
                                              return ListTile(
                                                leading: CircleAvatar(
                                                  backgroundColor:
                                                      member.role == 'admin'
                                                      ? Colors.red
                                                      : Colors.green,
                                                  child: Text(
                                                    member.fullName
                                                            ?.substring(0, 1)
                                                            .toUpperCase() ??
                                                        'U',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                title: Text(
                                                  member.fullName ??
                                                      'Sin nombre',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                subtitle: Text(
                                                  '${member.role} • ${member.email}',
                                                ),
                                                trailing: IconButton(
                                                  icon: const Icon(
                                                    Icons.remove_circle,
                                                    color: Colors.red,
                                                  ),
                                                  onPressed: () {
                                                    context.read<AdminBloc>().add(
                                                      AdminRemoveUserFromTeam(
                                                        member.id,
                                                        team['id'],
                                                      ),
                                                    );
                                                  },
                                                ),
                                              );
                                            },
                                          ),

                                    // 🔹 Agregar miembros
                                    availableUsers.isEmpty
                                        ? const Center(
                                            child: Text(
                                              'No hay usuarios disponibles para agregar',
                                            ),
                                          )
                                        : ListView.builder(
                                            itemCount: availableUsers.length,
                                            itemBuilder: (context, index) {
                                              final user =
                                                  availableUsers[index];
                                              return ListTile(
                                                leading: CircleAvatar(
                                                  backgroundColor:
                                                      user.role == 'admin'
                                                      ? Colors.red
                                                      : Colors.green,
                                                  child: Text(
                                                    user.fullName
                                                            ?.substring(0, 1)
                                                            .toUpperCase() ??
                                                        'U',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                title: Text(
                                                  user.fullName ?? 'Sin nombre',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                subtitle: Text(
                                                  '${user.role} • ${user.email}',
                                                ),
                                                trailing: IconButton(
                                                  icon: const Icon(
                                                    Icons.add_circle,
                                                    color: Colors.green,
                                                  ),
                                                  onPressed: () {
                                                    context
                                                        .read<AdminBloc>()
                                                        .add(
                                                          AdminAddUserToTeam(
                                                            user.id,
                                                            team['id'],
                                                          ),
                                                        );
                                                  },
                                                ),
                                              );
                                            },
                                          ),
                                  ],
                                ),
                              ),
                            ],
                          ),
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
            },
          ),
        ),
      ),
    );
  }
}
