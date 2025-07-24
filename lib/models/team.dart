class Team {
  final String id;
  final String name;
  final String? description;
  final String? leaderId;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  // Nuevos campos para membresía
  final String? roleInTeam;
  final bool? isLeader;
  final int? memberCount;

  const Team({
    required this.id,
    required this.name,
    this.description,
    this.leaderId,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.roleInTeam,
    this.isLeader,
    this.memberCount,
  });

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: json['team_id'] != null
          ? json['team_id'] as String
          : json['id'] as String,
      name: json['team_name'] != null
          ? json['team_name'] as String
          : json['name'] as String,
      description: json['team_description'] != null
          ? json['team_description'] as String?
          : json['description'] as String?,
      leaderId: json['leader_id'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(
        json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updated_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
      roleInTeam: json['role_in_team'] as String?,
      isLeader: json['is_leader'] as bool?,
      memberCount: json['member_count'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'leader_id': leaderId,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'role_in_team': roleInTeam,
      'is_leader': isLeader,
      'member_count': memberCount,
    };
  }

  Team copyWith({
    String? id,
    String? name,
    String? description,
    String? leaderId,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? roleInTeam,
    bool? isLeader,
    int? memberCount,
  }) {
    return Team(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      leaderId: leaderId ?? this.leaderId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      roleInTeam: roleInTeam ?? this.roleInTeam,
      isLeader: isLeader ?? this.isLeader,
      memberCount: memberCount ?? this.memberCount,
    );
  }

  @override
  String toString() {
    return 'Team(id: $id, name: $name, description: $description, leaderId: $leaderId, isActive: $isActive, roleInTeam: $roleInTeam, isLeader: $isLeader, memberCount: $memberCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Team && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
