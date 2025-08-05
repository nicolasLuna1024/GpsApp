class TerrainPoint {
  final double latitude;
  final double longitude;
  final double? altitude;
  final DateTime timestamp;

  TerrainPoint({
    required this.latitude,
    required this.longitude,
    this.altitude,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory TerrainPoint.fromJson(Map<String, dynamic> json) {
    return TerrainPoint(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      altitude: json['altitude'] != null
          ? (json['altitude'] as num).toDouble()
          : null,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(), // Usar fecha actual si no hay timestamp
    );
  }
}

class Terrain {
  final String id;
  final String name;
  final String? description;
  final List<TerrainPoint> points;
  final double area; // en metros cuadrados
  final String userId;
  final String? teamId;
  final String? teamName; // NUEVA FUNCIONALIDAD: Nombre del equipo para UI
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  Terrain({
    required this.id,
    required this.name,
    this.description,
    required this.points,
    required this.area,
    required this.userId,
    this.teamId,
    this.teamName, // NUEVA FUNCIONALIDAD: Parámetro opcional
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'points': points.map((point) => point.toJson()).toList(),
      'area': area,
      'user_id': userId,
      'team_id': teamId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_active': isActive,
    };
  }

  factory Terrain.fromJson(Map<String, dynamic> json) {
    // NUEVA FUNCIONALIDAD: Extraer nombre del equipo si está presente
    String? teamName;
    if (json['teams'] != null) {
      final teams = json['teams'] as Map<String, dynamic>;
      teamName = teams['name'] as String?;
    }

    return Terrain(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?, // Permitir null
      points: (json['points'] as List)
          .map((point) => TerrainPoint.fromJson(point as Map<String, dynamic>))
          .toList(),
      area: (json['area'] as num).toDouble(),
      userId: json['user_id'] as String,
      teamId: json['team_id'] as String?, // Permitir null
      teamName: teamName, // NUEVA FUNCIONALIDAD: Asignar nombre del equipo
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  // Calcular área usando la fórmula de Shoelace (para coordenadas geográficas)
  static double calculateArea(List<TerrainPoint> points) {
    if (points.length < 3) return 0.0;

    double area = 0.0;
    for (int i = 0; i < points.length; i++) {
      int j = (i + 1) % points.length;
      area += points[i].longitude * points[j].latitude;
      area -= points[j].longitude * points[i].latitude;
    }
    area = (area / 2.0).abs();

    // Convertir de grados cuadrados a metros cuadrados aproximadamente
    // Factor de conversión aproximado (varía según la latitud)
    const double metersPerDegree = 111320; // metros por grado en el ecuador
    return area * metersPerDegree * metersPerDegree;
  }

  // Formatear área para mostrar
  String get formattedArea {
    if (area < 10000) {
      return '${area.toStringAsFixed(2)} m²';
    } else {
      double hectares = area / 10000;
      return '${hectares.toStringAsFixed(2)} ha';
    }
  }
}
