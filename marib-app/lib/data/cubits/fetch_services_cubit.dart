import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/model/classified_model.dart'; // يحتوي ClassifiedModel + ClassifiedSummary
import 'package:marib/data/repositories/service_repository.dart';

/// ---------------------------
/// States
/// ---------------------------
abstract class FetchServicesState {}

class FetchServicesInitial extends FetchServicesState {}

class FetchServicesInProgress extends FetchServicesState {}

class FetchServicesSuccess extends FetchServicesState {
  /// نعرض في القائمة نسخة خفيفة فقط
  final List<ClassifiedSummary> servicesList;
  final int totalData;
  final bool hasMore;
  final bool isLoadingMore;
  final bool loadingMoreError;

  FetchServicesSuccess({
    required this.servicesList,
    required this.totalData,
    required this.hasMore,
    this.isLoadingMore = false,
    this.loadingMoreError = false,
  });
}

class FetchServicesFailure extends FetchServicesState {
  final dynamic errorMessage;
  FetchServicesFailure(this.errorMessage);
}

/// ---------------------------
/// Cubit
/// ---------------------------
class FetchServicesCubit extends Cubit<FetchServicesState> {
  final ServiceRepository _serviceRepository = ServiceRepository();

  FetchServicesCubit() : super(FetchServicesInitial());

  final int _limit = 10;
  int _offset = 0;
  bool _hasMoreData = true;

  /// نخزن النسخ الخفيفة فقط (للعرض في الشبكة)
  List<ClassifiedSummary> _services = [];

  bool hasMoreData() => _hasMoreData;

  /// جلب أولي
  Future<void> fetchServices({int? categoryId}) async {
    try {
      emit(FetchServicesInProgress());
      _offset = 0;

      final Map<String, dynamic> parameters = {
        "offset": _offset.toString(),
        "limit": _limit.toString(),
        if (categoryId != null) "category_id": categoryId.toString(),
      };

      final result = await _serviceRepository.fetchServices(parameters);

      // قد تكون بالفعل List<ClassifiedSummary> أو List<Map>
      final List raw = (result['services'] as List? ?? const []);
      final List<ClassifiedSummary> list = raw.map((e) {
        if (e is ClassifiedSummary) return e;
        return ClassifiedSummary.fromJson(Map<String, dynamic>.from(e));
      }).toList();

      _services = list;
      final int total = (result['total'] as int? ?? list.length);
      _hasMoreData = _services.length < total;

      emit(FetchServicesSuccess(
        servicesList: _services,
        totalData: total,
        hasMore: _hasMoreData,
        isLoadingMore: false,
        loadingMoreError: false,
      ));
    } catch (e) {
      emit(FetchServicesFailure(e.toString()));
    }
  }

  /// جلب إضافي (تحميل المزيد)
  Future<void> fetchMoreServices({int? categoryId}) async {
    if (!_hasMoreData) return;

    // أعرض حالة "تحميل المزيد" الحالية للمستخدم
    if (state is FetchServicesSuccess) {
      final s = state as FetchServicesSuccess;
      emit(FetchServicesSuccess(
        servicesList: s.servicesList,
        totalData: s.totalData,
        hasMore: s.hasMore,
        isLoadingMore: true,
        loadingMoreError: false,
      ));
    }

    try {
      _offset += _limit;

      final Map<String, dynamic> parameters = {
        "offset": _offset.toString(),
        "limit": _limit.toString(),
        if (categoryId != null) "category_id": categoryId.toString(),
      };

      final result = await _serviceRepository.fetchServices(parameters);

      final List raw = (result['services'] as List? ?? const []);
      final List<ClassifiedSummary> newItems = raw.map((e) {
        if (e is ClassifiedSummary) return e;
        return ClassifiedSummary.fromJson(Map<String, dynamic>.from(e));
      }).toList();

      final int total =
          (result['total'] as int? ?? (_services.length + newItems.length));

      _services.addAll(newItems);
      _hasMoreData = _services.length < total;

      emit(FetchServicesSuccess(
        servicesList: _services,
        totalData: total,
        hasMore: _hasMoreData,
        isLoadingMore: false,
        loadingMoreError: false,
      ));
    } catch (e) {
      // في حال خطأ أثناء التحميل الإضافي نحافظ على البيانات الحالية
      if (state is FetchServicesSuccess) {
        final s = state as FetchServicesSuccess;
        emit(FetchServicesSuccess(
          servicesList: s.servicesList,
          totalData: s.totalData,
          hasMore: s.hasMore,
          isLoadingMore: false,
          loadingMoreError: true,
        ));
      } else {
        emit(FetchServicesFailure(e.toString()));
      }
    }
  }
}
