import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:marib/data/cubits/system/user_details.dart';
import 'package:marib/data/repositories/auth_repository.dart';

import 'shared/signup_new_view_model.dart';
import 'signup_stepper.dart';

class SignupNewPage extends StatefulWidget {
  const SignupNewPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute(builder: (_) => const SignupNewPage());
  }

  @override
  State<SignupNewPage> createState() => _SignupNewPageState();
}

class _SignupNewPageState extends State<SignupNewPage> {
  late final SignupNewViewModel _viewModel;

  UserDetailsCubit? _resolveUserDetailsCubit() {
    try {
      return context.read<UserDetailsCubit>();
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    final userDetails = _resolveUserDetailsCubit();

    _viewModel = SignupNewViewModel(
      authRepository: AuthRepository(),
      multiAuthRepository: MultiAuthRepository(),
      userDetailsCubit: userDetails,
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
    return SignupStepper(viewModel: _viewModel);
  }
}