class CollaborativeSession {
  final String id;
  final String name;
  final String? description;
  final String teamId;
  final String? teamName;
  final String createdBy;
  final String? creatorName;
  final List<String> participants;
  final int participantCount;
  final bool isParticipant;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CollaborativeSession({
    required this.id,
    required this.name,
    this.description,
    required this.teamId,
    this.teamName,
    required this.createdBy,
    this.creatorName,
    this.participants = const [],
    this.participantCount = 0,
    this.isParticipant = false,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CollaborativeSession.fromJson(Map<String, dynamic> json) {
    return CollaborativeSession(
      id: json['session_id'] as String,
      name: json['session_name'] as String,
      description: json['session_description'] as String?,
      teamId: json['team_id'] as String,
      teamName: json['team_name'] as String?,
      createdBy: json['created_by'] as String,
      creatorName: json['creator_name'] as String?,
      participants: json['participants'] != null
          ? List<String>.from(json['participants'] as List)
          : [],
      participantCount: json['participant_count'] as int? ?? 0,
      isParticipant: json['is_participant'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'session_id': id,
      'session_name': name,
      'session_description': description,
      'team_id': teamId,
      'team_name': teamName,
      'created_by': createdBy,
      'creator_name': creatorName,
      'participants': participants,
      'participant_count': participantCount,
      'is_participant': isParticipant,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  CollaborativeSession copyWith({
    String? id,
    String? name,
    String? description,
    String? teamId,
    String? teamName,
    String? createdBy,
    String? creatorName,
    List<String>? participants,
    int? participantCount,
    bool? isParticipant,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CollaborativeSession(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      teamId: teamId ?? this.teamId,
      teamName: teamName ?? this.teamName,
      createdBy: createdBy ?? this.createdBy,
      creatorName: creatorName ?? this.creatorName,
      participants: participants ?? this.participants,
      participantCount: participantCount ?? this.participantCount,
      isParticipant: isParticipant ?? this.isParticipant,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'CollaborativeSession{id: $id, name: $name, teamName: $teamName, participantCount: $participantCount, isParticipant: $isParticipant}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CollaborativeSession &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
