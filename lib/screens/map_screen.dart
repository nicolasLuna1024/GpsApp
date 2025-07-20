import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import '../bloc/location_bloc.dart';
import '../models/user_location.dart';
import '../services/location_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  

  final MapController _mapController = MapController();

  double _currentZoom = 15.0;
  LatLng _currentCenter = const LatLng(0, 0);
  bool _hasCenteredOnce = false;

  void _initialMapCenter(Position nuevoCentro) {
    final nuevaUbicacion = LatLng(nuevoCentro.latitude, nuevoCentro.longitude);
    setState(() {
      _currentCenter = nuevaUbicacion;
    });

    // Mover el mapa a la ubicación del dispositivo
    _mapController.move(nuevaUbicacion, _currentZoom);
  }


  @override
  void initState() {
    super.initState();
    // Solicitar permisos y empezar tracking al cargar la pantalla
    context.read<LocationBloc>().add(LocationPermissionRequested());
    
    _mapController.mapEventStream.listen((event){
      setState(() {
        _currentZoom = event.camera.zoom;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              context.read<LocationBloc>().add(LocationTeamMembersRequested());
            },
          ),
          IconButton(
            icon: const Icon(Icons.my_location, color: Colors.white),
            onPressed: _centerOnCurrentLocation,
          ),
        ],
      ),
      body:
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
          } else if (state is LocationUpdated) {
            _updateMapCenter(state.position);
          }
        },
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
                    maxZoom: 18.0,
                    minZoom: 5.0,
                  ),
                  children: [
                    // Capa de tiles de OpenStreetMap
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.app_final',
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
    );
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

      // Marcadores para miembros del equipo
      for (var location in state.teamLocations) {
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

      for (var location in state.teamLocations) {
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
                Text(
                  'Compañeros conectados: ${teamLocations.length}',
                  style: TextStyle(
                    color: Colors.orange[600],
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
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
          FloatingActionButton(
            heroTag: "tracking",
            onPressed: () {
              if (context.read<LocationBloc>().isTracking) {
                context.read<LocationBloc>().add(LocationStopTracking());
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

  void _updateMapCenter(Position position) {
    setState(() {
      _currentCenter = LatLng(position.latitude, position.longitude);
    });
    _mapController.move(_currentCenter, _currentZoom);
  }

  void _centerOnCurrentLocation() {
    _mapController.move(_currentCenter, 15.0);
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
            Text('ID: ${location.userId}'),
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

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
