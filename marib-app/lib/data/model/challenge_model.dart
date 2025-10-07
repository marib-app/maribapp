class Challenge {
  final int id;
  final String title;
  final String description;
  final int requiredReferrals;   // من الـ API: required_referrals
  final int pointsPerReferral;   // من الـ API: points_per_referral
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  const Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.requiredReferrals,
    required this.pointsPerReferral,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  /// توافق مع الشاشات التي تستخدم requiredPoints
  int get requiredPoints => requiredReferrals;

  /// مجموع النقاط الممكنة (اختياري)
  int get totalPossiblePoints => requiredReferrals * pointsPerReferral;

  /// ✅ بديل آمن لو احتجت كائن افتراضي
  factory Challenge.empty() => const Challenge(
    id: 0,
    title: '',
    description: '',
    requiredReferrals: 0,
    pointsPerReferral: 0,
    isActive: false,
    createdAt: '',
    updatedAt: '',
  );

  factory Challenge.fromJson(Map<String, dynamic> json) {
    return Challenge(
      id: (json['id'] ?? 0) as int,
      title: (json['title'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      requiredReferrals: (json['required_referrals'] ?? json['requiredPoints'] ?? 0) as int,
      pointsPerReferral: (json['points_per_referral'] ?? 0) as int,
      isActive: json['is_active'] is bool
          ? (json['is_active'] as bool)
          : (json['is_active'] == 1),
      createdAt: (json['created_at'] ?? '') as String,
      updatedAt: (json['updated_at'] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'required_referrals': requiredReferrals,
      'points_per_referral': pointsPerReferral,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  Challenge copyWith({
    int? id,
    String? title,
    String? description,
    int? requiredReferrals,
    int? pointsPerReferral,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
  }) {
    return Challenge(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      requiredReferrals: requiredReferrals ?? this.requiredReferrals,
      pointsPerReferral: pointsPerReferral ?? this.pointsPerReferral,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Challenge &&
              runtimeType == other.runtimeType &&
              id == other.id &&
              title == other.title &&
              description == other.description &&
              requiredReferrals == other.requiredReferrals &&
              pointsPerReferral == other.pointsPerReferral &&
              isActive == other.isActive &&
              createdAt == other.createdAt &&
              updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      description.hashCode ^
      requiredReferrals.hashCode ^
      pointsPerReferral.hashCode ^
      isActive.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode;
}
