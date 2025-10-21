import 'package:marib/data/model/service_request_model.dart';

class ServiceRequestPage {
  const ServiceRequestPage({
    required this.requests,
    required this.total,
    required this.currentPage,
    required this.lastPage,
  });

  final List<ServiceRequestModel> requests;
  final int total;
  final int currentPage;
  final int lastPage;

  bool get hasMore => currentPage < lastPage;
}