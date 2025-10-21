import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/model/service_request_model.dart';
import 'package:marib/data/model/service_request_page.dart';
import 'package:marib/data/repositories/service_request_repository.dart';

enum ServiceRequestFilter { review, approved, rejected }

extension ServiceRequestFilterExtension on ServiceRequestFilter {
  String get apiValue => switch (this) {
    ServiceRequestFilter.review => 'review',
    ServiceRequestFilter.approved => 'approved',
    ServiceRequestFilter.rejected => 'rejected',
  };
}

class ServiceRequestPageState {
  const ServiceRequestPageState({
    required this.requests,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.isLoading,
    required this.isRefreshing,
    required this.isLoadingMore,
    required this.hasError,
    required this.loadMoreError,
    this.errorMessage,
  });

  factory ServiceRequestPageState.initial() => const ServiceRequestPageState(
    requests: <ServiceRequestModel>[],
    currentPage: 0,
    lastPage: 1,
    total: 0,
    isLoading: false,
    isRefreshing: false,
    isLoadingMore: false,
    hasError: false,
    loadMoreError: false,
    errorMessage: null,
  );

  final List<ServiceRequestModel> requests;
  final int currentPage;
  final int lastPage;
  final int total;
  final bool isLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final bool hasError;
  final bool loadMoreError;
  final String? errorMessage;

  bool get hasMore => currentPage < lastPage;
  bool get hasLoaded => currentPage > 0 || requests.isNotEmpty;

