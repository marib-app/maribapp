import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:marib/data/repositories/wallet_operations_repository.dart';
import 'package:marib/data/model/wallet/wallet_recipient.dart';
import 'package:marib/utils/api.dart';



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
      final requestPayload = _prepareTransferPayload(payload);

      final response = await _repository.submitTransfer(
        payload: requestPayload,
        currency: requestPayload['currency']?.toString(),
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





  Map<String, dynamic> _prepareTransferPayload(Map<String, dynamic> payload) {
    final requestPayload = Map<String, dynamic>.from(payload);

    final String uniqueSuffix = Api.generateIdempotencyKey();
    final String? baseClientTag = requestPayload['client_tag']?.toString().trim();
    requestPayload['client_tag'] = _composeClientTag(baseClientTag, uniqueSuffix);

    final int? resolvedRecipientId = _resolveRecipientId(requestPayload);
    if (resolvedRecipientId != null) {
      requestPayload['recipient_id'] = resolvedRecipientId;
    }

    final double? resolvedAmount = _resolveAmount(requestPayload);
    if (resolvedAmount != null) {
      requestPayload['amount'] = resolvedAmount;
    }

    return requestPayload;
  }

  String _composeClientTag(String? baseTag, String uniqueSuffix) {
    const int maxLength = 64;
    const int minimumUnique = 8;
    const String separator = '-';

    String truncate(String value, int limit) {
      if (limit <= 0) {
        return '';
      }
      return value.length <= limit ? value : value.substring(0, limit);
    }

    final String trimmedUnique = uniqueSuffix.trim();
    final String truncatedUnique = truncate(trimmedUnique, maxLength);

    final String trimmedBase = (baseTag ?? '').trim();
    if (trimmedBase.isEmpty) {
      return truncatedUnique;
    }

    var basePart = trimmedBase;
    var availableForUnique = maxLength - basePart.length - separator.length;

    if (availableForUnique < minimumUnique) {
      final int targetBaseLength = maxLength - minimumUnique - separator.length;
      if (targetBaseLength <= 0) {
        return truncatedUnique;
      }
      basePart = truncate(basePart, targetBaseLength);
      availableForUnique = maxLength - basePart.length - separator.length;
    }

    final String uniquePart = truncate(truncatedUnique, availableForUnique);

    if (basePart.isEmpty) {
      return uniquePart;
    }

    if (uniquePart.isEmpty) {
      return truncate(basePart, maxLength);
    }

    return '$basePart$separator$uniquePart';
  }

  int? _resolveRecipientId(Map<String, dynamic> payload) {
    int? tryParse(dynamic value) {
      if (value == null) {
        return null;
      }
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      final String trimmed = value.toString().trim();
      if (trimmed.isEmpty) {
        return null;
      }
      return int.tryParse(trimmed);
    }

    final candidates = [
      payload['recipient_id'],
      payload['recipientId'],
      payload['recipient'],
    ];

    for (final value in candidates) {
      final parsed = tryParse(value);
      if (parsed != null) {
        return parsed;
      }
    }

    final dynamic fields = payload['fields'];
    if (fields is Map) {
      for (final key in const ['recipient_id', 'recipientId', 'recipient']) {
        final parsed = tryParse(fields[key]);
        if (parsed != null) {
          return parsed;
        }
      }
    }

    return null;
  }

  double? _resolveAmount(Map<String, dynamic> payload) {
    double? tryParse(dynamic value) {
      if (value == null) {
        return null;
      }
      if (value is double) {
        return value;
      }
      if (value is int) {
        return value.toDouble();
      }
      if (value is num) {
        return value.toDouble();
      }
      final String trimmed = value.toString().trim();
      if (trimmed.isEmpty) {
        return null;
      }
      final normalized = trimmed.replaceAll(',', '.');
      return double.tryParse(normalized);
    }

    final candidates = [
      payload['amount'],
      payload['transfer_amount'],
      payload['value'],
    ];

    for (final value in candidates) {
      final parsed = tryParse(value);
      if (parsed != null) {
        return parsed;
      }
    }

    final dynamic fields = payload['fields'];
    if (fields is Map) {
      for (final key in const ['amount', 'transfer_amount', 'value']) {
        final parsed = tryParse(fields[key]);
        if (parsed != null) {
          return parsed;
        }
      }
    }

    return null;
  }
}