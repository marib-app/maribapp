import 'package:marib/data/model/service_request_model.dart';

class ServiceRequestPaginationMeta {
  const ServiceRequestPaginationMeta({
    required this.total,
    required this.currentPage,
    required this.lastPage,
  });

  final int total;
  final int currentPage;
  final int lastPage;

  bool get hasMore => currentPage < lastPage;
}

class ServiceRequestPage {
  const ServiceRequestPage({
    required this.requests,
    required this.meta,
  });

  final List<ServiceRequestModel> requests;
  final ServiceRequestPaginationMeta meta;

  int get total => meta.total;

  int get currentPage => meta.currentPage;

  int get lastPage => meta.lastPage;

  bool get hasMore => meta.hasMore;
}