  ServiceRequestPageState copyWith({
    List<ServiceRequestModel>? requests,
    int? currentPage,
    int? lastPage,
    int? total,
    bool? isLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    bool? hasError,
    bool? loadMoreError,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return ServiceRequestPageState(
      requests: requests ?? this.requests,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      total: total ?? this.total,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasError: hasError ?? this.hasError,
      loadMoreError: loadMoreError ?? this.loadMoreError,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }
}

class ServiceRequestsState {
  const ServiceRequestsState({
    required this.pages,
    required this.selectedStatus,
  });

  factory ServiceRequestsState.initial() {
    final Map<ServiceRequestFilter, ServiceRequestPageState> pages = {
      for (final ServiceRequestFilter filter in ServiceRequestFilter.values)
        filter: ServiceRequestPageState.initial(),
    };
    return ServiceRequestsState(
      pages: pages,
      selectedStatus: ServiceRequestFilter.review,
    );
  }

  final Map<ServiceRequestFilter, ServiceRequestPageState> pages;
  final ServiceRequestFilter selectedStatus;

  ServiceRequestsState copyWith({
    Map<ServiceRequestFilter, ServiceRequestPageState>? pages,
    ServiceRequestFilter? selectedStatus,
  }) {
    return ServiceRequestsState(
      pages: pages ?? this.pages,
      selectedStatus: selectedStatus ?? this.selectedStatus,
    );
  }

  ServiceRequestsState updateStatus(
      ServiceRequestFilter filter,
      ServiceRequestPageState newState, {
        ServiceRequestFilter? selectedStatus,
      }) {
    final Map<ServiceRequestFilter, ServiceRequestPageState> updatedPages =
    Map<ServiceRequestFilter, ServiceRequestPageState>.from(pages)
      ..[filter] = newState;
    return ServiceRequestsState(
      pages: updatedPages,
      selectedStatus: selectedStatus ?? this.selectedStatus,
    );
  }
}

class ServiceRequestsCubit extends Cubit<ServiceRequestsState> {
  ServiceRequestsCubit({
    ServiceRequestRepository? repository,
    this.perPage,
  })  : _repository = repository ?? ServiceRequestRepository(),
        super(ServiceRequestsState.initial());

  final ServiceRequestRepository _repository;
  final int? perPage;

  Future<void> changeStatus(ServiceRequestFilter status) async {
    if (state.selectedStatus != status) {
      emit(state.copyWith(selectedStatus: status));
    }

    final ServiceRequestPageState pageState =
        state.pages[status] ?? ServiceRequestPageState.initial();

    if (!pageState.hasLoaded || pageState.hasError) {
      await _fetchPage(
        status: status,
        pageNumber: 1,
        append: false,
        triggeredByRefresh: false,
        selectedStatusOverride: status,
      );
    }
  }

  Future<void> refresh(ServiceRequestFilter status) {
    return _fetchPage(
      status: status,
      pageNumber: 1,
      append: false,
      triggeredByRefresh: true,
      selectedStatusOverride: state.selectedStatus,
    );
  }

  Future<void> loadMore(ServiceRequestFilter status) {
    final ServiceRequestPageState pageState =
        state.pages[status] ?? ServiceRequestPageState.initial();
    if (!pageState.hasMore) {
      return Future<void>.value();
    }
    if (pageState.isLoadingMore) {
      return Future<void>.value();
    }
    final int nextPage = pageState.currentPage + 1;
    return _fetchPage(
      status: status,
      pageNumber: nextPage,
      append: true,
      triggeredByRefresh: false,
      selectedStatusOverride: state.selectedStatus,
    );
  }

  Future<void> _fetchPage({
    required ServiceRequestFilter status,
    required int pageNumber,
    required bool append,
    required bool triggeredByRefresh,
    ServiceRequestFilter? selectedStatusOverride,
  }) async {
    final ServiceRequestPageState currentState =
        state.pages[status] ?? ServiceRequestPageState.initial();

    if (append) {
      if (!currentState.hasMore && pageNumber > currentState.currentPage) {
        return;
      }
      if (currentState.isLoadingMore) {
        return;
      }
    } else {
      if (triggeredByRefresh) {
        if (!currentState.hasLoaded || currentState.isRefreshing) {
          if (!currentState.hasLoaded) {
            // If there is nothing loaded yet, treat as a normal fetch.
          } else {
            return;
          }
        }
      } else if (currentState.isLoading) {
        return;
      }
    }

    final List<ServiceRequestModel> existingRequests =
    List<ServiceRequestModel>.from(currentState.requests);

    ServiceRequestPageState pendingState;
    if (append) {
      pendingState = currentState.copyWith(
        isLoadingMore: true,
        loadMoreError: false,
        clearErrorMessage: false,
      );
    } else {
      final bool initialLoad = !currentState.hasLoaded;
      pendingState = currentState.copyWith(
        isLoading: initialLoad && !triggeredByRefresh,
        isRefreshing: !initialLoad && triggeredByRefresh,
        hasError: false,
        loadMoreError: false,
        clearErrorMessage: true,
      );
    }

    emit(state.updateStatus(
      status,
      pendingState,
      selectedStatus: selectedStatusOverride ?? state.selectedStatus,
    ));

    try {
      final ServiceRequestPage result = await _repository.fetchRequests(
        status: status.apiValue,
        page: pageNumber,
        perPage: perPage,
      );

      final int resolvedCurrentPage =
      result.currentPage > 0 ? result.currentPage : pageNumber;
      int resolvedLastPage = result.lastPage;
      if (resolvedLastPage < resolvedCurrentPage) {
        resolvedLastPage = resolvedCurrentPage;
      }
      if (append && resolvedLastPage < currentState.lastPage) {
        resolvedLastPage = currentState.lastPage;
      }

      final List<ServiceRequestModel> combined = append
          ? _mergeRequests(existingRequests, result.requests)
          : result.requests;

      final ServiceRequestPageState successState = pendingState.copyWith(
        requests: combined,
        currentPage: resolvedCurrentPage,
        lastPage: resolvedLastPage,
        total: result.total,
        isLoading: false,
        isRefreshing: false,
        isLoadingMore: false,
        hasError: false,
        loadMoreError: false,
        clearErrorMessage: true,
      );

      emit(state.updateStatus(
        status,
        successState,
        selectedStatus: selectedStatusOverride ?? state.selectedStatus,
      ));
    } catch (error, _) {
      final ServiceRequestPageState failureState;
      if (append) {
        failureState = currentState.copyWith(
          isLoadingMore: false,
          loadMoreError: true,
          clearErrorMessage: false,
        );
      } else {
        failureState = currentState.copyWith(
          isLoading: false,
          isRefreshing: false,
          hasError: true,
          loadMoreError: false,
          errorMessage: error.toString(),
        );
      }

      emit(state.updateStatus(
        status,
        failureState,
        selectedStatus: selectedStatusOverride ?? state.selectedStatus,
      ));
    }
  }

  List<ServiceRequestModel> _mergeRequests(
      List<ServiceRequestModel> existing,
      List<ServiceRequestModel> incoming,
      ) {
    final List<ServiceRequestModel> merged = List<ServiceRequestModel>.from(existing);
    final Set<int> seen = existing.map((ServiceRequestModel item) => item.id).toSet();
    for (final ServiceRequestModel item in incoming) {
      if (seen.add(item.id)) {
        merged.add(item);
      }
    }
    return merged;
  }
}