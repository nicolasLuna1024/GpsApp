import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;
import 'dart:async';
import '../bloc/location_bloc.dart';
import '../models/user_location.dart';
import '../models/terrain.dart';
import '../services/location_service.dart';
import '../services/terrain_service.dart';
import '../services/auth_service.dart';
import '../services/collaborative_terrain_service.dart';
import '../models/collaborative_terrain_point.dart';
import '../bloc/collaborative_session_bloc.dart';





const String isolateName = 'LocatorIsolate';


class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  
  final MapController _mapController = MapController();
  final TextEditingController _terrainNameController = TextEditingController();
  final TextEditingController _terrainDescriptionController = TextEditingController();

  double _currentZoom = 15.0;
  LatLng _currentCenter = const LatLng(0, 0);
  bool _hasCenteredOnce = false;
  
  // Variables para manejo de puntos del terreno
  List<TerrainPoint> _terrainPoints = [];
  List<CollaborativeTerrainPoint> _collaborativePoints = [];
  bool _isAddingPoints = false;
  bool _isCollaborativeMode = false;
  StreamSubscription<List<CollaborativeTerrainPoint>>? _collaborativePointsSubscription;
  Timer? _collaborativePollingTimer;
  


  void _initialMapCenter(Position nuevoCentro) {
    final nuevaUbicacion = LatLng(nuevoCentro.latitude, nuevoCentro.longitude);
    setState(() {
      _currentCenter = nuevaUbicacion;
      _lastValidPosition = nuevaUbicacion;
    });

    // Centrar con un zoom apropiado para la ubicación inicial
    final initialZoom = 16.0;
    _mapController.moveAndRotate(nuevaUbicacion, initialZoom, 0);
    setState(() {
      _currentZoom = initialZoom;
    });

    // Mostrar mensaje informativo
    Fluttertoast.showToast(
      msg: 'Mapa centrado en tu ubicación actual',
      backgroundColor: Colors.green,
      textColor: Colors.white,
    );
  }


  @override
  void initState() {
    super.initState();
    // Solicitar permisos y empezar tracking al cargar la pantalla
    context.read<LocationBloc>().add(LocationPermissionRequested());
    
    // Cargar ubicaciones del equipo o sesión colaborativa
    Future.delayed(Duration(milliseconds: 500), () {
      _loadTeamOrSessionLocations();
      _initializeCollaborativeMode();
    });
    
    // Recargar modo colaborativo periódicamente como respaldo
    Future.delayed(Duration(milliseconds: 3000), () {
      if (mounted) {
        _initializeCollaborativeMode();
      }
    });
    
    _mapController.mapEventStream.listen((event){
      setState(() {
        _currentZoom = event.camera.zoom;
      });
    });
  }

  @override
  void dispose() {
    _terrainNameController.dispose();
    _terrainDescriptionController.dispose();
    _stopIconUpdateTimer();
    _collaborativePointsSubscription?.cancel();
    _collaborativePollingTimer?.cancel();
    // Timer de BD se maneja desde LocationBloc

    // Desactivar todas las ubicaciones activas del usuario al salir
    LocationService.deactivateUserLocations();
    super.dispose();
  }

  // Manejar el botón de back cuando el tracking está activo
  Future<bool> _onWillPop() async {
    if (context.read<LocationBloc>().isTracking) {
      final shouldExit = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Tracking Activo'),
          content: const Text(
            'El tracking en tiempo real está activo. Debes detenerlo antes de poder salir de esta pantalla.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Continuar tracking'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(true);
                // Detener tracking
                _stopTracking();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
              ),
              child: const Text('Detener y salir'),
            ),
          ],
        ),
      );
      return shouldExit ?? false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
        title: const Text(
          'Mapa en Tiempo Real',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.green[600],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              context.read<LocationBloc>().add(LocationUpdateRequested());
              _loadTeamOrSessionLocations();
              _refreshCollaborativePoints();
              // Reinicializar modo colaborativo
              Future.delayed(Duration(milliseconds: 500), () {
                if (mounted) {
                  _initializeCollaborativeMode();
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.my_location, color: Colors.white),
            onPressed: _centerOnCurrentLocation,
          ),
          // Debug button - remover después de probar
          IconButton(
            icon: const Icon(Icons.bug_report, color: Colors.white),
            onPressed: _showDebugInfo,
          ),
        ],
      ),
      body: MultiBlocListener(
        listeners: [
          BlocListener<LocationBloc, LocationState>(
            listener: (context, state) {
          if (state is LocationPermissionDenied) {
            Fluttertoast.showToast(
              msg: state.message,
              toastLength: Toast.LENGTH_LONG,
              gravity: ToastGravity.BOTTOM,
              backgroundColor: Colors.red,
              textColor: Colors.white,
            );
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: Text('Permiso requerido'),
                content: Text(
                    'Para que la app funcione en segundo plano, debes otorgar el permiso "Permitir todo el tiempo" en la configuración de la app.'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);

                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                    },
                    child: Text('Cancelar'),
                  ),
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await Geolocator.openAppSettings();
                    },
                    child: Text('Abrir configuración'),
                  ),
                ],
              ),
            );
          } else if (state is LocationError) {
            Fluttertoast.showToast(
              msg: state.message,
              toastLength: Toast.LENGTH_LONG,
              gravity: ToastGravity.BOTTOM,
              backgroundColor: Colors.red,
              textColor: Colors.white,
            );
          } else if (state is LocationTrackingActive && !_hasCenteredOnce) {
            _initialMapCenter(state.currentPosition);
            setState(() {
              _hasCenteredOnce = true;
            });
            // Iniciar timer para actualizaciones periódicas del ícono
            if (_iconUpdateTimer == null) {
              _startIconUpdateTimer();
            }
          } else if (state is LocationUpdated && !_hasCenteredOnce) {
            // Primera vez: centrar cámara en la ubicación actual
            _initialMapCenter(state.position);
            setState(() {
              _hasCenteredOnce = true;
            });
            // Iniciar timer para actualizaciones periódicas del ícono
            if (_iconUpdateTimer == null) {
              _startIconUpdateTimer();
            }
          } else if (state is LocationUpdated) {
            // Solo actualizar ícono cuando no hay tracking activo (ya centrado)
            _updateIconOnly(state.position);
            // Iniciar timer para actualizaciones periódicas del ícono si no existe
            if (_iconUpdateTimer == null) {
              _startIconUpdateTimer();
            }
          } else if (state is LocationTrackingActive) {
            // Actualizar ícono y cámara durante el tracking
            _updateMapCenter(state.currentPosition);
            // Iniciar timer para actualizaciones periódicas del ícono si no existe
            if (_iconUpdateTimer == null) {
              _startIconUpdateTimer();
            }
            // Timer de BD se maneja desde LocationBloc, no desde MapScreen
          }
          else if (state is LocationAlwaysPermission) {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: Text('Permiso requerido'),
                content: Text(
                    'Para que la app funcione en segundo plano, debes otorgar el permiso "Permitir todo el tiempo" en la configuración de la app.'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);

                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                    },
                    child: Text('Cancelar'),
                  ),
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await Geolocator.openAppSettings();
                    },
                    child: Text('Abrir configuración'),
                  ),
                ],
              ),
            );
          }
        },
          ),
          BlocListener<CollaborativeSessionBloc, CollaborativeSessionState>(
            listener: (context, state) {
              if (state is CollaborativeSessionJoined) {
                print('Sesión colaborativa unida, reinicializando modo...');
                Future.delayed(Duration(milliseconds: 500), () {
                  if (mounted) {
                    _initializeCollaborativeMode();
                  }
                });
              } else if (state is CollaborativeSessionOperationSuccess) {
                print('Operación de sesión exitosa, reinicializando modo...');
                Future.delayed(Duration(milliseconds: 500), () {
                  if (mounted) {
                    _initializeCollaborativeMode();
                  }
                });
              }
            },
          ),
        ],
        child: BlocBuilder<LocationBloc, LocationState>(
          builder:
           (context, state) {
            if (state is LocationLoading) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Obteniendo ubicación...',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              );
            }
            return Stack(
              children: [
                // Mapa
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(0.0, 0.0),
                    initialZoom: _currentZoom,
                    maxZoom: 20.0,
                    minZoom: 3.0,
                  ),
                  children: [
                    // Capa de tiles de OpenStreetMap
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.app_final',
                    ),
                    
                    // Polígono del terreno (individual o colaborativo)
                    if (_isCollaborativeMode && _collaborativePoints.length >= 3)
                      PolygonLayer(
                        polygons: [
                          Polygon(
                            points: _orderedCollaborativePoints
                                .map((p) => LatLng(p.latitude, p.longitude))
                                .toList(),
                            color: Colors.green.withOpacity(0.3),
                            borderColor: Colors.green,
                            borderStrokeWidth: 2,
                          ),
                        ],
                      )
                    else if (!_isCollaborativeMode && _terrainPoints.length >= 3)
                      PolygonLayer(
                        polygons: [
                          Polygon(
                            points: _orderedTerrainPoints
                                .map((p) => LatLng(p.latitude, p.longitude))
                                .toList(),
                            color: Colors.purple.withOpacity(0.3),
                            borderColor: Colors.purple,
                            borderStrokeWidth: 2,
                          ),
                        ],
                      ),

                    // Líneas conectando los puntos del terreno (individual o colaborativo)
                    if (_isCollaborativeMode && _collaborativePoints.length >= 2)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _orderedCollaborativePoints
                                .map((p) => LatLng(p.latitude, p.longitude))
                                .toList(),
                            color: Colors.green,
                            strokeWidth: 2,
                          ),
                        ],
                      )
                    else if (!_isCollaborativeMode && _terrainPoints.length >= 2)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _orderedTerrainPoints
                                .map((p) => LatLng(p.latitude, p.longitude))
                                .toList(),
                            color: Colors.purple,
                            strokeWidth: 2,
                          ),
                        ],
                      ),          
                    // Marcadores
                    MarkerLayer(markers: _buildMarkers(state)),
                  ],
                ),

                // Panel de información
                _buildInfoPanel(state),

                // Botones de control
                _buildControlButtons(state),
              ],
            );
          },
        ),
      ),
    ));
  }

  List<Marker> _buildMarkers(LocationState state) {
    List<Marker> markers = [];

    if (state is LocationTrackingActive) {
      // Marcador para la ubicación actual
      markers.add(
        Marker(
          point: LatLng(
            state.currentPosition.latitude,
            state.currentPosition.longitude,
          ),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blue[600],
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 6,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 20),
          ),
        ),
      );

      // Marcadores para miembros del equipo (filtrar el usuario actual)
      final currentUser = AuthService.currentUser;
      final filteredTeamLocations = state.teamLocations.where((location) => 
        currentUser == null || location.userId != currentUser.id
      ).toList();
      
      for (var location in filteredTeamLocations) {
        markers.add(
          Marker(
            point: LatLng(location.latitude, location.longitude),
            child: GestureDetector(
              onTap: () => _showMemberInfo(context, location),
              child: Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  color: Colors.orange[600],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.person_pin,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        );
      }
    } else if (state is LocationUpdated) {
      // Similar para LocationUpdated
      markers.add(
        Marker(
          point: LatLng(state.position.latitude, state.position.longitude),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blue[600],
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 20),
          ),
        ),
      );

      // Marcadores para miembros del equipo (filtrar el usuario actual)
      final currentUser = AuthService.currentUser;
      final filteredTeamLocations = state.teamLocations.where((location) => 
        currentUser == null || location.userId != currentUser.id
      ).toList();

      for (var location in filteredTeamLocations) {
        markers.add(
          Marker(
            point: LatLng(location.latitude, location.longitude),
            child: GestureDetector(
              onTap: () => _showMemberInfo(context, location),
              child: Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  color: Colors.orange[600],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.person_pin,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        );
      }
    }

    // Marcadores para puntos del terreno (individual o colaborativo)
    if (_isCollaborativeMode) {
      // Modo colaborativo: mostrar puntos de todos los participantes
      for (int i = 0; i < _collaborativePoints.length; i++) {
        final point = _collaborativePoints[i];
        final isOwnPoint = point.userId == AuthService.currentUser?.id;
        
        markers.add(
          Marker(
            point: LatLng(point.latitude, point.longitude),
            child: GestureDetector(
              onTap: () => _showCollaborativePointInfo(point),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: isOwnPoint ? Colors.purple[600] : Colors.orange[600],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: (isOwnPoint ? Colors.purple : Colors.orange).withOpacity(0.3),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${point.pointNumber}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    } else {
      // Modo individual: mostrar solo puntos propios
      for (int i = 0; i < _terrainPoints.length; i++) {
        final point = _terrainPoints[i];
        markers.add(
          Marker(
            point: LatLng(point.latitude, point.longitude),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.purple[600],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.3),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }



    return markers;
  }

  Widget _buildInfoPanel(LocationState state) {
    if (state is! LocationTrackingActive && state is! LocationUpdated) {
      return const SizedBox();
    }

    Position? position;
    List<UserLocation> teamLocations = [];

    if (state is LocationTrackingActive) {
      position = state.currentPosition;
      teamLocations = state.teamLocations;
    } else if (state is LocationUpdated) {
      position = state.position;
      teamLocations = state.teamLocations;
    }

    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.location_on, color: Colors.green[600], size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Mi Ubicación',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (position != null) ...[
                Text(
                  'Lat: ${position.latitude.toStringAsFixed(6)}',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  'Lng: ${position.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  'Precisión: ${position.accuracy.toStringAsFixed(1)}m',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
              if (teamLocations.isNotEmpty) ...[
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    // Filtrar al usuario actual de la lista de compañeros
                    final currentUser = AuthService.currentUser;
                    final filteredTeammates = teamLocations.where((location) => 
                      currentUser == null || location.userId != currentUser.id
                    ).toList();
                    
                    return Text(
                      'Compañeros conectados: ${filteredTeammates.length}',
                      style: TextStyle(
                        color: Colors.orange[600],
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ],
              
              // Información del terreno (individual o colaborativo)
              if (_isCollaborativeMode && _collaborativePoints.isNotEmpty) ...[
                const SizedBox(height: 12),
                Divider(height: 1, color: Colors.grey[300]),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.group_work, color: Colors.green[600], size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Mapeo Colaborativo',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.green[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Puntos totales: ${_collaborativePoints.length}',
                  style: const TextStyle(fontSize: 11),
                ),
                Text(
                  'Participantes: ${_getUniqueParticipants()}',
                  style: const TextStyle(fontSize: 11),
                ),
                if (_collaborativePoints.length >= 3) ...[
                  FutureBuilder<String>(
                    future: _getCollaborativeFormattedArea(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return Text(
                          'Área: ${snapshot.data}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[600],
                          ),
                        );
                      }
                      return Text(
                        'Calculando área...',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      );
                    },
                  ),
                ],
              ] else if (!_isCollaborativeMode && _terrainPoints.isNotEmpty) ...[
                const SizedBox(height: 12),
                Divider(height: 1, color: Colors.grey[300]),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.terrain, color: Colors.purple[600], size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Mapeo Individual',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.purple[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Puntos marcados: ${_terrainPoints.length}',
                  style: const TextStyle(fontSize: 11),
                ),
                if (_terrainPoints.length >= 3) ...[
                  Text(
                    'Área: ${_getFormattedArea()}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[600],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButtons(LocationState state) {
    return Positioned(
      bottom: 16,
      right: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Botón de tracking
          FloatingActionButton(
            heroTag: "tracking",
            onPressed: () {
              if (context.read<LocationBloc>().isTracking) {
                _stopTracking();
              } else {
                context.read<LocationBloc>().add(LocationStartTracking());
              }
            },
            backgroundColor: context.read<LocationBloc>().isTracking
                ? Colors.red[600]
                : Colors.green[600],
            child: Icon(
              context.read<LocationBloc>().isTracking
                  ? Icons.stop
                  : Icons.play_arrow,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          
          // Botón para marcar punto del terreno
          if (!_isAddingPoints)
            const SizedBox(height: 12),
          if (!_isAddingPoints)
            FloatingActionButton(
              heroTag: "addPoint",
              onPressed: () => _startTerrainMapping(),
              backgroundColor: _isCollaborativeMode ? Colors.green[600] : Colors.purple[600],
              child: const Icon(Icons.add_location, color: Colors.white),
            ),
          
          // Botón para limpiar todos los puntos (solo visible en modo colaborativo con puntos)
          if (_isCollaborativeMode && _collaborativePoints.isNotEmpty && !_isAddingPoints)
            const SizedBox(height: 12),
          if (_isCollaborativeMode && _collaborativePoints.isNotEmpty && !_isAddingPoints)
            FloatingActionButton(
              heroTag: "clearAllCollaborative",
              onPressed: () => _clearAllCollaborativePoints(),
              backgroundColor: Colors.red[600],
              child: const Icon(Icons.clear_all, color: Colors.white),
            )
          // Botones modo mapeo
          else if (_isAddingPoints) ...[
            FloatingActionButton(
              heroTag: "markPoint",
              onPressed: _canMarkPoint(state) ? () => _markCurrentLocation(state) : null,
              backgroundColor: _canMarkPoint(state) 
                  ? (_isCollaborativeMode ? Colors.green[600] : Colors.purple[600])
                  : Colors.grey,
              child: const Icon(Icons.room, color: Colors.white),
            ),
            const SizedBox(height: 8),
            FloatingActionButton.small(
              heroTag: "undoPoint",
              onPressed: _canRemoveLastPoint() ? _removeLastPoint : null,
              backgroundColor: Colors.orange[600],
              child: const Icon(Icons.undo, color: Colors.white, size: 18),
            ),
            const SizedBox(height: 8),
            FloatingActionButton.small(
              heroTag: "clearPoints",
              onPressed: _canClearPoints() ? _clearAllPoints : null,
              backgroundColor: Colors.red[600],
              child: Icon(
                _isCollaborativeMode ? Icons.clear_all : Icons.clear,
                color: Colors.white, 
                size: 18
              ),
            ),
            const SizedBox(height: 8),
            FloatingActionButton(
              heroTag: "saveTerrain",
              onPressed: _canSaveTerrain() ? () => _showSaveTerrainDialog() : null,
              backgroundColor: _canSaveTerrain() ? Colors.green[600] : Colors.grey,
              child: const Icon(Icons.save, color: Colors.white),
            ),
            const SizedBox(height: 8),
            // Botón de refresh para modo colaborativo
            if (_isCollaborativeMode)
              FloatingActionButton.small(
                heroTag: "refreshCollaborative",
                onPressed: () {
                  final activeSessionId = LocationService.getActiveCollaborativeSession();
                  if (activeSessionId != null) {
                    _loadInitialCollaborativePoints(activeSessionId);
                    Fluttertoast.showToast(
                      msg: 'Puntos colaborativos actualizados',
                      backgroundColor: Colors.blue,
                      textColor: Colors.white,
                    );
                  }
                },
                backgroundColor: Colors.blue[600],
                child: const Icon(Icons.refresh, color: Colors.white, size: 18),
              ),
            if (_isCollaborativeMode)
              const SizedBox(height: 8),
            FloatingActionButton.small(
              heroTag: "cancelMapping",
              onPressed: () => _stopTerrainMapping(),
              backgroundColor: Colors.grey[600],
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ],


          
          const SizedBox(height: 12),
          // Botón de compartir ubicación
          FloatingActionButton(
            heroTag: "share",
            onPressed: () => _shareLocation(state),
            backgroundColor: Colors.blue[600],
            child: const Icon(Icons.share, color: Colors.white),
          ),
        ],
      ),
    );
  }

  // Funciones para manejo del terreno
  String _getFormattedArea() {
    if (_terrainPoints.length < 3) return '0 m²';
    
    // Usar puntos ordenados para cálculo correcto del área
    final area = Terrain.calculateArea(_orderedTerrainPoints);
    if (area < 10000) {
      return '${area.toStringAsFixed(2)} m²';
    } else {
      double hectares = area / 10000;
      return '${hectares.toStringAsFixed(2)} ha';
    }
  }



  void _startTerrainMapping() {
    if (!context.read<LocationBloc>().isTracking) {
      Fluttertoast.showToast(
        msg: 'Debes activar el tracking primero',
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }
    
    setState(() {
      _isAddingPoints = true;
      _terrainPoints.clear();
    });
    
    final modeText = _isCollaborativeMode ? 'colaborativo' : 'individual';
    final modeColor = _isCollaborativeMode ? Colors.green : Colors.purple;
    
    Fluttertoast.showToast(
      msg: 'Modo mapeo $modeText activado. Pulsa el botón para marcar tu ubicación actual',
      backgroundColor: modeColor,
      textColor: Colors.white,
      toastLength: Toast.LENGTH_LONG,
    );
  }

  Future<void> _stopTerrainMapping() async {
    setState(() {
      _isAddingPoints = false;
      _terrainPoints.clear();
    });
    
    // Si es modo colaborativo, limpiar puntos de la sesión actual
    if (_isCollaborativeMode) {
      final activeSessionId = LocationService.getActiveCollaborativeSession();
      if (activeSessionId != null && _collaborativePoints.isNotEmpty) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cancelar Mapeo Colaborativo'),
            content: const Text(
              '¿Quieres eliminar todos los puntos colaborativos de esta sesión? '
              'Esta acción afectará a todos los participantes.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Mantener puntos'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Eliminar puntos'),
              ),
            ],
          ),
        );

        if (confirm == true) {
          try {
            await CollaborativeTerrainService().clearAllPoints(activeSessionId);
            Fluttertoast.showToast(
              msg: 'Puntos colaborativos eliminados',
              backgroundColor: Colors.orange,
              textColor: Colors.white,
            );
          } catch (e) {
            print('Error limpiando puntos colaborativos: $e');
          }
        }
      }
    }
    
    Fluttertoast.showToast(
      msg: 'Modo mapeo cancelado',
      backgroundColor: Colors.grey,
      textColor: Colors.white,
    );
  }

  bool _canMarkPoint(LocationState state) {
    return _isAddingPoints && 
           context.read<LocationBloc>().isTracking &&
           (state is LocationTrackingActive || state is LocationUpdated);
  }
  // Funciones originales removidas - reemplazadas por versiones colaborativas
  // Función removida - ahora se usa _saveIndividualTerrain() y _saveCollaborativeTerrain()

  String _formatTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  LatLng? _lastValidPosition;
  Timer? _iconUpdateTimer;
  // Timer de BD removido - se gestiona desde LocationBloc
  
  // Actualizar solo el ícono sin mover la cámara (para tracking visual)
  void _updateIconOnly(Position position) {
    final newCenter = LatLng(position.latitude, position.longitude);
    
    // Filtrar posiciones con ruido GPS
    if (_lastValidPosition != null) {
      final distance = _calculateDistance(_lastValidPosition!, newCenter);
      if (distance < 4 && position.accuracy > 8) {
        return;
      }
      if (distance < 2) {
        return;
      }
    }
    
    final distance = _calculateDistance(_currentCenter, newCenter);
    
    // Actualizar solo si la distancia es significativa
    if (distance >= 3) {
      setState(() {
        _currentCenter = newCenter;
        _lastValidPosition = newCenter;
      });
    }
  }

  // Actualizar solo el ícono (nunca mover cámara excepto en inicialización)
  void _updateMapCenter(Position position) {
    final newCenter = LatLng(position.latitude, position.longitude);
    
    // Filtrar posiciones con ruido GPS más estricto
    if (_lastValidPosition != null) {
      final distance = _calculateDistance(_lastValidPosition!, newCenter);
      // Filtro más estricto: ignorar cambios menores a 4 metros con precisión baja
      if (distance < 4 && position.accuracy > 8) {
        return;
      }
      // Filtro adicional: ignorar cambios muy pequeños incluso con buena precisión
      if (distance < 2) {
        return;
      }
    }
    
    final distance = _calculateDistance(_currentCenter, newCenter);
    
    // Solo actualizar ícono si la distancia es significativa (mínimo 3 metros)
    if (distance >= 3) {
      setState(() {
        _currentCenter = newCenter;
        _lastValidPosition = newCenter;
      });
      // NUNCA mover la cámara desde aquí - solo actualizar ícono
    }
  }

  // Calcular distancia entre dos puntos LatLng
  double _calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude, 
      point1.longitude, 
      point2.latitude, 
      point2.longitude,
    );
  }

  // Ordenar puntos para formar un polígono sin líneas cruzadas
  List<TerrainPoint> _sortPointsForPolygon(List<TerrainPoint> points) {
    if (points.length < 3) return points;

    // Calcular el centroide
    double centerLat = 0;
    double centerLng = 0;
    for (var point in points) {
      centerLat += point.latitude;
      centerLng += point.longitude;
    }
    centerLat /= points.length;
    centerLng /= points.length;

    // Ordenar puntos por ángulo desde el centroide
    List<TerrainPoint> sortedPoints = List.from(points);
    sortedPoints.sort((a, b) {
      double angleA = math.atan2(a.latitude - centerLat, a.longitude - centerLng);
      double angleB = math.atan2(b.latitude - centerLat, b.longitude - centerLng);
      return angleA.compareTo(angleB);
    });

    return sortedPoints;
  }

  // Obtener puntos ordenados para mostrar en el mapa
  List<TerrainPoint> get _orderedTerrainPoints {
    return _sortPointsForPolygon(_terrainPoints);
  }

  // Iniciar timer para actualizar el ícono cada 5 segundos (tracking y sin tracking)
  void _startIconUpdateTimer() {
    _stopIconUpdateTimer();
    _iconUpdateTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final position = await LocationService.getCurrentLocation();
        if (position != null) {
          // Siempre solo actualizar ícono, nunca mover cámara desde el timer
          _updateIconOnly(position);
        }
      } catch (e) {
        print('Error en actualización del ícono: $e');
      }
    });
  }

  // Detener timer de actualización del ícono
  void _stopIconUpdateTimer() {
    _iconUpdateTimer?.cancel();
    _iconUpdateTimer = null;
  }

  // Timer de BD eliminado - se maneja desde LocationBloc

  // Método para detener tracking
  void _stopTracking() {
    context.read<LocationBloc>().add(LocationStopTracking());
    print('Tracking detenido');
  }

  void _centerOnCurrentLocation() {
    _mapController.moveAndRotate(_currentCenter, 15.0, 0);
  }

  // Método para cargar ubicaciones según el contexto (equipo o sesión colaborativa)
  void _loadTeamOrSessionLocations() {
    final activeSessionId = LocationService.getActiveCollaborativeSession();
    
    if (activeSessionId != null) {
      // Si hay una sesión colaborativa activa, cargar participantes de la sesión
      context.read<LocationBloc>().add(
        LocationCollaborativeSessionMembersRequested(activeSessionId),
      );
      print('Cargando ubicaciones de sesión colaborativa: $activeSessionId');
    } else {
      // Si no hay sesión colaborativa, cargar miembros del equipo
      context.read<LocationBloc>().add(LocationTeamMembersRequested());
      print('Cargando ubicaciones del equipo');
    }
  }

  void _showMemberInfo(BuildContext context, UserLocation location) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Información del Compañero'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nombre: ${location.fullName ?? 'Usuario'}'),
            Text('Lat: ${location.latitude.toStringAsFixed(6)}'),
            Text('Lng: ${location.longitude.toStringAsFixed(6)}'),
            if (location.accuracy != null)
              Text('Precisión: ${location.accuracy!.toStringAsFixed(1)}m'),
            Text('Última actualización: ${_formatTime(location.timestamp)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _navigateToLocation(location.latitude, location.longitude);
            },
            child: const Text('Navegar'),
          ),
        ],
      ),
    );
  }

  void _shareLocation(LocationState state) {
    Position? position;

    if (state is LocationTrackingActive) {
      position = state.currentPosition;
    } else if (state is LocationUpdated) {
      position = state.position;
    }

    if (position != null) {
      final link = LocationService.generateLocationLink(
        position.latitude,
        position.longitude,
      );

      // Aquí podrías usar el plugin share_plus para compartir
      Fluttertoast.showToast(
        msg: 'Link copiado: $link',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.blue,
        textColor: Colors.white,
      );
    }
  }

  void _navigateToLocation(double lat, double lng) {
    final link = LocationService.generateNavigationLink(lat, lng);
    Fluttertoast.showToast(
      msg: 'Link de navegación: $link',
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.green,
      textColor: Colors.white,
    );
  }

  // Debug info - remover después de probar
  void _showDebugInfo() {
    final activeSessionId = LocationService.getActiveCollaborativeSession();
    final blocState = context.read<CollaborativeSessionBloc>().state;
    
    String blocStateInfo = 'Desconocido';
    if (blocState is CollaborativeSessionLoaded) {
      blocStateInfo = 'Loaded - Sesión activa: ${blocState.activeSession?.id ?? "Ninguna"}';
    } else if (blocState is CollaborativeSessionJoined) {
      blocStateInfo = 'Joined - Sesión: ${blocState.session.id}';
    } else {
      blocStateInfo = blocState.runtimeType.toString();
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Debug Info'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Modo colaborativo: $_isCollaborativeMode'),
              Text('Sesión activa (LocationService): ${activeSessionId ?? "Ninguna"}'),
              Text('Estado del BLoC: $blocStateInfo'),
              Text('Puntos colaborativos: ${_collaborativePoints.length}'),
              Text('Puntos individuales: ${_terrainPoints.length}'),
              Text('Está agregando puntos: $_isAddingPoints'),
              Text('Stream activo: ${_collaborativePointsSubscription != null}'),
              const SizedBox(height: 8),
              Text('Puntos colaborativos:', style: TextStyle(fontWeight: FontWeight.bold)),
              for (final point in _collaborativePoints)
                Text('  • Punto ${point.pointNumber} - ${point.userFullName}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: () {
              _refreshCollaborativePoints();
              _initializeCollaborativeMode(); 
              Navigator.of(context).pop();
              Fluttertoast.showToast(
                msg: 'Modo colaborativo reinicializado',
                backgroundColor: Colors.blue,
                textColor: Colors.white,
              );
            },
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  // ===========================================
  // FUNCIONES PARA MODO COLABORATIVO
  // ===========================================

  // Inicializar modo colaborativo si hay sesión activa
  void _initializeCollaborativeMode() {
    final activeSessionId = LocationService.getActiveCollaborativeSession();
    
    setState(() {
      _isCollaborativeMode = activeSessionId != null;
    });
    
    if (activeSessionId != null) {
      _startCollaborativePointsStream(activeSessionId);
      print('Modo colaborativo activado para sesión: $activeSessionId');
    } else {
      print('Modo individual activado');
    }
  }

  // Iniciar stream de puntos colaborativos con polling como respaldo
  void _startCollaborativePointsStream(String sessionId) {
    _collaborativePointsSubscription?.cancel();
    _collaborativePollingTimer?.cancel();
    
    print('Iniciando stream colaborativo para sesión: $sessionId');
    
    // Cargar puntos iniciales
    _loadInitialCollaborativePoints(sessionId);
    
    // Intentar usar stream de Supabase
    try {
      _collaborativePointsSubscription = CollaborativeTerrainService()
          .watchSessionTerrainPoints(sessionId)
          .listen(
            (points) {
              if (mounted) {
                setState(() {
                  _collaborativePoints = points;
                });
                print('Stream: Puntos colaborativos actualizados: ${points.length}');
              }
            },
            onError: (error) {
              print('Error en stream de puntos colaborativos: $error');
              // Fallback a polling si el stream falla
              _startCollaborativePolling(sessionId);
            },
          );
    } catch (e) {
      print('Error iniciando stream: $e');
      _startCollaborativePolling(sessionId);
    }
    
    // Polling como respaldo adicional cada 3 segundos
    _startCollaborativePolling(sessionId);
  }

  // Polling como respaldo del stream
  void _startCollaborativePolling(String sessionId) {
    _collaborativePollingTimer?.cancel();
    
    _collaborativePollingTimer = Timer.periodic(Duration(seconds: 3), (_) async {
      if (mounted && _isCollaborativeMode) {
        try {
          final points = await CollaborativeTerrainService().getSessionTerrainPoints(sessionId);
          if (mounted) {
            // Comparar más que solo la longitud
            final currentIds = _collaborativePoints.map((p) => p.id).toSet();
            final newIds = points.map((p) => p.id).toSet();
            
            if (points.length != _collaborativePoints.length || !currentIds.containsAll(newIds)) {
              setState(() {
                _collaborativePoints = points;
              });
              print('Polling: Puntos actualizados: ${points.length}');
            }
          }
        } catch (e) {
          print('Error en polling: $e');
        }
      }
    });
  }

  // Cargar puntos colaborativos iniciales
  Future<void> _loadInitialCollaborativePoints(String sessionId) async {
    try {
      final points = await CollaborativeTerrainService().getSessionTerrainPoints(sessionId);
      if (mounted) {
        setState(() {
          _collaborativePoints = points;
        });
        print('Puntos colaborativos iniciales cargados: ${points.length}');
      }
    } catch (e) {
      print('Error cargando puntos colaborativos iniciales: $e');
    }
  }

  // Refrescar puntos colaborativos manualmente
  void _refreshCollaborativePoints() {
    if (_isCollaborativeMode) {
      final activeSessionId = LocationService.getActiveCollaborativeSession();
      if (activeSessionId != null) {
        _loadInitialCollaborativePoints(activeSessionId);
        print('Refrescando puntos colaborativos...');
      }
    }
  }

  // Verificar si se puede remover último punto
  bool _canRemoveLastPoint() {
    if (_isCollaborativeMode) {
      // En modo colaborativo, verificar si el usuario tiene puntos propios
      final currentUserId = AuthService.currentUser?.id;
      return _collaborativePoints.any((p) => p.userId == currentUserId);
    } else {
      return _terrainPoints.isNotEmpty;
    }
  }

  // Verificar si se puede limpiar todos los puntos
  bool _canClearPoints() {
    if (_isCollaborativeMode) {
      return _collaborativePoints.isNotEmpty;
    } else {
      return _terrainPoints.isNotEmpty;
    }
  }

  // Verificar si se puede guardar terreno
  bool _canSaveTerrain() {
    if (_isCollaborativeMode) {
      return _collaborativePoints.length >= 3;
    } else {
      return _terrainPoints.length >= 3;
    }
  }

  // Obtener número de participantes únicos
  int _getUniqueParticipants() {
    final uniqueUsers = _collaborativePoints.map((p) => p.userId).toSet();
    return uniqueUsers.length;
  }

  // Obtener área formateada colaborativa
  Future<String> _getCollaborativeFormattedArea() async {
    try {
      final activeSessionId = LocationService.getActiveCollaborativeSession();
      if (activeSessionId == null) return '0 m²';

      final area = await CollaborativeTerrainService().calculateTerrainArea(activeSessionId);
      
      if (area < 10000) {
        return '${area.toStringAsFixed(2)} m²';
      } else {
        double hectares = area / 10000;
        return '${hectares.toStringAsFixed(2)} ha';
      }
    } catch (e) {
      print('Error calculando área colaborativa: $e');
      return 'Error calculando';
    }
  }

  // Obtener puntos colaborativos ordenados
  List<CollaborativeTerrainPoint> get _orderedCollaborativePoints {
    if (_collaborativePoints.length < 3) return _collaborativePoints;
    
    // Ordenar por point_number
    final sortedPoints = List<CollaborativeTerrainPoint>.from(_collaborativePoints);
    sortedPoints.sort((a, b) => a.pointNumber.compareTo(b.pointNumber));
    return sortedPoints;
  }

  // Modificar función para marcar ubicación actual
  void _markCurrentLocation(LocationState state) {
    if (!_canMarkPoint(state)) return;

    Position? currentPosition;
    if (state is LocationTrackingActive) {
      currentPosition = state.currentPosition;
    } else if (state is LocationUpdated) {
      currentPosition = state.position;
    }

    if (currentPosition == null) {
      Fluttertoast.showToast(
        msg: 'No se pudo obtener la ubicación actual',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    if (_isCollaborativeMode) {
      _markCollaborativePoint(currentPosition);
    } else {
      _markIndividualPoint(currentPosition);
    }
  }

  // Marcar punto individual
  void _markIndividualPoint(Position position) {
    final newPoint = TerrainPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude,
    );

    setState(() {
      _terrainPoints.add(newPoint);
    });

    Fluttertoast.showToast(
      msg: 'Punto ${_terrainPoints.length} marcado',
      backgroundColor: Colors.green,
      textColor: Colors.white,
    );
  }

  // Marcar punto colaborativo
  Future<void> _markCollaborativePoint(Position position) async {
    final activeSessionId = LocationService.getActiveCollaborativeSession();
    if (activeSessionId == null) {
      Fluttertoast.showToast(
        msg: 'No hay sesión colaborativa activa',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    try {
      final result = await CollaborativeTerrainService().addTerrainPoint(
        sessionId: activeSessionId,
        latitude: position.latitude,
        longitude: position.longitude,
        altitude: position.altitude,
        accuracy: position.accuracy,
      );

      Fluttertoast.showToast(
        msg: 'Punto ${result['point_number']} agregado (Total: ${result['total_points']})',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
      
      // Forzar actualización inmediata
      Future.delayed(Duration(milliseconds: 500), () {
        if (mounted) {
          _loadInitialCollaborativePoints(activeSessionId);
        }
      });
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error agregando punto: $e',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  // Modificar función para remover último punto
  void _removeLastPoint() {
    if (_isCollaborativeMode) {
      _removeLastCollaborativePoint();
    } else {
      _removeLastIndividualPoint();
    }
  }

  // Remover último punto individual
  void _removeLastIndividualPoint() {
    if (_terrainPoints.isEmpty) return;

    setState(() {
      _terrainPoints.removeLast();
    });

    Fluttertoast.showToast(
      msg: 'Último punto eliminado',
      backgroundColor: Colors.orange,
      textColor: Colors.white,
    );
  }

  // Remover último punto colaborativo
  Future<void> _removeLastCollaborativePoint() async {
    final activeSessionId = LocationService.getActiveCollaborativeSession();
    if (activeSessionId == null) return;

    try {
      final success = await CollaborativeTerrainService().removeLastPoint(activeSessionId);
      
      if (success) {
        // Forzar actualización inmediata
        Future.delayed(Duration(milliseconds: 500), () {
          if (mounted) {
            _loadInitialCollaborativePoints(activeSessionId);
          }
        });
        
        Fluttertoast.showToast(
          msg: 'Tu último punto eliminado',
          backgroundColor: Colors.orange,
          textColor: Colors.white,
        );
      } else {
        Fluttertoast.showToast(
          msg: 'No tienes puntos para eliminar',
          backgroundColor: Colors.grey,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error eliminando punto: $e',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  // Modificar función para limpiar todos los puntos
  void _clearAllPoints() {
    if (_isCollaborativeMode) {
      _clearAllCollaborativePoints();
    } else {
      _clearAllIndividualPoints();
    }
  }

  // Limpiar puntos individuales
  void _clearAllIndividualPoints() {
    setState(() {
      _terrainPoints.clear();
    });

    Fluttertoast.showToast(
      msg: 'Todos los puntos eliminados',
      backgroundColor: Colors.red,
      textColor: Colors.white,
    );
  }

  // Limpiar puntos colaborativos
  Future<void> _clearAllCollaborativePoints() async {
    final activeSessionId = LocationService.getActiveCollaborativeSession();
    if (activeSessionId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpiar Todos los Puntos'),
        content: const Text(
          '¿Estás seguro de que quieres eliminar TODOS los puntos colaborativos? '
          'Esta acción afectará a todos los participantes y no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar Todo'),
          ),
        ],
      ),
    );

            if (confirm != true) return;

    try {
      await CollaborativeTerrainService().clearAllPoints(activeSessionId);
      
      // Forzar actualización inmediata
      setState(() {
        _collaborativePoints.clear();
      });
      
      // Recargar después de un delay
      Future.delayed(Duration(milliseconds: 500), () {
        if (mounted) {
          _loadInitialCollaborativePoints(activeSessionId);
        }
      });
      
      Fluttertoast.showToast(
        msg: 'Todos los puntos colaborativos eliminados',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error limpiando puntos: $e',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  // Mostrar información de punto colaborativo
  void _showCollaborativePointInfo(CollaborativeTerrainPoint point) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Punto #${point.pointNumber}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Creado por: ${point.userFullName}'),
            Text('Lat: ${point.latitude.toStringAsFixed(6)}'),
            Text('Lng: ${point.longitude.toStringAsFixed(6)}'),
            if (point.accuracy != null)
              Text('Precisión: ${point.accuracy!.toStringAsFixed(1)}m'),
            Text('Fecha: ${_formatTime(point.createdAt)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _navigateToLocation(point.latitude, point.longitude);
            },
            child: const Text('Navegar'),
          ),
        ],
      ),
    );
  }

  // Modificar función para mostrar diálogo de guardar
  void _showSaveTerrainDialog() {
    if (_isCollaborativeMode) {
      _showSaveCollaborativeTerrainDialog();
    } else {
      _showSaveIndividualTerrainDialog();
    }
  }

  // Diálogo para guardar terreno individual
  void _showSaveIndividualTerrainDialog() {
    if (_terrainPoints.length < 3) {
      Fluttertoast.showToast(
        msg: 'Se necesitan al menos 3 puntos para guardar el terreno',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Guardar Terreno'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Puntos marcados: ${_terrainPoints.length}'),
              Text('Área calculada: ${_getFormattedArea()}'),
              const SizedBox(height: 16),
              TextField(
                controller: _terrainNameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del terreno',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _terrainDescriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => _saveIndividualTerrain(),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  // Diálogo para guardar terreno colaborativo
  void _showSaveCollaborativeTerrainDialog() {
    if (_collaborativePoints.length < 3) {
      Fluttertoast.showToast(
        msg: 'Se necesitan al menos 3 puntos para guardar el terreno',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Guardar Terreno Colaborativo'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Puntos totales: ${_collaborativePoints.length}'),
              Text('Participantes: ${_getUniqueParticipants()}'),
              FutureBuilder<String>(
                future: _getCollaborativeFormattedArea(),
                builder: (context, snapshot) {
                  return Text(
                    'Área: ${snapshot.data ?? "Calculando..."}',
                  );
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _terrainNameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del terreno',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _terrainDescriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => _saveCollaborativeTerrain(),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  // Guardar terreno individual
  Future<void> _saveIndividualTerrain() async {
    if (_terrainNameController.text.trim().isEmpty) {
      Fluttertoast.showToast(
        msg: 'Ingresa un nombre para el terreno',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    Navigator.of(context).pop();

    try {
      final success = await TerrainService.createTerrain(
        name: _terrainNameController.text.trim(),
        description: _terrainDescriptionController.text.trim().isEmpty 
          ? null 
          : _terrainDescriptionController.text.trim(),
        points: _orderedTerrainPoints,
        teamId: null, // FORZAR NULL para mediciones individuales
      );

      if (success) {
        Fluttertoast.showToast(
          msg: 'Terreno guardado exitosamente',
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
        
        setState(() {
          _terrainPoints.clear();
          _isAddingPoints = false;
        });
        _terrainNameController.clear();
        _terrainDescriptionController.clear();
      } else {
        throw Exception('Error al guardar el terreno');
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error al guardar: $e',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  // Guardar terreno colaborativo
  Future<void> _saveCollaborativeTerrain() async {
    if (_terrainNameController.text.trim().isEmpty) {
      Fluttertoast.showToast(
        msg: 'Ingresa un nombre para el terreno',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    final activeSessionId = LocationService.getActiveCollaborativeSession();
    if (activeSessionId == null) {
      Fluttertoast.showToast(
        msg: 'No hay sesión colaborativa activa',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    Navigator.of(context).pop();

    try {
      final terrainId = await CollaborativeTerrainService().saveCollaborativeTerrain(
        sessionId: activeSessionId,
        name: _terrainNameController.text.trim(),
        description: _terrainDescriptionController.text.trim().isEmpty 
          ? null 
          : _terrainDescriptionController.text.trim(),
      );

      Fluttertoast.showToast(
        msg: 'Terreno colaborativo guardado exitosamente',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
      
      setState(() {
        _isAddingPoints = false;
      });
      _terrainNameController.clear();
      _terrainDescriptionController.clear();
      
      print('Terreno colaborativo guardado con ID: $terrainId');
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error al guardar terreno colaborativo: $e',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }
}
