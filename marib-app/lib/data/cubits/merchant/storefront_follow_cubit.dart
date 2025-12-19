import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/model/merchant/storefront_model.dart';
import 'package:marib/data/repositories/merchant/storefront_follow_repository.dart';
import 'package:marib/data/repositories/merchant/storefront_repository.dart';

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
    required dynamic storeIdentifier,
    required StorefrontFollowRepository repository,
    required StorefrontRepository storefrontRepository,
    required bool initialIsFollowing,
    required int initialFollowersCount,
  })  : _storeId = storeIdentifier,
        _repository = repository,
        _storefrontRepository = storefrontRepository,
        super(
          StorefrontFollowState(
            isFollowing: initialIsFollowing,
            followersCount: max(0, initialFollowersCount),
          ),
        ) {
    // Sync with server to ensure initial state matches backend, even if snapshot is stale.
    Future.microtask(_refreshFromServer);
  }

  StorefrontFollowCubit.fromDetails({
    required StorefrontDetails details,
    StorefrontFollowRepository? repository,
    StorefrontRepository? storefrontRepository,
  }) : this(
          storeIdentifier: _resolveStoreIdentifier(details),
          repository: repository ?? const StorefrontFollowRepository(),
          storefrontRepository:
              storefrontRepository ?? const StorefrontRepository(),
          initialIsFollowing: details.isFollowed,
          initialFollowersCount: details.followersCount ?? 0,
        );

  final dynamic _storeId;
  final StorefrontFollowRepository _repository;
  final StorefrontRepository _storefrontRepository;

  static dynamic _resolveStoreIdentifier(StorefrontDetails details) {
    if (details.id != 0) return details.id;
    if (details.slug.trim().isNotEmpty) return details.slug;
    if (details.userId != null && details.userId! > 0) return details.userId;
    return null;
  }

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
      final result = targetFollow
          ? await _repository.follow(_storeId)
          : await _repository.unfollow(_storeId);

      emit(
        state.copyWith(
          isFollowing: result.isFollowing,
          followersCount: result.followersCount ?? state.followersCount,
          isLoading: false,
        ),
      );
      await _refreshFromServer();
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

  Future<void> _refreshFromServer() async {
    final String? identifier = _normalizeIdentifier(_storeId);
    if (identifier == null) return;
    bool isFollowing = state.isFollowing;
    int followersCount = state.followersCount;

    try {
      final StorefrontFollowResult status =
          await _repository.status(identifier);
      isFollowing = status.isFollowing;
      if (status.followersCount != null) {
        followersCount = status.followersCount!;
      }
    } catch (_) {
      // ignore, fall back to store fetch
    }

    try {
      final StorefrontDetails fresh =
          await _storefrontRepository.fetchStore(identifier);
      isFollowing = fresh.isFollowed || isFollowing;
      if (fresh.followersCount != null) {
        followersCount = fresh.followersCount!;
      }
    } catch (_) {
      // ignore, keep whatever we have
    }

    emit(
      state.copyWith(
        isFollowing: isFollowing,
        followersCount: followersCount,
        isLoading: false,
      ),
    );
  }

  String? _normalizeIdentifier(dynamic raw) {
    if (raw == null) return null;
    final String id = raw.toString().trim();
    if (id.isEmpty) return null;
    if (id == 'null' || id == '0') return null;
    return id;
  }
}
