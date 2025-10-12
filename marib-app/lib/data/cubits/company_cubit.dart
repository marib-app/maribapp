import 'package:marib/data/helper/custom_exception.dart';
import 'package:marib/data/model/company.dart';
import 'package:marib/utils/api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/repositories/system_repository.dart';

abstract class CompanyState {}

class CompanyInitial extends CompanyState {}

class CompanyFetchProgress extends CompanyState {}

class CompanyFetchSuccess extends CompanyState {
  Company companyData;

  CompanyFetchSuccess(this.companyData);
}

class CompanyFetchFailure extends CompanyState {
  final String errmsg;

  CompanyFetchFailure(this.errmsg);
}

class CompanyCubit extends Cubit<CompanyState> {
  CompanyCubit() : super(CompanyInitial());

  void fetchCompany(BuildContext context) {
    emit(CompanyFetchProgress());
    fetchCompanyFromDb(context)
        .then((value) => emit(CompanyFetchSuccess(value)))
        .catchError((e) => emit(CompanyFetchFailure(e.toString())));
  }

  Future<Company> fetchCompanyFromDb(BuildContext context) async {
    try {
      Company companyData = Company();

      Map<String, String> body = {};

      var response =
          await Api.get(url: Api.getSystemSettingsApi, queryParameters: body);

      if (!response[Api.error]) {
        final Map<String, dynamic> data =
        SystemRepository.normalizeSettingsPayload(response);
        companyData = Company(
          companyEmail: data['company_email']?.toString(),
          companyName: data['company_name']?.toString(),
          companyTel1: data['company_tel1']?.toString(),
          companyTel2: data['company_tel2']?.toString(),
        );
      } else {
        throw CustomException(response[Api.message]);
      }

      return companyData;
    } catch (e) {
      rethrow;
    }
  }
}
