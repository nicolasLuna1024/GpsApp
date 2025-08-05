class UserLocation {
  final String id;
  final String userId;
  final String? fullName; // Nombre completo del usuario
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? accuracy;
  final double? heading;
  final double? speed;
  final String? collaborativeSessionId; // Nuevo campo
  final DateTime timestamp;
  final bool isActive;

  const UserLocation({
    required this.id,
    required this.userId,
    this.fullName,
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.accuracy,
    this.heading,
    this.speed,
    this.collaborativeSessionId, // Nuevo campo
    required this.timestamp,
    this.isActive = true,
  });

  factory UserLocation.fromJson(Map<String, dynamic> json) {
    // Extraer full_name del JOIN con user_profiles si está disponible
    String? fullName;
    if (json['user_profiles'] != null) {
      final userProfile = json['user_profiles'];
      if (userProfile is List && userProfile.isNotEmpty) {
        fullName = userProfile.first['full_name'] as String?;
      } else if (userProfile is Map<String, dynamic>) {
        fullName = userProfile['full_name'] as String?;
      }
    }
    
    return UserLocation(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      fullName: fullName,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      altitude: json['altitude'] != null
          ? (json['altitude'] as num).toDouble()
          : null,
      accuracy: json['accuracy'] != null
          ? (json['accuracy'] as num).toDouble()
          : null,
      heading: json['heading'] != null
          ? (json['heading'] as num).toDouble()
          : null,
      speed: json['speed'] != null ? (json['speed'] as num).toDouble() : null,
      collaborativeSessionId: json['collaborative_session_id'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'accuracy': accuracy,
      'heading': heading,
      'speed': speed,
      'collaborative_session_id': collaborativeSessionId,
      'timestamp': timestamp.toIso8601String(),
      'is_active': isActive,
    };
  }

  UserLocation copyWith({
    String? id,
    String? userId,
    String? fullName,
    double? latitude,
    double? longitude,
    double? altitude,
    double? accuracy,
    double? heading,
    double? speed,
    String? collaborativeSessionId,
    DateTime? timestamp,
    bool? isActive,
  }) {
    return UserLocation(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
      accuracy: accuracy ?? this.accuracy,
      heading: heading ?? this.heading,
      speed: speed ?? this.speed,
      collaborativeSessionId: collaborativeSessionId ?? this.collaborativeSessionId,
      timestamp: timestamp ?? this.timestamp,
      isActive: isActive ?? this.isActive,
    );
  }
}
