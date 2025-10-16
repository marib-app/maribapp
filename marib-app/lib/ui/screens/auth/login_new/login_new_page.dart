import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:marib/data/cubits/auth/authentication_cubit.dart';
import 'package:marib/data/cubits/auth/login_cubit.dart';
import 'package:marib/data/cubits/system/user_details.dart';

import 'shared/login_new_view_model.dart';
import 'login_new_view.dart';

class LoginNewPage extends StatefulWidget {
  const LoginNewPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute(
      builder: (context) => MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => AuthenticationCubit()),
          BlocProvider(create: (_) => LoginCubit()),
        ],
        child: const LoginNewPage(),
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