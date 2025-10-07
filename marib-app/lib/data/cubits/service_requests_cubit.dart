import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/model/service_request_model.dart';
import 'package:marib/data/repositories/service_request_repository.dart';

abstract class ServiceRequestsState {
  const ServiceRequestsState();
}

class ServiceRequestsInitial extends ServiceRequestsState {
  const ServiceRequestsInitial();
}

class ServiceRequestsLoadInProgress extends ServiceRequestsState {
  const ServiceRequestsLoadInProgress();
}

class ServiceRequestsLoadSuccess extends ServiceRequestsState {
  final List<ServiceRequestModel> review;
  final List<ServiceRequestModel> approved;
  final List<ServiceRequestModel> rejected;

  const ServiceRequestsLoadSuccess({
    required this.review,
    required this.approved,
    required this.rejected,
  });

  ServiceRequestsLoadSuccess copyWith({
    List<ServiceRequestModel>? review,
    List<ServiceRequestModel>? approved,
    List<ServiceRequestModel>? rejected,
  }) {
    return ServiceRequestsLoadSuccess(
      review: review ?? this.review,
      approved: approved ?? this.approved,
      rejected: rejected ?? this.rejected,
    );
  }
}

class ServiceRequestsLoadFailure extends ServiceRequestsState {
  final dynamic error;
  const ServiceRequestsLoadFailure(this.error);
}

class ServiceRequestsCubit extends Cubit<ServiceRequestsState> {
  ServiceRequestsCubit({ServiceRequestRepository? repository})
      : _repository = repository ?? ServiceRequestRepository(),
        super(const ServiceRequestsInitial());

  final ServiceRequestRepository _repository;
  int? _categoryId;
  final List<ServiceRequestModel> _buffer = [];

  Future<void> fetchRequests({int? categoryId}) async {
    _categoryId = categoryId ?? _categoryId;
    emit(const ServiceRequestsLoadInProgress());
    try {
      final results = await Future.wait([
        _repository.fetchRequests(status: 'review', categoryId: _categoryId),
        _repository.fetchRequests(status: 'approved', categoryId: _categoryId),
        _repository.fetchRequests(status: 'rejected', categoryId: _categoryId),
      ]);

      var success = ServiceRequestsLoadSuccess(
        review: results[0],
        approved: results[1],
        rejected: results[2],
      );

      if (_buffer.isNotEmpty) {
        for (final item in List<ServiceRequestModel>.from(_buffer)) {
          success = _insert(success, item);
        }
        _buffer.clear();
      }

      emit(success);
    } catch (e) {
      emit(ServiceRequestsLoadFailure(e));
    }
  }

  Future<void> refresh() => fetchRequests();

  void addOrUpdate(ServiceRequestModel request) {
    final normalized = _normalizeStatus(request.status);
    final model = ServiceRequestModel(
      id: request.id,
      status: normalized,
      raw: request.raw,
      serviceTitle: request.serviceTitle,
      submittedAt: request.submittedAt,
      amount: request.amount,
      currency: request.currency,
      customFields: request.customFields,
      attachments: request.attachments,
    );

    if (state is ServiceRequestsLoadSuccess) {
      final updated = _insert(state as ServiceRequestsLoadSuccess, model);
      emit(updated);
    } else if (state is ServiceRequestsLoadInProgress ||
        state is ServiceRequestsInitial) {
      _buffer.removeWhere((element) => element.id == model.id);
      _buffer.add(model);
    }
  }

  void addOrUpdateFromMap(Map<String, dynamic> data) {
    addOrUpdate(ServiceRequestModel.fromJson(data));
  }

  ServiceRequestsLoadSuccess _insert(
      ServiceRequestsLoadSuccess current,
      ServiceRequestModel request,
      ) {
    final normalizedStatus = _normalizeStatus(request.status);

    List<ServiceRequestModel> clone(List<ServiceRequestModel> input) =>
        List<ServiceRequestModel>.from(input);

    final review = clone(current.review);
    final approved = clone(current.approved);
    final rejected = clone(current.rejected);

    void removeExisting(List<ServiceRequestModel> list) {
      list.removeWhere((element) => element.id == request.id);
    }

    for (final list in [review, approved, rejected]) {
      removeExisting(list);
    }

    List<ServiceRequestModel> target;
    switch (normalizedStatus) {
      case 'approved':
        target = approved;
        break;
      case 'rejected':
        target = rejected;
        break;
      default:
        target = review;
    }

    target.insert(0, request);
    target.sort((a, b) {
      final aDate = a.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return current.copyWith(
      review: review,
      approved: approved,
      rejected: rejected,
    );
  }

  String _normalizeStatus(String status) {
    final s = status.trim().toLowerCase();
    switch (s) {
      case 'approved':
      case 'accepted':
      case 'done':
        return 'approved';
      case 'rejected':
      case 'declined':
      case 'cancelled':
        return 'rejected';
      default:
        return 'review';
    }
  }
}