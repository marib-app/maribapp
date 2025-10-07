import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/cubits/wallet/manual_payment_requests_cubit.dart';

import 'package:marib/data/cubits/wallet/wallet_summary_cubit.dart';
import 'package:marib/data/cubits/wallet/wallet_transactions_cubit.dart';
import 'package:marib/ui/screens/wallet/wallet_screen_ui.dart';
import 'package:marib/data/cubits/wallet/wallet_transfers_cubit.dart';
import 'package:marib/data/cubits/wallet/wallet_withdrawals_cubit.dart';


class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  static Route route(RouteSettings settings) {
    return MaterialPageRoute(
      settings: settings,
      builder: (context) {
        return MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => WalletSummaryCubit()..fetchSummary()),
            BlocProvider(create: (_) => WalletTransactionsCubit()..loadInitial()),
            BlocProvider(create: (_) => ManualPaymentRequestsCubit()..loadInitial()),

            BlocProvider(create: (_) => WalletTransfersCubit()),
            BlocProvider(
              create: (_) => WalletWithdrawalsCubit()
                ..loadInitial(includeOptions: true),
            ),
          ],
          child: const WalletScreenUI(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => WalletSummaryCubit()..fetchSummary()),
        BlocProvider(create: (_) => WalletTransactionsCubit()..loadInitial()),
        BlocProvider(create: (_) => ManualPaymentRequestsCubit()..loadInitial()),
        BlocProvider(create: (_) => WalletTransfersCubit()),
        BlocProvider(
          create: (_) => WalletWithdrawalsCubit()
            ..loadInitial(includeOptions: true),
        ),
      ],
      child: const WalletScreenUI(),
    );
  }
}