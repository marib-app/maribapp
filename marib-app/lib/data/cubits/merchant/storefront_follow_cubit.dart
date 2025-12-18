import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/model/merchant/storefront_model.dart';
import 'package:marib/data/repositories/merchant/storefront_follow_repository.dart';

class StorefrontFollowState extends Equatable {
  const StorefrontFollowState({
    required this.isFollowing,
    required this.followersCount,
    this.isLoading = false,
    this.errorMessage,
  });

  final bool isFollowing;
  final int followersCount;
  final bool isLoading;
  final String? errorMessage;

  StorefrontFollowState copyWith({
    bool? isFollowing,
    int? followersCount,
    bool? isLoading,
    String? errorMessage,
  }) {
    return StorefrontFollowState(
      isFollowing: isFollowing ?? this.isFollowing,
      followersCount: followersCount ?? this.followersCount,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        isFollowing,
        followersCount,
        isLoading,
        errorMessage,
      ];
}

class StorefrontFollowCubit extends Cubit<StorefrontFollowState> {
  StorefrontFollowCubit({
    required int storeId,
    required StorefrontFollowRepository repository,
    required bool initialIsFollowing,
    required int initialFollowersCount,
  })  : _storeId = storeId,
        _repository = repository,
        super(
          StorefrontFollowState(
            isFollowing: initialIsFollowing,
            followersCount: max(0, initialFollowersCount),
          ),
        );

  StorefrontFollowCubit.fromDetails({
    required StorefrontDetails details,
    StorefrontFollowRepository? repository,
  }) : this(
          storeId: details.id,
          repository: repository ?? const StorefrontFollowRepository(),
          initialIsFollowing: details.isFollowed,
          initialFollowersCount: details.followersCount ?? 0,
        );

  final int _storeId;
  final StorefrontFollowRepository _repository;

  Future<void> toggleFollow() async {
    if (state.isLoading) return;

    final bool targetFollow = !state.isFollowing;
    final int currentCount = state.followersCount;
    final int nextCount = max(0, currentCount + (targetFollow ? 1 : -1));

    emit(
      state.copyWith(
        isFollowing: targetFollow,
        followersCount: nextCount,
        isLoading: true,
        errorMessage: null,
      ),
    );

    try {
      if (targetFollow) {
        await _repository.follow(_storeId);
      } else {
        await _repository.unfollow(_storeId);
      }
      emit(state.copyWith(isLoading: false));
    } catch (error) {
      emit(
        state.copyWith(
          isFollowing: !targetFollow,
          followersCount: currentCount,
          isLoading: false,
          errorMessage: error.toString(),
        ),
      );
    }
  }
}
