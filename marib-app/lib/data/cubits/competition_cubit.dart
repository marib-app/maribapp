import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/model/challenge_model.dart';
import 'package:marib/ui/screens/competitions/user_referral_points.dart';
import 'package:marib/data/repositories/competition_repository.dart';
import 'package:flutter/foundation.dart';


// الحالة الأساسية للكوبت
abstract class CompetitionState {
  const CompetitionState();
  List<Object?> get props => [];
}

class CompetitionInitial extends CompetitionState {}

class CompetitionLoading extends CompetitionState {}

class CompetitionSuccess extends CompetitionState {
  final UserReferralPoints referralPoints;
  final List<Challenge> challenges;
  final List<dynamic> paymentTransactions;
  final Challenge nextChallenge;
  final int maxPoints;
  final int totalPoints;
  final int totalRequiredReferrals;


  const CompetitionSuccess(
      this.referralPoints,
      this.challenges,
      this.paymentTransactions,
      this.nextChallenge,
      this.maxPoints,
      this.totalPoints,
      this.totalRequiredReferrals,
      );

  @override
  List<Object?> get props => [
    referralPoints,
    challenges,
    paymentTransactions,
    nextChallenge,
    maxPoints,
    totalPoints,
    totalRequiredReferrals,
  ];
}

class CompetitionFailure extends CompetitionState {
  final String error;

  const CompetitionFailure(this.error);

  @override
  List<Object?> get props => [error];
}


// الكيوبت الرئيسي
class CompetitionCubit extends Cubit<CompetitionState> {
  final CompetitionRepository _competitionRepository;

  CompetitionCubit(this._competitionRepository) : super(CompetitionInitial());

  Future<void> fetchCompetitionData() async {
    emit(CompetitionLoading());
    try {
      // جلب البيانات الأولية من الريبو
      final referralPointsRaw =
      await _competitionRepository.getUserReferralPoints();
      final envelope = await _competitionRepository.getChallenges();

      List<dynamic> paymentTransactions = <dynamic>[];
      try {
        paymentTransactions =
        await _competitionRepository.getRecentPaymentTransactions();
      } catch (e) {
        debugPrint('Failed to load recent payment transactions: $e');
        paymentTransactions = <dynamic>[];
      }

      // التحويل إلى نماذج فعلية
      final referralPoints = UserReferralPoints.fromJson(referralPointsRaw);
      final dynamic challengesData = envelope['challenges'];
      final List<Challenge> challenges;
      if (challengesData is List<Challenge>) {
        challenges = List<Challenge>.from(challengesData);
      } else if (challengesData is List) {
        challenges = challengesData
            .whereType<Map<String, dynamic>>()
            .map(Challenge.fromJson)
            .toList();
      } else {
        challenges = <Challenge>[];
      }

      final int maxPoints = (envelope['max_points'] as num?)?.toInt() ?? 0;
      final int totalPoints = (envelope['total_points'] as num?)?.toInt() ?? 0;
      final int totalRequiredReferrals =
          (envelope['total_required_referrals'] as num?)?.toInt() ?? 0;


      // ترتيب التحديات وتصفيتها
      final sortedChallenges = challenges.where((c) => c.isActive).toList()
        ..sort((a, b) => a.requiredReferrals.compareTo(b.requiredReferrals));

      // الحصول على التحدي القادم للمستخدم
      final Challenge nextChallenge;
      if (sortedChallenges.isEmpty) {
        nextChallenge = Challenge.empty();
      } else {
        nextChallenge = sortedChallenges.firstWhere(
              (challenge) =>
          referralPoints.currentPoints < challenge.requiredReferrals,
          orElse: () => sortedChallenges.last,
        );
      }

      emit(CompetitionSuccess(
        referralPoints,
        challenges,
        paymentTransactions,
        nextChallenge,
        maxPoints,
        totalPoints,
        totalRequiredReferrals,
      ));
    } catch (e) {
      emit(CompetitionFailure(e.toString()));
    }
  }

  Future<void> savePaymentInfo({
    required List<String> paymentMethods,
    required Map<String, dynamic> paymentAccountDetails,
    String? businessName,
    String? businessWhatsapp,
    String? businessLocation,
    List<String>? businessCategories,
    String? commercialRegister,
    String? email,
  }) async {
    final previousState = state;

    try {
      await _competitionRepository.savePaymentInfo(
        accountType: '2',
        businessName: businessName,
        businessWhatsapp: businessWhatsapp,
        businessLocation: businessLocation,
        businessCategories: businessCategories,
        commercialRegister: commercialRegister,
        paymentMethods: paymentMethods,
        paymentAccountDetails: paymentAccountDetails,
        email: email,
      );

      if (previousState is CompetitionSuccess) {
        List<dynamic> updatedTransactions =
            previousState.paymentTransactions;

        try {
          updatedTransactions = List<dynamic>.from(
            await _competitionRepository.getRecentPaymentTransactions(),
          );
        } catch (error) {
          debugPrint('Failed to refresh payment transactions: $error');
        }

        emit(CompetitionSuccess(
          previousState.referralPoints,
          previousState.challenges,
          updatedTransactions,
          previousState.nextChallenge,
          previousState.maxPoints,
          previousState.totalPoints,
          previousState.totalRequiredReferrals,
        ));
      } else {
        await fetchCompetitionData();
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to save payment info: $error');
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

}
