import 'package:marib/data/repositories/advertisement_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/model/subscription_package_limit.dart';




abstract class FetchUserPackageLimitState {}

class FetchUserPackageLimitInitial extends FetchUserPackageLimitState {}

class FetchUserPackageLimitInProgress extends FetchUserPackageLimitState {}

class FetchUserPackageLimitInSuccess extends FetchUserPackageLimitState {
  final String responseMessage;

  final SubscriptionPackageLimit limit;
  final bool canCreateListing;

  FetchUserPackageLimitInSuccess({
    required this.responseMessage,
    required this.limit,
    required this.canCreateListing,
  });



}

class FetchUserPackageLimitFailure extends FetchUserPackageLimitState {
  final dynamic error;

  FetchUserPackageLimitFailure(this.error);
}

class FetchUserPackageLimitCubit extends Cubit<FetchUserPackageLimitState> {
  FetchUserPackageLimitCubit() : super(FetchUserPackageLimitInitial());
  final AdvertisementRepository repository = AdvertisementRepository();

  Future<void> fetchUserPackageLimit({required String packageType}) async {
    emit(FetchUserPackageLimitInProgress());

    try {
      final value = await repository.fetchUserPackageLimit(
        packageType: packageType,
      );

      final dataMap = _asMap(value['data']);
      final limit = SubscriptionPackageLimit.fromMap(dataMap);
      final bool unlimited = limit.isUnlimited;
      final bool? allowed = limit.allowed;
      final bool canCreateListing;
      if (unlimited) {
        canCreateListing = true;
      } else if (allowed != null) {
        canCreateListing = allowed;
      } else {
        canCreateListing = (limit.remaining ?? 0) > 0;
      }


      emit(
        FetchUserPackageLimitInSuccess(
          responseMessage: value['message']?.toString() ?? '',
          limit: limit,
          canCreateListing: canCreateListing,
        ),
      );
    } catch (e) {
      emit(FetchUserPackageLimitFailure(e.toString()));
    }
  }


  Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) {

      return raw;
    }

    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));

    }

    return <String, dynamic>{};
  }



}
