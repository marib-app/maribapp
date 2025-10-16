import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:marib/data/cubits/auth/authentication_cubit.dart';
import 'package:marib/data/cubits/auth/login_cubit.dart';
import 'package:marib/data/cubits/system/user_details.dart';

import 'shared/login_new_view_model.dart';
import 'login_new_view.dart';

class LoginNewPage extends StatefulWidget {
  const LoginNewPage({
    super.key,
    this.isDeleteAccountFlow = false,
    this.popToCurrent = false,
    this.legacyArguments,
  });

  final bool isDeleteAccountFlow;
  final bool popToCurrent;
  final Map<String, dynamic>? legacyArguments;

  static Route<void> route(RouteSettings settings) {
    final parsed = _LoginRouteArguments.from(settings.arguments);

    return MaterialPageRoute(
      settings: settings,

      builder: (context) => MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => AuthenticationCubit()),
          BlocProvider(create: (_) => LoginCubit()),
        ],
        child: LoginNewPage(
          isDeleteAccountFlow: parsed.isDeleteAccount,
          popToCurrent: parsed.popToCurrent,
          legacyArguments: parsed.rawArguments,
        ),
      ),
    );
  }

  @override
  State<LoginNewPage> createState() => _LoginNewPageState();
}

class _LoginNewPageState extends State<LoginNewPage> {
  late final LoginNewViewModel _viewModel;

  UserDetailsCubit? _resolveUserDetailsCubit(BuildContext context) {
    try {
      return context.read<UserDetailsCubit>();
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    final loginCubit = context.read<LoginCubit>();
    final authenticationCubit = context.read<AuthenticationCubit>();
    final userDetailsCubit = _resolveUserDetailsCubit(context);

    _viewModel = LoginNewViewModel(
      loginCubit: loginCubit,
      authenticationCubit: authenticationCubit,
      userDetailsCubit: userDetailsCubit,
      isDeleteAccountFlow: widget.isDeleteAccountFlow,
      popToCurrent: widget.popToCurrent,
      legacyArguments: widget.legacyArguments,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _viewModel.initialize(context);
    });
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LoginNewView(viewModel: _viewModel);
  }



}

class _LoginRouteArguments {
  final bool isDeleteAccount;
  final bool popToCurrent;
  final Map<String, dynamic>? rawArguments;

  const _LoginRouteArguments({
    required this.isDeleteAccount,
    required this.popToCurrent,
    required this.rawArguments,
  });

  factory _LoginRouteArguments.from(Object? arguments) {
    if (arguments is _LoginRouteArguments) {
      return arguments;
    }

    if (arguments is Map) {
      final map = Map<String, dynamic>.from(arguments as Map);
      return _LoginRouteArguments(
        isDeleteAccount: (map['isDeleteAccount'] as bool?) ?? false,
        popToCurrent: (map['popToCurrent'] as bool?) ?? false,
        rawArguments: map,
      );
    }

    return const _LoginRouteArguments(
      isDeleteAccount: false,
      popToCurrent: false,
      rawArguments: null,
    );
  }
}