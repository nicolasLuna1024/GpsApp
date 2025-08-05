import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../bloc/terrain_bloc.dart';
import '../models/terrain.dart';
import 'terrain_mapping_screen.dart';

class TerrainListScreen extends StatefulWidget {
  const TerrainListScreen({super.key});

  @override
  State<TerrainListScreen> createState() => _TerrainListScreenState();
}

class _TerrainListScreenState extends State<TerrainListScreen> {
  @override
  void initState() {
    super.initState();
    context.read<TerrainBloc>().add(TerrainLoadUserTerrains());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Mis Terrenos',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.orange[600],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              context.read<TerrainBloc>().add(TerrainLoadUserTerrains());
            },
          ),
        ],
      ),
      body: BlocListener<TerrainBloc, TerrainState>(
        listener: (context, state) {
          if (state is TerrainSuccess) {
            Fluttertoast.showToast(
              msg: state.message,
              backgroundColor: Colors.green,
              textColor: Colors.white,
            );
          } else if (state is TerrainError) {
            Fluttertoast.showToast(
              msg: state.message,
              backgroundColor: Colors.red,
              textColor: Colors.white,
            );
          }
        },
        child: BlocBuilder<TerrainBloc, TerrainState>(
          builder: (context, state) {
            if (state is TerrainLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is TerrainLoaded) {
              return _buildTerrainList(context, state);
            } else {
              return _buildEmptyState(context);
            }
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: context.read<TerrainBloc>(),
                child: const TerrainMappingScreen(),
              ),
            ),
          );

          // Recargar terrenos cuando regresa de la pantalla de mapeo
          if (mounted) {
            context.read<TerrainBloc>().add(TerrainLoadUserTerrains());
          }
        },
        backgroundColor: Colors.orange[600],
        icon: const Icon(Icons.add_location, color: Colors.white),
        label: const Text(
          'Nuevo Terreno',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildTerrainList(BuildContext context, TerrainLoaded state) {
    if (state.terrains.isEmpty) {
      return _buildEmptyState(context);
    }

    return Column(
      children: [
        // Estadísticas
        if (state.stats.isNotEmpty) _buildStatsCard(state.stats),

        // Lista de terrenos
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: state.terrains.length,
            itemBuilder: (context, index) {
              final terrain = state.terrains[index];
              return _buildTerrainCard(context, terrain);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCard(Map<String, dynamic> stats) {
    final totalTerrains = stats['total_terrains'] ?? 0;
    final totalArea = stats['total_area'] ?? 0.0;

    String formattedTotalArea;
    if (totalArea < 10000) {
      formattedTotalArea = '${totalArea.toStringAsFixed(2)} m²';
    } else {
      double hectares = totalArea / 10000;
      formattedTotalArea = '${hectares.toStringAsFixed(2)} ha';
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange[600]!, Colors.orange[400]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Resumen',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$totalTerrains terrenos mapeados',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                Text(
                  'Área total: $formattedTotalArea',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.terrain, color: Colors.white, size: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildTerrainCard(BuildContext context, Terrain terrain) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showTerrainDetails(context, terrain),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.terrain,
                      color: Colors.orange[600],
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          terrain.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (terrain.description != null)
                          Text(
                            terrain.description!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') {
                        _showDeleteDialog(context, terrain);
                      }
                    },
                    itemBuilder: (BuildContext context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Eliminar'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildInfoChip(
                    icon: Icons.straighten,
                    label: terrain.formattedArea,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  _buildInfoChip(
                    icon: Icons.location_on,
                    label: '${terrain.points.length} puntos',
                    color: Colors.green,
                  ),
                  
                  const SizedBox(width: 8),
                  _buildInfoChip(
                    icon: terrain.teamName != null ? Icons.group : Icons.person,
                    label: terrain.teamName ?? 'Individual',
                    color: terrain.teamName != null ? Colors.purple : Colors.orange,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Creado: ${_formatDate(terrain.createdAt)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.terrain, size: 64, color: Colors.orange[300]),
          ),
          const SizedBox(height: 24),
          const Text(
            'No hay terrenos mapeados',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Comienza creando tu primer terreno',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: context.read<TerrainBloc>(),
                    child: const TerrainMappingScreen(),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.add_location),
            label: const Text('Crear Terreno'),
          ),
        ],
      ),
    );
  }

  void _showTerrainDetails(BuildContext context, Terrain terrain) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(terrain.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (terrain.description != null) ...[
              Text(
                'Descripción:',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(terrain.description!),
              const SizedBox(height: 12),
            ],
            Text(
              'Área: ${terrain.formattedArea}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Puntos: ${terrain.points.length}'),
            Text('Creado: ${_formatDate(terrain.createdAt)}'),
            Text('Actualizado: ${_formatDate(terrain.updatedAt)}'),
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

  void _showDeleteDialog(BuildContext context, Terrain terrain) {
    // Obtener el BLoC del contexto actual
    final terrainBloc = context.read<TerrainBloc>();

    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: terrainBloc,
        child: BlocListener<TerrainBloc, TerrainState>(
          listener: (context, state) {
            if (state is TerrainSuccess) {
              Navigator.of(context).pop();
              Fluttertoast.showToast(
                msg: state.message,
                backgroundColor: Colors.green,
                textColor: Colors.white,
              );
            } else if (state is TerrainError) {
              Navigator.of(context).pop();
              Fluttertoast.showToast(
                msg: state.message,
                backgroundColor: Colors.red,
                textColor: Colors.white,
              );
            }
          },
          child: AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning, color: Colors.red),
                SizedBox(width: 8),
                Text('Eliminar Terreno'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¿Estás seguro de que quieres eliminar este terreno?',
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
                        'Nombre: ${terrain.name}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (terrain.description != null)
                        Text('Descripción: ${terrain.description}'),
                      Text('Área: ${terrain.formattedArea}'),
                      Text('Puntos: ${terrain.points.length}'),
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
                  child: const Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Esta acción no se puede deshacer.',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
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
                  context.read<TerrainBloc>().add(TerrainDelete(terrain.id));
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

  Widget _buildTerrainWithTeamCard(
    BuildContext context, 
    Map<String, dynamic> terrainData
  ) {
    // Crear objeto Terrain para usar los métodos existentes
    final terrain = Terrain.fromJson(terrainData);
    final teamInfo = terrainData['teams'] as Map<String, dynamic>?;
    final teamName = teamInfo?['name'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showTerrainDetails(context, terrain),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.terrain,
                      color: Colors.orange[600],
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          terrain.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (terrain.description != null)
                          Text(
                            terrain.description!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') {
                        _showDeleteDialog(context, terrain);
                      }
                    },
                    itemBuilder: (BuildContext context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Eliminar'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildInfoChip(
                    icon: Icons.straighten,
                    label: terrain.formattedArea,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  _buildInfoChip(
                    icon: Icons.location_on,
                    label: '${terrain.points.length} puntos',
                    color: Colors.green,
                  ),

                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Creado: ${_formatDate(terrain.createdAt)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
