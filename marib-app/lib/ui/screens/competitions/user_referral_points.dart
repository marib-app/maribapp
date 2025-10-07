class UserReferralPoints {
  final int totalPoints;
  final String nextRewardMessage;
  final String inviteFriendMessage;
  final String qrCodeData;
  final int currentPoints;
  final int maxPoints;
  final String referralCode;
  final int referredUsersCount;


  const UserReferralPoints({
    required this.totalPoints,
    required this.nextRewardMessage,
    required this.inviteFriendMessage,
    required this.qrCodeData,
    required this.currentPoints,
    required this.maxPoints,
    required this.referralCode,
    required this.referredUsersCount,
  });

  factory UserReferralPoints.fromJson(Map<String, dynamic> json) {
    return UserReferralPoints(

      totalPoints: json['total_points'] ?? 0,
      nextRewardMessage: json['next_reward_message'] ?? '',
      inviteFriendMessage: json['invite_friend_message'] ?? '',
      qrCodeData: json['qr_code_data'] ?? '',
      currentPoints: json['current_points'] ?? 0,
      maxPoints: json['max_points'] ?? 0,
      referralCode: json['referral_code'] ?? '',
      referredUsersCount: json['referred_users_count'] ?? 0,
    );
  }


  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is UserReferralPoints &&
              runtimeType == other.runtimeType &&
              totalPoints == other.totalPoints &&
              nextRewardMessage == other.nextRewardMessage &&
              inviteFriendMessage == other.inviteFriendMessage &&
              qrCodeData == other.qrCodeData &&
              currentPoints == other.currentPoints &&
              maxPoints == other.maxPoints &&
              referralCode == other.referralCode &&
              referredUsersCount == other.referredUsersCount;

  @override
  int get hashCode =>
      totalPoints.hashCode ^
      nextRewardMessage.hashCode ^
      inviteFriendMessage.hashCode ^
      qrCodeData.hashCode ^
      currentPoints.hashCode ^
      maxPoints.hashCode ^
      referralCode.hashCode ^
      referredUsersCount.hashCode;


  bool get hasMaxedOut => currentPoints >= maxPoints;
}
