// ignore_for_file: public_member_api_docs, sort_constructors_first

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/payment/bank_account.dart';
import 'package:marib/utils/payment/east_yemen_bank_config.dart';

class GetApiKeysCubit extends Cubit<GetApiKeysState> {
  GetApiKeysCubit() : super(GetApiKeysInitial());

  Future<void> fetch() async {
    emit(GetApiKeysInProgress());

    try {
      final Map<String, dynamic> response =
      Map<String, dynamic>.from(await Api.get(url: Api.getPaymentSettingsApi));

      final List<BankAccount> manualBanks = _parseManualBanks(response['data']);
      final EastYemenBankConfig? eastYemenBank = _parseEastYemenBank(response);
      final bool walletEnabled = _parseWalletEnabled(response);

      emit(
        GetApiKeysSuccess(
          manualBanks: manualBanks,
          eastYemenBank: eastYemenBank,
          walletEnabled: walletEnabled,
          raw: response,
        ),
      );
    } catch (error) {
      emit(GetApiKeysFail(error.toString()));
    }
  }

  List<BankAccount> _parseManualBanks(dynamic payload) {
    final List<BankAccount> banks = <BankAccount>[];

    void inspect(dynamic node) {
      if (node == null) return;

      if (node is Iterable) {
        for (final dynamic element in node) {
          inspect(element);
        }
        return;
      }

      final Map<String, dynamic>? map = _mapify(node);
      if (map == null) {
        return;
      }

      if (_looksLikeBank(map)) {
        final BankAccount bank = BankAccount.fromJson(map);
        if (bank.bankName.trim().isNotEmpty && bank.isActive) {
          banks.add(bank);
        }
        return;
      }

      const List<String> bankKeys = <String>[
        'manual_payment_banks',
        'manual_banks',
        'manualBanks',
        'banks',
        'items',
        'data',
      ];

      for (final String key in bankKeys) {
        if (!map.containsKey(key)) continue;
        inspect(map[key]);
      }
    }
    inspect(payload);

    banks.sort((BankAccount a, BankAccount b) {
      final int orderComparison = (a.displayOrder ?? 0).compareTo(b.displayOrder ?? 0);
      if (orderComparison != 0) {
        return orderComparison;
      }
      return a.bankName.toLowerCase().compareTo(b.bankName.toLowerCase());
    });

    return banks;
  }

  EastYemenBankConfig? _parseEastYemenBank(Map<String, dynamic> payload) {
    final Map<String, dynamic>? direct = _mapify(
      payload['east_yemen_bank'] ??
          payload['eastYemenBank'] ??
          (payload['data'] is Map ? (payload['data'] as Map)['east_yemen_bank'] : null) ??
          (payload['data'] is Map ? (payload['data'] as Map)['eastYemenBank'] : null),
    );

    if (direct != null && direct.isNotEmpty) {
      try {
        return EastYemenBankConfig.fromMap(direct);
      } catch (_) {
        return null;
      }
    }

    return null;
  }

  bool _parseWalletEnabled(Map<String, dynamic> payload) {
    dynamic candidate = payload['wallet_enabled'] ?? payload['walletEnabled'];

    if (candidate == null) {
      final Map<String, dynamic>? wallet = _mapify(payload['wallet']);
      if (wallet != null) {
        candidate = wallet['enabled'] ?? wallet['status'];
      }
    }

    if (candidate == null) {
      final Map<String, dynamic>? extras = _mapify(payload['extras']);
      if (extras != null) {
        candidate = extras['wallet_enabled'] ?? extras['walletEnabled'];
      }
    }

    if (candidate == null) {
      return true;
    }

    return _asBool(candidate);
  }

  Map<String, dynamic>? _mapify(dynamic value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    if (value is Map) {
      return value.map(
            (dynamic key, dynamic v) => MapEntry<String, dynamic>('${key ?? ''}', v),
      );
    }
    return null;
  }

  bool _looksLikeBank(Map<String, dynamic> map) {
    return map.containsKey('bank_name') ||
        map.containsKey('account_name') ||
        map.containsKey('accountNumber') ||
        map.containsKey('account_number') ||
        map.containsKey('iban');
  }

  bool _asBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final String normalized = value.toString().trim().toLowerCase();
    if (normalized.isEmpty) return false;
    return <String>{'1', 'true', 'yes', 'y', 'on', 'enabled', 'active'}.contains(normalized);
  }
}

abstract class GetApiKeysState {}

class GetApiKeysInitial extends GetApiKeysState {}

class GetApiKeysInProgress extends GetApiKeysState {}

class GetApiKeysSuccess extends GetApiKeysState {


  GetApiKeysSuccess({
    required this.manualBanks,
    required this.walletEnabled,
    required this.raw,
    this.eastYemenBank,
  });

  final List<BankAccount> manualBanks;
  final bool walletEnabled;
  final EastYemenBankConfig? eastYemenBank;
  final Map<String, dynamic> raw;
}

class GetApiKeysFail extends GetApiKeysState {

  GetApiKeysFail(this.error);
  final dynamic error;

}
