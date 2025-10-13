import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

import 'package:marib/data/model/challenge_model.dart';

class CompetitionLogic {
  const CompetitionLogic();

  List<Challenge> _sortedByRequirement(List<Challenge> challenges) {
    final sorted = List<Challenge>.from(challenges)
      ..sort((a, b) => a.requiredReferrals.compareTo(b.requiredReferrals));
    return sorted;
  }

  Challenge? highestChallenge(List<Challenge> challenges) {
    if (challenges.isEmpty) {
      return null;
    }
    final active = challenges.where((c) => c.isActive).toList();
    final sorted =
    active.isEmpty ? _sortedByRequirement(challenges) : _sortedByRequirement(active);
    return sorted.isEmpty ? null : sorted.last;
  }

  Challenge? nearestUnreached(List<Challenge> challenges, int currentPoints) {
    if (challenges.isEmpty) {
      return null;
    }
    final active = challenges.where((c) => c.isActive).toList();
    final sorted =
    active.isEmpty ? _sortedByRequirement(challenges) : _sortedByRequirement(active);

    for (final challenge in sorted) {
      if (currentPoints < challenge.requiredReferrals) {
        return challenge;
      }
    }
    return null;
  }

  int remainingToNearest(List<Challenge> challenges, int currentPoints) {
    final nearest = nearestUnreached(challenges, currentPoints);
    if (nearest == null) {
      return 0;
    }
    final remaining = nearest.requiredReferrals - currentPoints;
    return remaining > 0 ? remaining : 0;
  }

  double progressToHighest(List<Challenge> challenges, int currentPoints) {
    final highest = highestChallenge(challenges);
    if (highest == null || highest.requiredReferrals <= 0) {
      return 0;
    }
    final ratio = currentPoints / highest.requiredReferrals;
    return ratio.clamp(0, 1).toDouble();
  }

  bool hasCollectibleReward(List<Challenge> challenges, int currentPoints) {
    if (challenges.isEmpty) {
      return false;
    }
    final active = challenges.where((challenge) => challenge.isActive).toList();
    final pool = active.isEmpty ? challenges : active;
    return pool.any(
          (challenge) =>
      challenge.requiredReferrals > 0 &&
          currentPoints >= challenge.requiredReferrals,
    );
  }
}

class CompetitionActions {
  const CompetitionActions({
    required this.onWarningFlagGetter,
    required this.onWarningFlagSetter,
    required this.onTryCollect,
    required this.onShakeAnimation,
    required this.goToChallengeInstructions,
    required this.onSavePaymentInfo,
  });

  final bool Function() onWarningFlagGetter;
  final void Function(bool flag) onWarningFlagSetter;
  final bool Function(int currentPoints, List<Challenge> challenges) onTryCollect;
  final Animation<double> Function() onShakeAnimation;
  final VoidCallback goToChallengeInstructions;
  final Future<void> Function({
  required List<String> paymentMethods,
  required Map<String, dynamic> paymentAccountDetails,
  String? businessName,
  String? businessWhatsapp,
  String? businessLocation,
  List<String>? businessCategories,
  String? commercialRegister,
  String? email,
  }) onSavePaymentInfo;
}