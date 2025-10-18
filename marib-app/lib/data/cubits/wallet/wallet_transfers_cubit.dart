import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:marib/data/repositories/wallet_operations_repository.dart';
import 'package:marib/data/model/wallet/wallet_recipient.dart';



abstract class WalletTransfersState {}

class WalletTransfersInitial extends WalletTransfersState {}

class WalletTransferSubmitting extends WalletTransfersState {}

class WalletTransferSuccess extends WalletTransfersState {
  WalletTransferSuccess(this.response);

  final Map<String, dynamic> response;
}

class WalletTransferFailure extends WalletTransfersState {
  WalletTransferFailure(this.error);

  final dynamic error;
}

class WalletTransfersCubit extends Cubit<WalletTransfersState> {
  WalletTransfersCubit({WalletOperationsRepository? repository})
      : _repository = repository ?? WalletOperationsRepository(),
        super(WalletTransfersInitial());

  final WalletOperationsRepository _repository;

  Future<Map<String, dynamic>> submitTransfer(Map<String, dynamic> payload) async {
    emit(WalletTransferSubmitting());
    try {
      final response = await _repository.submitTransfer(
        payload: payload,
        currency: payload['currency']?.toString(),
      );

      emit(WalletTransferSuccess(response));
      return response;
    } catch (e) {
      emit(WalletTransferFailure(e));
      rethrow;
    }
  }


  Future<WalletRecipient> fetchRecipient(int recipientId) {
    return _repository.fetchTransferRecipient(recipientId: recipientId);
  }


  void refresh() {
    emit(WalletTransfersInitial());
  }
}