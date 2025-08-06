class CollaborativeTerrainPoint {
  final String id;
  final String? collaborativeSessionId;
  final String? userId;
  final String userFullName;
  final int pointNumber;
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? accuracy;
  final DateTime createdAt;
  final bool isActive;

  CollaborativeTerrainPoint({
    required this.id,
    this.collaborativeSessionId,
    this.userId,
    required this.userFullName,
    required this.pointNumber,
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.accuracy,
    required this.createdAt,
    this.isActive = true,
  });

  factory CollaborativeTerrainPoint.fromJson(Map<String, dynamic> json) {
    return CollaborativeTerrainPoint(
      id: json['point_id']?.toString() ?? json['id']?.toString() ?? '',
      collaborativeSessionId: json['collaborative_session_id']?.toString(),
      userId: json['user_id']?.toString(),
      userFullName: json['user_full_name']?.toString() ?? 'Usuario',
      pointNumber: json['point_number']?.toInt() ?? 0,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      altitude: json['altitude']?.toDouble(),
      accuracy: json['accuracy']?.toDouble(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'collaborative_session_id': collaborativeSessionId,
      'user_id': userId,
      'user_full_name': userFullName,
      'point_number': pointNumber,
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'accuracy': accuracy,
      'created_at': createdAt.toIso8601String(),
      'is_active': isActive,
    };
  }

  @override
  String toString() {
    return 'CollaborativeTerrainPoint(id: $id, pointNumber: $pointNumber, lat: $latitude, lng: $longitude, user: $userFullName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CollaborativeTerrainPoint && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
