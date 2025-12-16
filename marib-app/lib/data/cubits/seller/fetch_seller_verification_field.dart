import 'package:marib/data/model/custom_field/custom_field_model.dart';
import 'package:marib/data/model/verification_metadata.dart';
import 'package:marib/data/repositories/seller/seller_verification_field_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

abstract class FetchSellerVerificationFieldState {}

class FetchSellerVerificationFieldInitial
    extends FetchSellerVerificationFieldState {}

class FetchSellerVerificationFieldInProgress
    extends FetchSellerVerificationFieldState {}

class FetchSellerVerificationFieldSuccess
    extends FetchSellerVerificationFieldState {
  final List<VerificationFieldModel> fields;
  final VerificationMetadata metadata;
  final String accountType;

  FetchSellerVerificationFieldSuccess({
    required this.fields,
    required this.metadata,
    required this.accountType,
  });
}

class FetchSellerVerificationFieldFail
    extends FetchSellerVerificationFieldState {
  final dynamic error;

  FetchSellerVerificationFieldFail(this.error);
}

class FetchSellerVerificationFieldsCubit
    extends Cubit<FetchSellerVerificationFieldState> {
  FetchSellerVerificationFieldsCubit()
      : super(FetchSellerVerificationFieldInitial());
  final SellerVerificationFieldRepository sellerVerificationFieldRepository =
      SellerVerificationFieldRepository();

  void fetchSellerVerificationFields({String? accountType, bool forceRefresh = false}) async {
    try {
      emit(FetchSellerVerificationFieldInProgress());
      final String normalizedAccountType =
          _normalizeAccountType(accountType) ?? 'individual';

      final metadata = await sellerVerificationFieldRepository
          .getVerificationMetadata(accountType: normalizedAccountType, forceRefresh: forceRefresh);

      List<VerificationFieldModel> result =
          metadata.fieldsFor(normalizedAccountType);

      emit(FetchSellerVerificationFieldSuccess(
          fields: result,
          metadata: metadata,
          accountType: normalizedAccountType));
    } catch (e) {
      emit(FetchSellerVerificationFieldFail(e.toString()));
    }
  }

//while edit
  void fillCustomFields(List<VerificationFieldModel> fields,
      {VerificationMetadata? metadata, String? accountType}) {
    final previous = state is FetchSellerVerificationFieldSuccess
        ? state as FetchSellerVerificationFieldSuccess
        : null;

    emit(FetchSellerVerificationFieldSuccess(
      fields: fields,
      metadata: metadata ?? previous?.metadata ?? VerificationMetadata.empty(),
      accountType: accountType ?? previous?.accountType ?? 'individual',
    ));
  }

  List<VerificationFieldModel> getFields() {
    if (state is FetchSellerVerificationFieldSuccess) {
      return (state as FetchSellerVerificationFieldSuccess).fields;
    }
    return [];
  }

  bool? isEmpty() {
    if (state is FetchSellerVerificationFieldSuccess) {
      return (state as FetchSellerVerificationFieldSuccess).fields.isEmpty;
    }
    return null;
  }

  String? _normalizeAccountType(String? value) {
    if (value == null) return null;
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case '1':
      case 'individual':
      case 'personal':
      case 'customer':
      case 'private':
        return 'individual';
      case '2':
      case 'realestate':
      case 'real_estate':
      case 'property':
        return 'realestate';
      case '3':
      case 'commercial':
      case 'business':
      case 'merchant':
      case 'seller':
        return 'commercial';
      default:
        return null;
    }
  }
}
