import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:marib/data/model/subscription_status.dart';
import 'package:marib/data/repositories/subscription_repository.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/errorFilter.dart';

abstract class PromoteAdState {
  const PromoteAdState();
}

class PromoteAdIdle extends PromoteAdState {
  const PromoteAdIdle();
}

class PromoteAdChecking extends PromoteAdState {
  const PromoteAdChecking({this.previousStatus});

  final SubscriptionStatus? previousStatus;
}

class PromoteAdSubscriberReady extends PromoteAdState {
  const PromoteAdSubscriberReady({
    required this.status,
    required this.hasBalance,
    required this.isFeatured,
    required this.canPause,
    this.message,

  });

  final SubscriptionStatus status;
  final bool hasBalance;
  final bool isFeatured;
  final bool canPause;
  final String? message;

  double? get availableBalance => status.availableBalance;
  int? get featuredCount => status.featuredCount;
}

class PromoteAdNonSubscriber extends PromoteAdState {
  const PromoteAdNonSubscriber({
    required this.status,
    this.message,
  });

  final SubscriptionStatus status;
  final String? message;

}

class PromoteAdActing extends PromoteAdState {
  const PromoteAdActing({
    required this.status,
    required this.isFeaturing,
  });

  final SubscriptionStatus status;
  final bool isFeaturing;
}

class PromoteAdError extends PromoteAdState {
  const PromoteAdError({
    required this.message,
    this.status,
  });

  final String message;
  final SubscriptionStatus? status;
}

class PromoteAdCubit extends Cubit<PromoteAdState> {
  PromoteAdCubit({
    required int adId,
    SubscriptionRepository? subscriptionRepository,
  })  : _adId = adId,
        _subscriptionRepository = subscriptionRepository ?? SubscriptionRepository(),
        super(const PromoteAdIdle());

  final int _adId;
  final SubscriptionRepository _subscriptionRepository;

  Future<void> check() async {
    final SubscriptionStatus? previous = _extractStatus(state);
    emit(PromoteAdChecking(previousStatus: previous));
    try {
      final SubscriptionStatus status = await _subscriptionRepository.fetchStatus();
      _emitFromStatus(status);
    } on ApiException catch (error) {
      emit(PromoteAdError(
        message: _resolveErrorMessage(error.errorMessage),
        status: previous,
      ));
    } catch (error) {
      emit(PromoteAdError(
        message: _resolveErrorMessage(error),
        status: previous,
      ));
    }
  }

  Future<void> feature() async {
    final SubscriptionStatus? previous = _extractStatus(state);
    if (previous == null) {
      await check();
      return;
    }

    if (!_canActOnStatus(previous)) {
      emit(PromoteAdError(
        message: _resolveErrorMessage('insufficient-balance'),
        status: previous,
      ));
      return;
    }

    if (_adId <= 0) {
      emit(PromoteAdError(
        message: _resolveErrorMessage('لا يمكن تحديد الإعلان الحالي'),
        status: previous,
      ));
      return;
    }

    emit(PromoteAdActing(status: previous, isFeaturing: true));
    try {
      final Map<String, dynamic> response =
      await _subscriptionRepository.featureAd(_adId);
      final String? message = _extractSuccessMessage(response);

      final SubscriptionStatus status = await _subscriptionRepository.fetchStatus();
      _emitFromStatus(status, successMessage: message);
    } on ApiException catch (error) {
      emit(PromoteAdError(
        message: _resolveErrorMessage(error.errorMessage),
        status: previous,
      ));
    } catch (error) {
      emit(PromoteAdError(
        message: _resolveErrorMessage(error),
        status: previous,
      ));
    }
  }

  Future<void> unfeature() async {
    final SubscriptionStatus? previous = _extractStatus(state);
    if (previous == null) {
      await check();
      return;
    }

    if (_adId <= 0) {
      emit(PromoteAdError(
        message: _resolveErrorMessage('لا يمكن تحديد الإعلان الحالي'),
        status: previous,
      ));
      return;
    }

    emit(PromoteAdActing(status: previous, isFeaturing: false));
    try {
      final Map<String, dynamic> response =
      await _subscriptionRepository.unfeatureAd(_adId);
      final String? message = _extractSuccessMessage(response);

      final SubscriptionStatus status = await _subscriptionRepository.fetchStatus();
      _emitFromStatus(status, successMessage: message);
    } on ApiException catch (error) {
      emit(PromoteAdError(
        message: _resolveErrorMessage(error.errorMessage),
        status: previous,
      ));
    } catch (error) {
      emit(PromoteAdError(
        message: _resolveErrorMessage(error),
        status: previous,
      ));
    }
  }

  void _emitFromStatus(SubscriptionStatus status, {String? successMessage}) {
    final String? trimmed = successMessage?.trim();
    final String? message = (trimmed == null || trimmed.isEmpty) ? null : trimmed;

    if (!status.hasActive) {
      emit(PromoteAdNonSubscriber(status: status, message: message));
      return;
    }

    final bool isFeatured = status.isFeatured ?? false;
    final bool canPause = status.canPause ?? false;
    emit(PromoteAdSubscriberReady(
      status: status,
      hasBalance: _hasBalance(status),
      isFeatured: isFeatured,
      canPause: canPause,
      message: message,
    ));
  }

  SubscriptionStatus? _extractStatus(PromoteAdState state) {
    if (state is PromoteAdSubscriberReady) {
      return state.status;
    }
    if (state is PromoteAdNonSubscriber) {
      return state.status;
    }
    if (state is PromoteAdActing) {
      return state.status;
    }
    if (state is PromoteAdError) {
      return state.status;
    }
    if (state is PromoteAdChecking) {
      return state.previousStatus;
    }
    return null;
  }

  bool _hasBalance(SubscriptionStatus status) {
    final double available = status.availableBalance ?? 0;
    final int remaining = status.featuredCount ?? 0;
    return available > 0 || remaining > 0;
  }

  bool _canActOnStatus(SubscriptionStatus status) {
    if (!status.hasActive) {
      return false;
    }
    return _hasBalance(status) || (status.isFeatured ?? false);
  }

  String _resolveErrorMessage(dynamic errorCode) {
    return ErrorFilter.check(errorCode ?? 'unknown-error').error.toString();
  }

  String? _extractSuccessMessage(Map<String, dynamic> response) {
    String? resolveMessage(Map<String, dynamic> source) {
      for (final String key in const ['message', 'msg']) {
        final dynamic value = source[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
      return null;
    }

    final String? direct = resolveMessage(response);
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }

    final dynamic data = response['data'];
    if (data is Map<String, dynamic>) {
      final String? nested = resolveMessage(data);
      if (nested != null && nested.isNotEmpty) {
        return nested;
      }
    }
    return null;
  }
}