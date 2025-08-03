import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../bloc/terrain_bloc.dart';
import '../models/terrain.dart';

class TerrainMappingScreen extends StatefulWidget {
  const TerrainMappingScreen({super.key});

  @override
  State<TerrainMappingScreen> createState() => _TerrainMappingScreenState();
}

class _TerrainMappingScreenState extends State<TerrainMappingScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  LatLng? _currentLocation;
  bool _isLocating = false;

  // Coordenadas por defecto (Ciudad de México)
  final LatLng _defaultLocation = const LatLng(19.4326, -99.1332);

  @override
  void initState() {
    super.initState();

    // Asegurar que tenemos un estado inicial con puntos vacíos
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Inicializar el estado si es necesario
        final currentState = context.read<TerrainBloc>().state;
        if (currentState is! TerrainLoaded) {
          context.read<TerrainBloc>().add(TerrainClearCurrentPoints());
        }

        // Retrasar la obtención de ubicación para que el mapa se renderice primero
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            _getCurrentLocation();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocating = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Los servicios de ubicación están deshabilitados');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Permisos de ubicación denegados');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Permisos de ubicación denegados permanentemente');
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _isLocating = false;
      });

      // Mover el mapa solo si ya está renderizado
      if (mounted) {
        try {
          await Future.delayed(const Duration(milliseconds: 500));
          _mapController.move(_currentLocation!, 16.0);
        } catch (e) {
          // Ignorar error si el mapa no está listo
          print('Mapa no está listo aún: $e');
        }
      }
    } catch (e) {
      setState(() => _isLocating = false);
      Fluttertoast.showToast(
        msg: 'Error al obtener ubicación: $e',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  void _addPointAtLocation(LatLng location) {
    final point = TerrainPoint(
      latitude: location.latitude,
      longitude: location.longitude,
    );

    // Debug: Imprimir información del punto agregado
    print('Agregando punto: (${point.latitude}, ${point.longitude})');

    context.read<TerrainBloc>().add(TerrainAddPoint(point));

    // Obtener el estado actual para mostrar información más detallada
    final state = context.read<TerrainBloc>().state;
    int pointCount = 0;
    if (state is TerrainLoaded) {
      pointCount =
          state.currentPoints.length + 1; // +1 porque acabamos de agregar uno
    }

    Fluttertoast.showToast(
      msg: 'Punto $pointCount agregado',
      backgroundColor: Colors.green,
      textColor: Colors.white,
      toastLength: Toast.LENGTH_SHORT,
    );
  }

  void _removeLastPoint() {
    context.read<TerrainBloc>().add(TerrainRemoveLastPoint());

    Fluttertoast.showToast(
      msg: 'Punto eliminado',
      backgroundColor: Colors.orange,
      textColor: Colors.white,
    );
  }

  void _clearAllPoints() {
    context.read<TerrainBloc>().add(TerrainClearCurrentPoints());

    Fluttertoast.showToast(
      msg: 'Todos los puntos eliminados',
      backgroundColor: Colors.red,
      textColor: Colors.white,
    );
  }

  void _saveTerrain(List<TerrainPoint> points) {
    if (_nameController.text.trim().isEmpty) {
      Fluttertoast.showToast(
        msg: 'Ingresa un nombre para el terreno',
        backgroundColor: Colors.red,
        textColor: Colors.white,
        toastLength: Toast.LENGTH_LONG,
      );
      return;
    }

    if (points.length < 3) {
      Fluttertoast.showToast(
        msg: 'Se necesitan al menos 3 puntos para crear un terreno',
        backgroundColor: Colors.red,
        textColor: Colors.white,
        toastLength: Toast.LENGTH_LONG,
      );
      return;
    }

    // Debug: Imprimir información de los puntos
    print('Guardando terreno con ${points.length} puntos:');
    for (int i = 0; i < points.length; i++) {
      print('Punto $i: (${points[i].latitude}, ${points[i].longitude})');
    }

    context.read<TerrainBloc>().add(
      TerrainCreate(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        points: points,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Mapear Terreno',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.purple[600],
        elevation: 0,
        actions: [
          if (_currentLocation == null && !_isLocating)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: ElevatedButton.icon(
                onPressed: _getCurrentLocation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                icon: const Icon(Icons.my_location, size: 18),
                label: const Text('Ubicación', style: TextStyle(fontSize: 12)),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.my_location, color: Colors.white),
              onPressed: _isLocating ? null : _getCurrentLocation,
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
            Navigator.of(context).pop();
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
            List<TerrainPoint> currentPoints = [];

            // Manejar diferentes estados
            if (state is TerrainLoaded) {
              currentPoints = state.currentPoints;
            } else if (state is TerrainError) {
              // En caso de error, mantener los puntos si estaban en un estado previo
              currentPoints = [];
            } else if (state is TerrainSuccess) {
              // En caso de éxito, limpiar puntos
              currentPoints = [];
            } else {
              // Estado inicial o de carga
              currentPoints = [];
            }

            return Column(
              children: [
                // Información del terreno
                _buildTerrainInfo(currentPoints),

                // Mapa
                Expanded(child: _buildMap(currentPoints)),

                // Controles
                _buildControls(currentPoints),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTerrainInfo(List<TerrainPoint> currentPoints) {
    final area = currentPoints.length >= 3
        ? Terrain.calculateArea(currentPoints)
        : 0.0;

    String formattedArea;
    if (area < 10000) {
      formattedArea = '${area.toStringAsFixed(2)} m²';
    } else {
      double hectares = area / 10000;
      formattedArea = '${hectares.toStringAsFixed(2)} ha';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.terrain, color: Colors.purple[600]),
              const SizedBox(width: 8),
              const Text(
                'Información del Terreno',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nombre del terreno',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Descripción (opcional)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoChip(
                  icon: Icons.location_on,
                  label: '${currentPoints.length} puntos',
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildInfoChip(
                  icon: Icons.straighten,
                  label: formattedArea,
                  color: currentPoints.length >= 3 ? Colors.green : Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(List<TerrainPoint> currentPoints) {
    // Usar ubicación actual o ubicación por defecto
    final mapCenter = _currentLocation ?? _defaultLocation;

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: mapCenter,
        initialZoom: _currentLocation != null ? 16.0 : 10.0,
        onTap: (tapPosition, point) => _addPointAtLocation(point),
        onMapReady: () {
          // El mapa está listo, intentar obtener ubicación si no la tenemos
          if (_currentLocation == null && !_isLocating) {
            _getCurrentLocation();
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
        ),

        // Overlay de carga de ubicación
        if (_isLocating)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Obteniendo ubicación...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),

        // Polígono del terreno
        if (currentPoints.length >= 3)
          PolygonLayer(
            polygons: [
              Polygon(
                points: currentPoints
                    .map((p) => LatLng(p.latitude, p.longitude))
                    .toList(),
                color: Colors.purple.withOpacity(0.3),
                borderColor: Colors.purple,
                borderStrokeWidth: 2,
              ),
            ],
          ),

        // Líneas conectando los puntos
        if (currentPoints.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: currentPoints
                    .map((p) => LatLng(p.latitude, p.longitude))
                    .toList(),
                color: Colors.purple,
                strokeWidth: 2,
              ),
            ],
          ),

        // Marcadores de los puntos
        MarkerLayer(
          markers: [
            // Ubicación actual (solo si está disponible)
            if (_currentLocation != null)
              Marker(
                point: _currentLocation!,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.my_location,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),

            // Puntos del terreno
            ...currentPoints.asMap().entries.map((entry) {
              final index = entry.key;
              final point = entry.value;
              return Marker(
                point: LatLng(point.latitude, point.longitude),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.purple,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildControls(List<TerrainPoint> currentPoints) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Instrucciones
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Toca en el mapa para agregar puntos y crear el polígono del terreno',
                    style: TextStyle(color: Colors.blue, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Botones de control
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: currentPoints.isNotEmpty ? _removeLastPoint : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.undo, size: 18),
                  label: const Text('Deshacer'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: currentPoints.isNotEmpty ? _clearAllPoints : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.clear, size: 18),
                  label: const Text('Limpiar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: currentPoints.length >= 3
                      ? () => _saveTerrain(currentPoints)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text('Guardar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
